param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$addresses
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

# bail when not running over hyperv.
$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -ne 'Microsoft Corporation') {
    Exit 0
}

# NB the first network adapter is the vagrant management interface
#    which we do not modify.
# NB this is somewhat brittle: InterfaceIndex sometimes does not enumerate
#    the same way, so we use MacAddress instead, as it seems to work more
#    reliably; but this is not ideal either.
# TODO somehow use the MAC address to set the IP addresses.
$adapters = @(Get-NetAdapter -Physical | Sort-Object MacAddress | Select-Object -Skip 1)

for ($n = 0; $n -lt $adapters.Length; ++$n) {
    $adapter = $adapters[$n]
    $address = $addresses[$n]
    $adapterAddresses = @($adapter | Get-NetIPAddress -ErrorAction SilentlyContinue)
    if ($adapterAddresses -and ($adapterAddresses.IPAddress -eq $address)) {
        continue
    }        
    Write-Output "Setting the $($adapter.Name) ($($adapter.MacAddress)) adapter IP address to $address..."
    $adapter | New-NetIPAddress `
        -IPAddress $address `
        -PrefixLength 24 `
        | Out-Null
    $adapter | Set-NetConnectionProfile `
        -NetworkCategory Private `
        | Out-Null
}