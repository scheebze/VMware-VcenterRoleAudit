#transcripting
Stop-Transcript | out-null
$logspath = $PSScriptRoot + "\" + ("{0:yyyyMMdd}_LockedVMDisk_Consolidation.log" -f (get-date))  
Start-Transcript -path $logspath -append

#Create Feature Array
$Featurescheck = [PSCustomObject]@{
    PasswordImport = $false
    VCenterImport = $true
    Roleimport = $false
}

#Define Roles to Audit
if($feature.Roleimport -eq $true){
    $AuditRoleImportfile = $PSScriptRoot + "\Auditrolefile.txt"
    $Auditroles = get-content $AuditRoleImportfile
}
if($feature.Roleimport -eq $false){
    $Auditroles = @(
        "veeam"
    )
}

#Define VCenters to Audit for Role
if($feature.VCenterImport -eq $true){
    $VcentersImportFile = $PSScriptRoot + "\VCenters.csv"
    $Vcenters = import-csv $VcentersImportFile
}
if($feature.VCenterImport -eq $false){
    $Vcenters = @(
        [PSCustomObject]@{
            VCenterName = "vcsa-85989.ddc4ae00.us-east4.gve.goog";
            Domain = "us.deloitte.com" 
        }
        [PSCustomObject]@{
            VCenterName = "vcenter2.test2.com";
            Domain = "test2.com" 
        }
    )
}

#Region Connect to Vcenters

if($global:DefaultVIServers){
    Disconnect-VIServer -Server $global:DefaultVIServers -confirm:$False -Force | out-null
}

#Define Credential hash

$Domains = $vcenters | select -ExpandProperty domain -Unique

$credentials = @()
foreach($domain in $domains){
    write-host "Getting Credentials for $domain"
    $credential = @()
    $Credential = [PSCustomObject]@{
        Domain = $domain
        Cred = (Get-Credential -Message "Provide Credential for $domain")
    }
    $credentials += $credential
}

#Connect to Vcenter
Foreach ($Vcenter in $Vcenters){

    $vcentercreds = @()
    $vcentercreds = $credentials | where {$_.domain -eq $vcenter.domain} | select -ExpandProperty Cred
    

    try{
        connect-viserver -server $vcenter.VCenterName -Credential $vcentercreds -force -erroraction stop  
    }Catch{
        write-host "Could not connect to $vcenter." -ForegroundColor Red
    }
}

#EndRegion Connect to Vcenters

#Region Get Role and Privileges
Foreach($vcenter in $Vcenters){
    #Check to see if the role exists
}

#EndRegion Get Role and Privileges