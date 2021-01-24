echo 'Installing the PowerShell ActiveDirectory module...'
Install-WindowsFeature RSAT-AD-PowerShell

echo 'This computer is member of the following AD groups:'
Get-ADComputer $env:COMPUTERNAME `
    | Get-ADPrincipalGroupMembership `
    | Select-Object name,distinguishedName,sid `
    | Format-Table -AutoSize | Out-String -Width 2000
