# Sitecore Package Deployer Monitor Task
### Overview
The task is used to monitor Team Development for Sitecore (TDS) update package files that are required to install the packages on Windows Machines including files and Sitecore content items. The task provides the ability to monitor files on Windows Machines. The tasks uses PowerShell to monitor the package insatallation status.

###The different parameters of the task are explained below:

*	**Source**: The source of the files. As described above using pre-defined system variables like $(Build.Repository.LocalPath) make it easy to specify the location of the build on the Build Automation Agent machine. The variables resolve to the working folder on the agent machine, when the task is run on it. Wild cards like **\*.zip are not supported.
* **Machines**: Specify comma separated list of machine FQDNs/ip addresses along with port(optional). For example dbserver.fabrikam.com, dbserver_int.fabrikam.com:5986,192.168.34:5986.  
* **Admin Login**: Domain/Local administrator of the target host. Format: &lt;Domain or hostname&gt;\ &lt; Admin User&gt;.  
* **Password**:  Password for the admin login. It can accept variable defined in Build/Release definitions as '$(passwordVariable)'. You may mark variable type as 'secret' to secure it.  
*	**Destination Folder**: The folder in the Windows machines where the files will be monitored. An example of the destination folder is c:\FabrikamFibre\Web.
*	**Clean Target**: Checking this option will clean the destination folder prior to monitoring the files in it.