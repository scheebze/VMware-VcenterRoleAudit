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
    $Auditroles = @(
        "veeam",
        "ReadOnly"
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

#Region Get Role and Privileges
$AllData = @()
Foreach($vcenter in $Vcenters){
    write-host "Working on $($vcenter.VCenterName)" -ForegroundColor Yellow
    $PrivilegesReport = @()

    Write-Host "Getting Role information" -ForegroundColor Yellow
    foreach ($role in $Auditroles){
        if($vcenter.VCenterName -in ($global:DefaultVIServers.name)){
            $rolesearch = @()
            $rolesearch = (get-virole -Name $role).PrivilegeList

            if ($rolesearch){    
                Write-host "$role exists on $($vcenter.VCenterName)" 
                foreach ($item in $rolesearch){
                    $privileges = @()
                    $privileges = [PSCustomObject]@{
                        Role = $Role
                        PrivilegeName = $item
                        VCenterName = $vcenter.VCenterName
                    }
                    $PrivilegesReport +=  $privileges
                } 
            }
            else {
                write-host "$role doesn't exist on $($vcenter.VCenterName)" -ForegroundColor Magenta
                $privileges = @()
                $privileges = [PSCustomObject]@{
                    Role = $Role
                    PrivilegeName = "Role $Role Doesn't Exist"
                    VCenterName = $vcenter.VCenterName
                }
                $PrivilegesReport +=  $privileges
            }
        }
        else{
            Write-Host "Couldn't connect to $($vcenter.VCenterName)" -ForegroundColor Magenta
            $privileges = @()
            $privileges = [PSCustomObject]@{
                Role = $Role
                PrivilegeName = "Couldn't connect to VCenter" 
                VCenterName = $vcenter.VCenterName
            }
            $PrivilegesReport +=  $privileges
        }
    }

    write-host "Getting Privilege Information" -ForegroundColor Yellow
    $privilegeinfo = @()
    if($vcenter.VCenterName -in ($global:DefaultVIServers.name)){
        Get-VIPrivilege -Server $vcenter.VCenterName | foreach{
            $privilegeinfoitem = @()
            $privilegeinfoitem = [PSCustomObject]@{
                PrivID = $_.ExtensionData.PrivID
                PrivGroupName = $_.ExtensionData.PrivGroupName
                Privname = $_.Name
                PrivDescription = $_.Description
            }
            $privilegeinfo += $privilegeinfoitem
        }
    }else{
        Write-Host "Couldn't connect to $($vcenter.VCenterName)" -ForegroundColor Magenta
        $privilegeinfoitem = @()
        $privilegeinfoitem = [PSCustomObject]@{
            PrivID = "Couldn't connect to VCenter"
            PrivGroupName = "Couldn't connect to VCenter"
            Privname = "Couldn't connect to VCenter"
            PrivDescription = "Couldn't connect to VCenter"
        }
        $privilegeinfo += $privilegeinfoitem
    }


    Write-host "Combining Role and Privilege info" -ForegroundColor Yellow
    $VCenterData = @()
    
    foreach ($item in $PrivilegesReport){
        $filter = @()
        $filter = $privilegeinfo | where {$_.PrivID -eq $item.PrivilegeName}
  
        if($filter){
            #build Data Report
            $Row = @()
            $Row = [PSCustomObject]@{
                Role = $item.Role
                PrivilegeName = $item.PrivilegeName
                PrivilegeGroupName = $filter.PrivGroupName
                PrivilegeDescription = $filter.PrivDescription
                VCenterName = $vcenter.VCenterName
            }
        }else{
            #build Data Report
            $Row = @()
            $Row = [PSCustomObject]@{
                Role = $item.Role
                PrivilegeName = $item.PrivilegeName
                PrivilegeGroupName = "N/A"
                PrivilegeDescription = "N/A"
                VCenterName = $vcenter.VCenterName
            }
        }
        

        $VCenterData += $Row
    }

    Write-host "Adding VCenter Data to All Data" -ForegroundColor Yellow
    foreach($item in $VCenterData){
        $AllData += $item
    }
}
#EndRegion Get Role and Privileges

#Region Build Excel Spreadsheet
Write-host "Building Spreadsheet" -ForegroundColor Yellow

$excel = New-Object -ComObject excel.application
$excel.visible = $true

#Region Sheet 1 All_Data

## --- Add Workbook and Sheets --- ##
$workbook = $excel.workbooks.add()

$sheet1= $workbook.Worksheets.Item(1) 
$sheet1.Name = 'All_Data'

## --- Create Column Titles --- ##
$sheet1.Cells.Item(1,1) = "Role"
$sheet1.Cells.Item(1,2) = "PrivilegeName"
$sheet1.Cells.Item(1,3) = "PrivilegeGroupName"
$sheet1.Cells.Item(1,4) = "PrivilegeDescription"
$sheet1.Cells.Item(1,5) = "VCenterName"

## --- adding rows to worksheet --- ##
$a = 1
$AllDatacount = ($AllData).count

$x = 2
foreach ($item in $AllData){
write-host "adding item $a of $AllDatacount" 
$sheet1.Cells.Item($x,1) = $item.Role
$sheet1.Cells.Item($x,2) = $item.PrivilegeName
$sheet1.Cells.Item($x,3) = $item.PrivilegeGroupName
$sheet1.Cells.Item($x,4) = $item.PrivilegeDescription
$sheet1.Cells.Item($x,5) = $item.VCenterName

$x++
$a++

}

#EndRegion Sheet 1 All_Data

#Region Audit_Review
foreach ($role in $Auditroles){
    #Empty Reused Arrays
    $sheet2 = @()
    $roledata = @()
    $Sheetname = @()
    $privilegelist = @()

    #Filter All data on Role
    $roledata = $AllData | where {$_.Role -eq $role}

    #Set Sheet name
    $Sheetname = $role + '_Audit'

    #Add Worksheet and set name
    $workbook.Worksheets.add() 
    $sheet2= $workbook.Worksheets.item(1) 
    $sheet2.Name = $Sheetname

    ## --- Create Column Titles --- ##
    $sheet2.Cells.Item(1,1) = "PrivilegeName"
    $column = 2
    foreach ($vcenter in $vcenters){
        $sheet2.Cells.Item(1,$column) = $vcenter.VCenterName
        $column++ 
    }
    
    #Identify Privilege List
    $privilegelist = $roledata | select -Unique -ExpandProperty PrivilegeName
    
    #Create first column with privilege list
    $rowcount = 2
    foreach ($item in $privilegelist){
        $sheet2.Cells.Item($rowcount,1) = $item
        $rowcount++
    }

    #Identify if Vcenter Server has Privilege and set column to X to indicate it has it
    $c = 1
    $d = $roledata.count
    
    foreach ($item in $roledata){
    write-host "adding item $c of $d" 
    $itemrow = @()
    $itemcolumn = @()
    
    #Find Privilege Item Row
    $itemrow = $sheet2.Cells.find($item.PrivilegeName).row
    
    #Find VCenter Server Column
    $itemcolumn = $sheet2.Cells.find($item.VCenterName).column
    
    # Add Rows to worksheet
    $sheet2.Cells.Item($itemrow,$itemcolumn) = "X"
    
    
    $c++
    }
}

#EndRegion Audit_Review

#Save Excel File
$workbook.SaveAs($outputpath) 
$excel.Quit()

#EndRegion Build Excel Spreadsheet

