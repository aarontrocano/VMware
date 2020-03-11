<#

#>
$objreport1 = @()
$objreport2 = @()
$Server = 'vcsa01'
$port = '443'
$import = get-content ([Environment]::GetFolderPath("Desktop") + '\exampleservs' + '.txt')
$errorlog = ([Environment]::GetFolderPath("Desktop") + '\info' + '\vmwareerror ' + (get-date -format MM-dd-yyyy) + '.txt')
$esxireport = ([Environment]::GetFolderPath("Desktop") + '\info' + '\ExampleVmwareReport ' + (get-date -format MM-dd-yyyy) + '.txt')
$otherreport = ([Environment]::GetFolderPath("Desktop") + '\info' + '\otherreport ' + (get-date -format MM-dd-yyyy) + '.txt')
Import-Module -name 'Vmware.PowerCLI'
Connect-VIServer -Server $server -Port $port -Credential $Credential
$ADqueryobj = Get-ADComputer -filter { Operatingsystem -like '*Windows Server*' } -properties * | select-object name
[array]$ADDNSNames = $adqueryobj.name
[array]$vmquery = get-vm | select-object name
foreach ($name in $ADDNSNames) {
    if ($name -in $vmquery.name -and $name -in $import) {
        Write-warning "$name was found in ESXi!" -Verbose
        try {
            [bool]$check1 = $true
            $matchinvmware = get-vm -name $name | 
            select-object name, powerstate, Notes, Guest, NumCPU, corespersocket, memorygb, vmhost, version, hardwareversion, resourcepool -ErrorAction Stop 
            $matchinad = Get-ADComputer -identity $name -properties name, canonicalname, ipv4address, description, enabled, Operatingsystem | 
            select-object name, canonicalname, ipv4address, description, enabled, Operatingsystem -ErrorAction Stop 
        }     
        catch {
            [bool]$check1 = $false                                   
            Write-Warning ($name + ':' + ' ' + $_.Exception.message)
            Add-Content -Path $errorlog -Value ($name + ':' + ' ' + $_.Exception.message)                
        }                                       
        if ($check1) {
            $objcol = [ordered]@{ }
            $objcol.IsVmware = ('YES')
            $objcol.ComputerName = $matchinvmware.name
            $objcol.Powerstate = $matchinvmware.powerstate
            $objcol.VmwareDescription = $matchinvmware.Notes 
            $objcol.ADDescription = $matchinad.description 
            $objcol.OS = $matchinad.Operatingsystem
            $objcol.NumberofCPUs = $matchinvmware.NumCPU
            $objcol.CPUCoresperSocket = $matchinvmware.corespersocket
            $objcol.MemoryinGB = $matchinvmware.memorygb
            $objcol.VmwareVersion = $matchinvmware.version
            $objcol.VmwareHardwareVersion = $matchinvmware.hardwareversion
            $objcol.VmwareResourcePool = $matchinvmware.resourcepool
            $objcol.VnwareHost = $matchinvmware.vmhost
            $objhash = New-Object PSObject -Property $objcol
            $objreport1 += $objhash   
        } 
    }    
    else { 
        Write-Verbose "$name did not meet the criteria!" -Verbose  
        try {
            [bool]$check2 = $true
            $matchinad = Get-ADComputer -identity $name -properties name, canonicalname, ipv4address, description, enabled, Operatingsystem | 
            select-object name, canonicalname, ipv4address, description, enabled, Operatingsystem -ErrorAction Stop
        }
        catch {
            [bool]$check2 = $false
            Write-Verbose "Failed to get AD details for $name in Check2!" -Verbose 
            Add-Content -Path $errorlog -Value ("Failed to get AD details for $name in Check2!")
        }   
        if ($check2) {    
            $objcol = [ordered]@{ }
            $objcol.IsVmware = ('NO')
            $objcol.ComputerName = $matchinad.name
            $objcol.Canonicalname = $matchinad.canonicalname
            $objcol.ipv4address. $matchinad.ipv4address
            $objcol.ADDescription = $matchinad.description 
            $objcol.Operatingsystem = $matchinad.Operatingsystem
            $objcol.Enabled = $matchinad.Enabled    
            $objhash = New-Object PSObject -Property $objcol
            $objreport2 += $objhash 
        }  
    }
}
$objreport1 | Select-Object * | Out-File $esxireport
$objreport2 | Select-Object * | Out-file $otherreport
