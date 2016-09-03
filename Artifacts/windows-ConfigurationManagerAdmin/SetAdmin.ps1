#Add Domain Admins as Full Admins
import-module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)  
new-psdrive -Name $SiteCode -PSProvider "AdminUI.PS.Provider\CMSite" -Root "localhost"
cd ((Get-PSDrive -PSProvider CMSite).Name + ':')
    
New-CMAdministrativeUser -Name "$($env:userdomain)\domain admins" -RoleName "Full Administrator"