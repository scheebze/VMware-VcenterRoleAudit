$FilePath = "C:\code\VMware-VcenterRoleAudit"

#transcripting
Stop-Transcript | out-null
$logspath = $FilePath + "\" + ("{0:yyyyMMdd}_VCenterRole_AuditRemediation.log" -f (get-date))  
Start-Transcript -path $logspath -append

$outputpath = $FilePath + "\" + ("{0:yyyyMMdd}_VCenterRoleAuditRemediation.xlsx" -f (get-date)) 


Write-host "Detecting if PowerCLI is available"
$PowerCLI = Get-Module -ListAvailable VMware.PowerCLI
if (!$PowerCLI) {
    Throw 'The PowerCLI module must be installed to continue'
}

#Create Feature Array
$Featurescheck = [PSCustomObject]@{
    PasswordImport = $false
    VCenterImport = $false
    Roleimport = $false
}

#Define Roles to Audit
if($Featurescheck.Roleimport -eq $true){
    $AuditRoleImportfile = $FilePath + "\Auditrolefile.txt"
    $Roles = get-content $AuditRoleImportfile
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

    Write-host "Building Privilege Item Mapping"
    $privilegeMap = @()
    Get-VIPrivilege -server $vcenter.VCenterName | foreach{
        $privilegeitemmap = [PSCustomObject]@{
            Name = $_.Name
            PrivID = $_.ExtensionData.PrivID
            }
        $privilegeMap += $privilegeitemmap
    }

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
                    foreach ($Privilegeitem in $variablesearch.Value){
                        if($Privilegeitem -in $rolesearch){
                            Write-host "$Privilegeitem is present in $role on $($vcenter.VCenterName)" -ForegroundColor Green
                            $PrivilegeItemStatus = "Existing"
                        }
                        else{
                            Write-host "$Privilegeitem is not present in $role on $($vcenter.VCenterName)" -ForegroundColor Magenta
                            Write-host "Attempting remediation on $Privilegeitem."

                            try{
                                #get's the privilege item information to feed into the setvirole
                                $privilegeitemadd = @()
                                $privilegeitemadd = Get-VIPrivilege -server $vcenter.vcentername | where {$_.extensiondata.privid -eq $privilegeitem} -ErrorAction stop

                                Set-VIRole -Role $role -AddPrivilege $privilegeitemadd -Confirm:$false -ErrorAction Stop
                                write-host "Successfully added $Privilegeitem to $role on $($vcenter.VCenterName)" -ForegroundColor Green
                                $PrivilegeItemStatus = "Remediated"
                            }
                            catch{
                                write-host "Failed to add $Privilegeitem to $role on $($vcenter.VCenterName)" -ForegroundColor Red
                                $PrivilegeItemStatus = "Remediation Failed"
                            }
                        }
                        $PrivilegeItemData = @()
                        $PrivilegeItemData = [PSCustomObject]@{
                            Role = $Role
                            PrivilegeName = $Privilegeitem
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
 
#Region Build Excel Spreadsheet
Write-host "Building Spreadsheet" -ForegroundColor Yellow

$excel = New-Object -ComObject excel.application
$excel.visible = $true

## --- Add Workbook and Sheets --- ##
$workbook = $excel.workbooks.add()

$sheet1= $workbook.Worksheets.Item(1) 
$sheet1.Name = 'All_Data'

## --- Create Column Titles --- ##
$sheet1.Cells.Item(1,1) = "Role"
$sheet1.Cells.Item(1,2) = "PrivilegeName"
$sheet1.Cells.Item(1,3) = "PrivilegeItemStatus"
$sheet1.Cells.Item(1,4) = "VCenterName"

## --- adding rows to worksheet --- ##
$a = 1
$vcenterdatacount = ($vcenterdata).count

$x = 2
foreach ($vcenterdataitem in $vcenterdata){
write-host "adding item $a of $vcenterdatacount" 
$sheet1.Cells.Item($x,1) = $vcenterdataitem.Role
$sheet1.Cells.Item($x,2) = $vcenterdataitem.PrivilegeName
$sheet1.Cells.Item($x,3) = $vcenterdataitem.PrivilegeItemStatus
$sheet1.Cells.Item($x,4) = $vcenterdataitem.VCenterName

$x++
$a++

}

#Add Worksheet and set name
$workbook.Worksheets.add() 
$sheet2= $workbook.Worksheets.item(1) 
$sheet2.Name = "Charts"

## --- Create Column Titles --- ##
$sheet2.Cells.Item(1,1) = "VCenterName"
$sheet2.Cells.Item(1,2) = "Failed"
$sheet2.Cells.Item(1,3) = "Remediated"
$sheet2.Cells.Item(1,4) = "Existing"

$Sheet2Vcenters = $vcenterdata | select -ExpandProperty VCenterName -Unique

$x = 2
#Add data to Worksheet - basically a pivot
foreach ($Sheet2vcenter in $Sheet2Vcenters){
    $Failedcount = @()
    $existingcount = @()
    $RemediatedCount = @()
    $TotalCount = @()

    $totalcount = ($vcenterdata | where {$_.VCenterName -eq $Sheet2vcenter}).count
    $Failedcount = ($vcenterdata | where {$_.VCenterName -eq $Sheet2vcenter -and $_.PrivilegeItemStatus -eq "Remediation Failed"}).count
    $RemediatedCount = ($vcenterdata | where {$_.VCenterName -eq $Sheet2vcenter -and $_.PrivilegeItemStatus -eq "Remediated"}).count
    $existingcount = ($vcenterdata | where {$_.VCenterName -eq $Sheet2vcenter -and $_.PrivilegeItemStatus -eq "Existing"}).count

    $sheet2.Cells.Item($x,1) = $Sheet2vcenter
    $sheet2.Cells.Item($x,2) = $Failedcount
    $sheet2.Cells.Item($x,3) = $RemediatedCount
    $sheet2.Cells.Item($x,4) = $existingcount

    $x++

}

#Identify Data for Chart
$dataforchart = $sheet2.Range("A1").CurrentRegion

#Adding Chart to Sheet
$Chart1 = $sheet2.Shapes.AddChart().Chart

#Provide Chart Type
$ChartType1 = [Microsoft.Office.Interop.Excel.XLChartType]
$chart1.ChartType = $ChartType1::xlBarClustered

#Provide Source Data
$chart1.SetSourceData($dataforchart)

#Provide Title to chart
$chart1.HasTitle = $true
$Chart1.ChartTitle.Text = "Remediation Status"

#Save Excel File
$workbook.SaveAs($outputpath) 
$excel.Quit()

#EndRegion Build Excel Spreadsheet