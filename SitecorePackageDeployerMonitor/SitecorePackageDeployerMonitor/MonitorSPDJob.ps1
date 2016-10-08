##-----------------------------------------------------------------------
## <copyright file="SitecorePackageDeployerMonitorJob.ps1">(c) Jose A Rivera. All rights reserved.</copyright>
##-----------------------------------------------------------------------
# Look for a .json file. 
# If found use it to determine success or failure of Sitecore package installation.
# TODO:
#	1. Add /pt:[.zip|.update] parameter
#	2. Test Parallel job runs
#	3. Normalize logging
#	

$MonitorSPDJob = {
param (
    [string]$fqdn, 
    [string]$sourcePath,
    [string]$targetPath,
    [object]$credential,
    [string]$cleanTargetBeforeMonitor,
    [string]$additionalArguments)    

	Write-Verbose "Entering script MonitorSPDJob.ps1"

	$packageFileExtension = "*.update"
	$sourcePath = $sourcePath.Trim().TrimEnd('\', '/')
    $targetPath = $targetPath.Trim().TrimEnd('\', '/')    
	$isFileMonitor = Test-Path -Path $sourcePath -PathType Container
    $doCleanUp = $cleanTargetBeforeMonitor -eq "true"
	$sourcePathFilter = Join-Path -ChildPath $packageFileExtension -Path $sourcePath
	$filesToMonitor = ""
    
	if($isFileMonitor)
    {
        $sourceDirectory = Split-Path $sourcePathFilter
        $filesToMonitor = Split-Path $sourcePathFilter -Leaf -Resolve
    }
	
	Write-Verbose "sourcePath = $sourcePath"
	Write-Verbose "targetPath = $targetPath"
	Write-Verbose "doCleanUp = $doCleanUp"
	Write-Verbose "sourcePathFilter = $sourcePathFilter"
	Write-Verbose "filesToMonitor = $filesToMonitor"
	Write-Verbose "isFileMonitor = $isFileMonitor"
	Write-Verbose "sourceDirectory = $sourceDirectory"
	Write-Verbose "filesToMonitor = $filesToMonitor"
	Write-Verbose "packageFileExtension = $packageFileExtension"

    if(Test-Path "$env:AGENT_HOMEDIRECTORY\Agent\Worker")
    {
        Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\*.dll | % {
        [void][reflection.assembly]::LoadFrom( $_.FullName )
        Write-Verbose "Loading .NET assembly:`t$($_.name)" -Verbose
        }
    }
    else
    {
        if(Test-Path "$env:AGENT_HOMEDIRECTORY\externals\vstshost")
        {
            [void][reflection.assembly]::LoadFrom("$env:AGENT_HOMEDIRECTORY\externals\vstshost\Microsoft.TeamFoundation.DistributedTask.Task.LegacySDK.dll")
        }
    }
    
    import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"
    
    function ThrowError
    {
        param(
            [string]$errorMessage,
            [string]$fqdn)
        
        $failMessage = "Monitoring failed for resource : $fqdn"
        throw "$failMessage`n$errorMessage"
    }
    
    function Validate-Null(
        [string]$value,
        [string]$variableName)
    {
        $value = $value.Trim()    
        if(-not $value)
        {
            ThrowError -errorMessage (Get-LocalizedString -Key "Parameter '{0}' cannot be null or empty." -ArgumentList $variableName)
        }
    }
    
    function Validate-Credential(
        [object]$credential)
    {
        if($credential)
        {
            Validate-Null $credential.UserName "Username"
            Validate-Null $credential.Password "Password"                        
        }
        else
        {
            ThrowError -errorMessage (Get-LocalizedString -Key "Parameter '{0}' cannot be null or empty." -ArgumentList "credential")
        }   
    }

    function Get-DownLevelLogonName(
        [string]$fqdn,
        [string]$userName)
    {
        if($userName  -like '.\*') {
            $userName = $userName.replace(".\","\")
            $userName = $fqdn+$userName
        }

        return $userName
    }

    function Replace-First(
        [string]$text,
        [string]$search, 
        [string]$replace)
    {
        $pos = $text.IndexOf($search);
        if ($pos -le 0)
        {
            return $text;
        }

        return $text.Substring(0, $pos) + $replace + $text.Substring($pos + $search.Length);
    }

	function Replace-Last(
        [string]$text,
        [string]$search,
        [string]$replace)
	{
		return $text.Remove(($lastIndex = $text.LastIndexOf($search)),$search.Length).Insert($lastIndex,$replace)
	}

	function Array-ToHash(
		[array]$a)
	{
		$hash = @{}
		$a | foreach { $hash[$_] = Replace-Last $_ ".update" ".json" }
		return $hash
	}

    function Get-DestinationNetworkPath(
        [string]$targetPath,
        [string]$machineShare)
    {
        if(-not $machineShare)
        {
            return $targetPath
        }

        $targetSpecificPath = Replace-First $targetPath ":" '$'    
        return [io.path]::Combine($machineShare, $targetSpecificPath)    
    }    

	function Get-Args(
		[string]$command)
	{
		return [management.automation.psparser]::Tokenize($command,[ref]$null)
	}

	function Get-MonitorParameters(
		[string]$additionalArguments)
	{
		$monitorParameters = @{}

		if (-not [string]::IsNullOrWhiteSpace($additionalArguments))
		{
			$arg = Get-Args $additionalArguments | Select-Object -ExpandProperty Content | ForEach-Object{ 
				switch -wildcard ($_) 
				{ 
					"*/S:*" { $monitorParameters.Add("Sleep", $_.split(':')[-1].trim()) } 
					"*/T:*" { $monitorParameters.Add("Timeout", $_.split(':')[-1].trim())} 
				}
			}
		}

		return $monitorParameters
	}

    function Get-MachineShare(
        [string]$fqdn,
        [string]$targetPath)
    {
        if([bool]([uri]$targetPath).IsUnc)
        {
            return $targetPath
        }
        if($fqdn)
        {
            return [IO.Path]::DirectorySeparatorChar + [IO.Path]::DirectorySeparatorChar + $fqdn
        }

        return ""
    }

    $machineShare = Get-MachineShare -fqdn $fqdn -targetPath $targetPath    
    $destinationNetworkPath = Get-DestinationNetworkPath -targetPath $targetPath -machineShare $machineShare
    
    Validate-Credential $credential
    $userName = Get-DownLevelLogonName -fqdn $fqdn -userName $($credential.UserName)
    $password = $($credential.Password) 

    if($machineShare)
    {
        $command = "net use `"$machineShare`""
        if($userName)
        {
            $command += " /user:`"$userName`" `'$($password -replace "['`]", '$&$&')`'"
        }
        $command += " 2>&1"
        
        $dtl_mapOut = iex $command
        if ($LASTEXITCODE -ne 0) 
        {
            $errorMessage = (Get-LocalizedString -Key "Failed to connect to the path {0} with the user {1} for monitoring.`n" -ArgumentList $machineShare, $($credential.UserName)) + $dtl_mapOut
            ThrowError -errorMessage $errorMessage -fqdn $fqdn
        }
    }

    try
    {
        if($isFileMonitor -and $doCleanUp -and (Test-Path -path $destinationNetworkPath -pathtype container))
        {
            Get-ChildItem -Path $destinationNetworkPath -Recurse -force | Remove-Item -force -recurse;
            $output = Remove-Item -path $destinationNetworkPath -force -recurse 2>&1
            $err = $output | ?{$_.gettype().Name -eq "ErrorRecord"}
            if($err)
            {
                Write-Verbose -Verbose "Error occurred while deleting the destination folder: $err"
            }
        }
		
		$monitorParameters = Get-MonitorParameters -additionalArguments $additionalArguments

		# Get *.json filenames to look for
		$jsonFiles = Array-ToHash($filesToMonitor)

		if(-not $jsonFiles)
		{
			$errorMessage = Get-LocalizedString -Key "Monitoring failed, found no package files in $sourceDirectory. Consult the logs for more details."            
            ThrowError -errorMessage $errorMessage -fqdn $fqdn
		}
		else
		{
			Write-Verbose "Monitoring $($destinationNetworkPath) for $($jsonFiles.count) *.json files."

			if(Test-Path -path $destinationNetworkPath -pathtype container)
			{
				$progress = 0
				$sleepParam = if ($monitorParameters.Sleep -ne $null) { $monitorParameters.Sleep } else { 60 }
				$timeoutParam = if ($monitorParameters.Timeout -ne $null) { $monitorParameters.Timeout } else { 10 }

				foreach ($h in $jsonFiles.GetEnumerator())
				{
					Write-Host "Looking for $($h.Value)..."

					$targetJsonPath = Join-Path -ChildPath $($h.Value) -Path $destinationNetworkPath
					$found = $true
										
					$timeout = new-timespan -Minutes $timeoutParam
					$sw = [diagnostics.stopwatch]::StartNew()

					:inner while(!(Test-Path $targetJsonPath)) 
					{
						if ($sw.elapsed -gt $timeout) 
						{
							Write-Verbose "$($sw.elapsed.minutes) minutes have passed without finding $($h.Value), skipping."
							$found = $false
							break inner
						}

						Start-Sleep -s 60;
						Write-Host "##vso[task.setprogress value=$(($progress++/($jsonFiles.count * 10)) * 100);]Install Progress Indicator"
					}

					if (-not $found)
					{
						$errorMessage = Get-LocalizedString -Key "Monitoring failed. Consult the logs for more details."            
						ThrowError -errorMessage $errorMessage -fqdn $fqdn            
					}
					else
					{            
						#json file found, check package installation status
						$j = (Get-Content $targetJsonPath) -Join "`n" | ConvertFrom-Json
						$message = (Get-LocalizedString -Key "Package installation status: {0} on machine {1}. View the package deployment history at {2} for more details." -ArgumentList $j.Status, $j.ServerName, $j.DeployHistoryPath)
						
						if($j.Status -eq "Success"){
							Write-Output $message  
						}
						else
						{
							ThrowError -errorMessage $message -fqdn $fqdn 
						}
					} 
				}
			}
		}
    }
    finally
    {
        if($machineShare)
        {
            net use $machineShare /D /Y;  
        }
    }
}
