$MonitorSPDJob = {
param (
    [string]$fqdn, 
    [string]$sourcePath,
    [string]$targetPath,
    [object]$credential,
    [string]$cleanTargetBeforeMonitor,
	[string]$winRMPort,
	[string]$httpProtocolOption,
	[string]$skipCACheckOption
    )

    Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\*.dll | % {
    [void][reflection.assembly]::LoadFrom( $_.FullName )
    Write-Verbose "Loading .NET assembly:`t$($_.name)"
    }

    Get-ChildItem $env:AGENT_HOMEDIRECTORY\Agent\Worker\Modules\Microsoft.TeamFoundation.DistributedTask.Task.DevTestLabs\*.dll | % {
    [void][reflection.assembly]::LoadFrom( $_.FullName )
    Write-Verbose "Loading .NET assembly:`t$($_.name)"
    }

	$cleanTargetPathOption = ''
	if($cleanTargetBeforeMonitor -eq "true")
    {
		$cleanTargetPathOption = '-CleanTargetPath'
    }

    Write-Verbose "Initiating Monitor on $fqdn "

   	[String]$sitecorePackageDeployerMonitorBlockString = "SitecorePackageDeployerMonitor -MachineDnsName $fqdn -SourcePath `$sourcePath -DestinationPath `$targetPath -Credential `$credential -WinRMPort $winRMPort $cleanTargetPathOption $skipCACheckOption $httpProtocolOption"	
		
	[scriptblock]$sitecorePackageDeployerMonitorBlock = [scriptblock]::Create($sitecorePackageDeployerMonitorBlockString)
	
	$monitorResponse = Invoke-Command -ScriptBlock $sitecorePackageDeployerMonitorBlock
    
    Write-Output $monitorResponse
}