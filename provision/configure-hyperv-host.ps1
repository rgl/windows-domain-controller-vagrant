param(
    $vmId,
    $bridgesJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

$bridges = ConvertFrom-Json $bridgesJson

$vm = Get-VM -Id $vmId

# reconfigure the network adapters to use the given switch names.
# NB vagrant has already configured ALL network interfaces to use
#    the $env:HYPERV_SWITCH_NAME switch.
# NB the first network adapter is the vagrant management interface
#    which we do not modify.
$networkAdapters = @(Get-VMNetworkAdapter -VM $vm | Select-Object -Skip 1)
$networkAdapters | Select-Object -Skip $bridges.Length | ForEach-Object {
    Write-Host "Removing the VM $vmId from the $($_.SwitchName) switch..."
    $_ | Remove-VMNetworkAdapter
}
for ($n = 0; $n -lt $bridges.Length; ++$n) {
    $bridge = $bridges[$n]
    $switchName = $bridge[0]
    $macAddressSpoofing = $bridge[1]
    if ($n -lt $networkAdapters.Length) {
        Write-Host "Connecting the VM $vmId to the $switchName switch..."
        $networkAdapter = $networkAdapters[$n]
        $networkAdapter | Connect-VMNetworkAdapter -SwitchName $switchName
        $networkAdapter | Set-VMNetworkAdapterVlan -Untagged
    } else {
        Write-Host "Connecting the VM $vmId to the $switchName switch..."
        $networkAdapter = Add-VMNetworkAdapter `
            -VM $vm `
            -Name $switchName `
            -SwitchName $switchName `
            -Passthru
    }
    $networkAdapter | Set-VMNetworkAdapter `
        -MacAddressSpoofing "$(if ($macAddressSpoofing) {'On'} else {'Off'})"
}
Write-Host "VM Network Adapters:"
Get-VMNetworkAdapter -VM $vm
