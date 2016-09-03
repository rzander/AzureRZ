#Add Domain Admins as Full Admins
import-module ("C:\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1")  
new-psdrive -Name "T01" -PSProvider "AdminUI.PS.Provider\CMSite" -Root "localhost"
cd ((Get-PSDrive -PSProvider CMSite).Name + ':')
    
New-CMAdministrativeUser -Name "$($env:userdomain)\domain admins" -RoleName "Full Administrator"