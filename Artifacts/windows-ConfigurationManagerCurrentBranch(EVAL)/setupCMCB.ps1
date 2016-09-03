Param(
  [string]$SiteCode = 'TST',
  [string]$SiteName = 'Test Site'
)

cd $($PSScriptRoot)

if((gwmi win32_computersystem).partofdomain -eq $false)
{
Install-windowsfeature AD-domain-services
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false `
 -DatabasePath "C:\Windows\NTDS" `
 -DomainMode "Win2012R2" `
 -DomainName "contoso.com" `
 -DomainNetbiosName "contoso" `
 -ForestMode "Win2012R2" `
 -InstallDns:$true `
 -LogPath "C:\Windows\NTDS" `
 -NoRebootOnCompletion:$false `
 -SysvolPath "C:\Windows\SYSVOL" `
 -Force:$true `
 -SafeModeAdministratorPassword (ConvertTo-SecureString 'P@ssw0rd' –AsPlainText –Force)

 #restart-computer -Force
 } else  {

 if(!(Test-Path c:\sccmsetup.ini))
{
    $hostname = [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname;
    '[Identification]' | out-file -filepath C:\sccmsetup.ini
    'Action=InstallPrimarySite' | out-file -filepath C:\sccmsetup.ini -append 
    '[Options]' | out-file -filepath C:\sccmsetup.ini -append  
    'ProductID="EVAL"' | out-file -filepath C:\sccmsetup.ini -append  
    'PrerequisiteComp=0' | out-file -filepath C:\sccmsetup.ini -append 
    'PrerequisitePath="C:\SCCMDownloads"' | out-file -filepath C:\sccmsetup.ini -append 
    "SiteCode=$($SiteCode)" | out-file -filepath C:\sccmsetup.ini -append 
    'SiteName="' + $SiteName + '"' | out-file -filepath C:\sccmsetup.ini -append 
    'SMSInstallDir="C:\Microsoft Configuration Manager"' | out-file -filepath C:\sccmsetup.ini -append  
    "SDKServer=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
    'AdminConsole=1' | out-file -filepath C:\sccmsetup.ini -append 
    'JoinCEIP=0' | out-file -filepath C:\sccmsetup.ini -append 
    'RoleCommunicationProtocol=HTTPorHTTPS' | out-file -filepath C:\sccmsetup.ini -append 
    'ClientsUsePKICertificate=0' | out-file -filepath C:\sccmsetup.ini -append 
    'AddServerLanguages=' | out-file -filepath C:\sccmsetup.ini -append 
    'AddClientLanguages=DEU' | out-file -filepath C:\sccmsetup.ini -append 
    'MobileDeviceLanguage=0' | out-file -filepath C:\sccmsetup.ini -append 
    "ManagementPoint=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
    'ManagementPointProtocol=HTTP' | out-file -filepath C:\sccmsetup.ini -append 
    "DistributionPoint=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
    'DistributionPointProtocol=HTTP' | out-file -filepath C:\sccmsetup.ini -append 
    'DistributionPointInstallIIS=0' | out-file -filepath C:\sccmsetup.ini -append  
    '[SQLConfigOptions]' | out-file -filepath C:\sccmsetup.ini -append 
    "SQLServerName=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
    'DatabaseName=CM_TST' | out-file -filepath C:\sccmsetup.ini -append 
    'SQLSSBPort=4022' | out-file -filepath C:\sccmsetup.ini -append 
    '[HierarchyExpansionOption]' | out-file -filepath C:\sccmsetup.ini -append 
}

    #Add LocalSystem as SysAdmin
    #GITHUB Link : https://github.com/codykonior/HackSql
    $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    $services = Get-Service | Where { ($_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*') -and $_.Status -eq "Running" }
    foreach ($service in $services) {
        if ($service.Name -eq "MSSQLSERVER") {
            $sqlName = ".\"
        } else {
            $sqlName = ".\$($service.Name.Substring(6))"
        }

        Write-Host "Attempting $sqlName"
        $serviceProcess = Get-WmiObject -Class Win32_Service -Filter "Name = '$($service.Name)'"

        Invoke-TokenManipulation -ProcessId $serviceProcess.ProcessID -ImpersonateUser | Out-Null
        $impersonatedUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-Host "Service $($service.Name) on PID $($serviceProcess.ProcessID) will connect to $sqlName as $impersonatedUser"

        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$sqlName;Trusted_Connection=True")
        $sqlConnection.Open()
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand("If Not Exists (Select Top 1 0 From sys.server_principals Where name = '$userName')
    Begin
        Create Login [$userName] From Windows
    End

    If Not Exists (Select Top 1 0 From master.sys.server_principals sp Join master.sys.server_role_members srp On sp.principal_id = srp.member_principal_id Join master.sys.server_principals spr On srp.role_principal_id = spr.principal_id Where sp.name = '$userName' And spr.name = 'sysadmin')
    Begin
        Exec sp_addsrvrolemember '$userName', 'sysadmin'
    End", $sqlConnection)
        $sqlCommand.ExecuteNonQuery() | Out-Null
        $sqlConnection.Close()
        Invoke-TokenManipulation -RevToSelf | Out-Null
    }

    #Set SQL to run as LocalSystem
    $service = gwmi win32_service -filter "name='MSSQLSERVER'"
    $service.Change($null, $null, $null, $null, $null, $null, "LocalSystem", $null, $null, $null, $null)
    Stop-Service 'MSSQLSERVER' -Force
    Start-Service 'MSSQLSERVER'

    #Copy-Item .\sccmsetup.ini c:\ -Force
    #& ".\MSSQLServer2016_setup.exe"
    & ".\ADK10_setup.exe"
    & ".\CMCB_setup.exe"
 }