$FilePath = "C:\code\VMware-VcenterRoleAudit"

#transcripting
Stop-Transcript | out-null
$logspath = $FilePath + "\" + ("{0:yyyyMMdd}_VCenterRole_Audit.log" -f (get-date))  
Start-Transcript -path $logspath -append

$outputpath = $FilePath + "\" + ("{0:yyyyMMdd}_VCenterRoleAudit.xlsx" -f (get-date)) 

#Create Feature Array
$Featurescheck = [PSCustomObject]@{
    PasswordImport = $false
    VCenterImport = $true
    Roleimport = $false
}

#Define Roles to Audit
if($Featurescheck.Roleimport -eq $true){
    $AuditRoleImportfile = $FilePath + "\Auditrolefile.txt"
    $Auditroles = get-content $AuditRoleImportfile
}
if($Featurescheck.Roleimport -eq $false){
    $Roles = @(
        "veeam"
    )
}

#Define VCenters to Audit for Role
if($Featurescheck.VCenterImport -eq $true){
    $VcentersImportFile = $FilePath + "\VCenters.csv"
    $Vcenters = import-csv $VcentersImportFile
}
if($Featurescheck.VCenterImport -eq $false){
    $Vcenters = @(
        [PSCustomObject]@{
            VCenterName = "vcenter1.test1.com";
            Domain = "test1.com" 
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
        write-host "Successfully connected to $($vcenter.VCenterName)." -ForegroundColor Green
    }Catch{
        write-host "Could not connect to $($vcenter.VCenterName)." -ForegroundColor Red
    }
}

#EndRegion Connect to Vcenters

#Region Define Role Privileges

#Veeam Role Privileges
$VeeamPrivileges = @(
    "Cryptographer.Access",
    "Cryptographer.AddDisk",
    "Cryptographer.Encrypt",
    "Cryptographer.EncryptNew",
    "Cryptographer.Migrate",
    "Datastore.AllocateSpace",
    "Datastore.Browse",
    "Datastore.Config",
    "Datastore.DeleteFile",
    "Datastore.FileManagement",
    "DVPortgroup.Create",
    "DVPortgroup.Delete",
    "DVPortgroup.Modify",
    "Extension.Register",
    "Extension.Unregister",
    "Folder.Create",
    "Folder.Delete",
    "Global.DisableMethods",
    "Global.EnableMethods",
    "Global.Licenses",
    "Global.LogEvent",
    "Global.ManageCustomFields",
    "Global.SetCustomField",
    "Global.Settings",
    "Host.Cim.CimInteraction",
    "Host.Config.AdvancedConfig",
    "Host.Config.Maintenance",
    "Host.Config.Network",
    "Host.Config.Patch",
    "Host.Config.Storage",
    "InventoryService.Tagging.AttachTag",
    "InventoryService.Tagging.CreateCategory",
    "InventoryService.Tagging.CreateTag",
    "InventoryService.Tagging.DeleteCategory",
    "InventoryService.Tagging.DeleteTag",
    "InventoryService.Tagging.EditCategory",
    "InventoryService.Tagging.EditTag",
    "InventoryService.Tagging.ModifyUsedByForCategory",
    "InventoryService.Tagging.ModifyUsedByForTag",
    "InventoryService.Tagging.ObjectAttachable",
    "Network.Assign",
    "Network.Config",
    "Resource.AssignVMToPool",
    "Resource.ColdMigrate",
    "Resource.CreatePool",
    "Resource.DeletePool",
    "Resource.HotMigrate",
    "StoragePod.Config",
    "StorageProfile.Update",
    "StorageProfile.View",
    "System.Anonymous",
    "System.Read",
    "System.View",
    "VApp.AssignResourcePool",
    "VApp.AssignVM",
    "VApp.Unregister",
    "VirtualMachine.Config.AddExistingDisk",
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.AddRemoveDevice",
    "VirtualMachine.Config.AdvancedConfig",
    "VirtualMachine.Config.Annotation",
    "VirtualMachine.Config.ChangeTracking",
    "VirtualMachine.Config.DiskExtend",
    "VirtualMachine.Config.DiskLease",
    "VirtualMachine.Config.EditDevice",
    "VirtualMachine.Config.RawDevice",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Config.Rename",
    "VirtualMachine.Config.Resource",
    "VirtualMachine.Config.Settings",
    "VirtualMachine.GuestOperations.Execute",
    "VirtualMachine.GuestOperations.Modify",
    "VirtualMachine.GuestOperations.Query",
    "VirtualMachine.Interact.ConsoleInteract",
    "VirtualMachine.Interact.DeviceConnection",
    "VirtualMachine.Interact.GuestControl",
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Interact.PowerOn",
    "VirtualMachine.Interact.SetCDMedia",
    "VirtualMachine.Interact.SetFloppyMedia",
    "VirtualMachine.Interact.Suspend",
    "VirtualMachine.Inventory.Create",
    "VirtualMachine.Inventory.CreateFromExisting",
    "VirtualMachine.Inventory.Delete",
    "VirtualMachine.Inventory.Register",
    "VirtualMachine.Inventory.Unregister",
    "VirtualMachine.Provisioning.DiskRandomAccess",
    "VirtualMachine.Provisioning.DiskRandomRead",
    "VirtualMachine.Provisioning.GetVmFiles",
    "VirtualMachine.Provisioning.MarkAsTemplate",
    "VirtualMachine.Provisioning.MarkAsVM",
    "VirtualMachine.Provisioning.PutVmFiles",
    "VirtualMachine.State.CreateSnapshot",
    "VirtualMachine.State.RemoveSnapshot",
    "VirtualMachine.State.RenameSnapshot",
    "VirtualMachine.State.RevertToSnapshot"
)

#EndRegion Define Role Privileges

#Region Get Role and Privileges
Foreach($vcenter in $Vcenters){
    write-host "Working on $($vcenter.VCenterName)" -ForegroundColor Cyan
    Write-Host "Getting Role information" -ForegroundColor Yellow

    $VCenterData = @()

    foreach ($role in $Roles){

        write-host "$role" -ForegroundColor Yellow
        $RoleData = @()
        
        if($vcenter.VCenterName -in ($global:DefaultVIServers.name)){
            
            $rolesearch = @()
            $rolesearch = (get-virole -Name $role -server $vcenter.VCenterName).PrivilegeList

            if ($rolesearch){
                Write-host "$role exists on $($vcenter.VCenterName)"

                $Variablerolesearchname = $role + "privileges"
                $variablesearch = Get-Variable -name $Variablerolesearchname

                if($variablesearch){
                    foreach ($item in $variablesearch.Value){
                        if($item -in $rolesearch){
                            Write-host "$item is present in $role on $($vcenter.VCenterName)" -ForegroundColor Green
                            $PrivilegeItemStatus = "Existing"
                        }
                        else{
                            Write-host "$item is not present in $role on $($vcenter.VCenterName)" -ForegroundColor Magenta
                            Write-host "Attempting remediation on $item."

                            try{
                                Set-VIRole -Role $role -AddPrivilege $item -Confirm:$false -WhatIf -ErrorAction Stop
                                write-host "Successfully added $item to $role on $($vcenter.VCenterName)" -ForegroundColor Green
                                $PrivilegeItemStatus = "Remediated"
                            }
                            catch{
                                write-host "Failed to add $item to $role on $($vcenter.VCenterName)" -ForegroundColor Red
                                $PrivilegeItemStatus = "Remediation Failed"
                            }
                        }
                        $PrivilegeItemData = @()
                        $PrivilegeItemData = [PSCustomObject]@{
                            Role = $Role
                            PrivilegeName = $item
                            PrivilegeItemStatus = $PrivilegeItemStatus
                            VCenterName = $vcenter.VCenterName
                        }
                        $RoleData +=  $PrivilegeItemData
                    }
                }
                else{
                    write-host "No configuration for $role in script" -ForegroundColor Red
                    $PrivilegeItemData = @()
                    $PrivilegeItemData = [PSCustomObject]@{
                        Role = $Role
                        PrivilegeName = "No configuration for $role in script"
                        PrivilegeItemStatus = "No configuration for $role in script"
                        VCenterName = $vcenter.VCenterName
                    }
                    $RoleData +=  $PrivilegeItemData
                }
            }
            else{
                write-host "$role doesn't exist on $($vcenter.VCenterName)" -ForegroundColor Magenta
                $PrivilegeItemData = @()
                $PrivilegeItemData = [PSCustomObject]@{
                    Role = $Role
                    PrivilegeName = "Role $Role Doesn't Exist"
                    PrivilegeItemStatus = "Role $Role Doesn't Exist"
                    VCenterName = $vcenter.VCenterName
                }
                $RoleData +=  $PrivilegeItemData
            }         
        }
        else{
            Write-Host "Couldn't connect to $($vcenter.VCenterName)" -ForegroundColor Magenta

            $PrivilegeItemData = @()
            $PrivilegeItemData = [PSCustomObject]@{
                Role = $Role
                PrivilegeName = "Couldn't connect to VCenter"
                PrivilegeItemStatus = "Couldn't connect to VCenter"
                VCenterName = $vcenter.VCenterName
            }
            $RoleData +=  $PrivilegeItemData
        }

        foreach($item in $RoleData){
            $vcenterdata += $item
        }
    }
}

#EndRegion Get Role and Privileges
