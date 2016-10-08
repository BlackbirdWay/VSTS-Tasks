# Sitecore Package Deployer Monitor Task
### Overview
This Visual Studio Team Setvice (VSTS) Custom Build Task is used to monitor for **Team Development for Sitecore** (TDS) update package .json notification files. They are deposited in the **Sitecore Package Deployer** folder on the Windows Machine(s) hosting **Sitecore** instance(s). This task provides the ability to monitor TDS .json notification files on Windows Machines. The task uses PowerShell and WinRM to monitor the package insatallation status.

###The different parameters of the task are explained below:

* **Source**: The source of the files. As described above using pre-defined system variables like $(Build.Repository.LocalPath) make it easy to specify the location of the build on the Build Automation Agent machine. The variables resolve to the working folder on the agent machine, when the task is run on it. Wild cards like **\*.zip are not supported.
* **Machines**: Specify comma separated list of machine FQDNs/ip addresses along with port(optional). For example scserver.ascii63software.com, scserver_int.ascii63software.com:5986,192.168.01.01:5986.  
* **Admin Login**: Domain/Local administrator of the target host. Format: &lt;Domain or hostname&gt;\&lt; Admin User&gt;.  
* **Password**:  Password for the admin login. It can accept variable defined in Build/Release definitions as '$(passwordVariable)'. You may mark variable type as 'secret' to secure it.  
* **Destination Folder**: The folder in the Windows machines where the files will be monitored. An example of the destination folder is C:\Sites\Sitecore\Data\SitecorePackageDeployer.
* **Clean Target**: Checking this option will clean the destination folder prior to monitoring the files in it.

###Installing Task

* https://marketplace.visualstudio.com/items?itemName=josearivera.Sitecore-Package-Deployer-Monitor

###How it works

TBD

###More information

* Visit Hedgehog Development's [Sitecore Package Deployer](http://www.hhogdev.com/blog/2015/september/sitecore-package-deployer.aspx) page or [GitHub repo](https://github.com/HedgehogDevelopment/SitecorePackageDeployer) to learn more.
* You can find out more on how to create a VSTS custom build task by visiting the [Add a build task](https://www.visualstudio.com/en-us/docs/integrate/extensions/develop/add-build-task) page.