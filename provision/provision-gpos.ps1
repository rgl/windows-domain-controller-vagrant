$adDomain = Get-ADDomain
$domainDn = $adDomain.DistinguishedName

# install dependencies.
# see https://github.com/FriedrichWeinmann/GPOTools
# see https://www.powershellgallery.com/packages/GPOTools
Get-PackageProvider -Name NuGet -Force | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name GPOTools -Force
Import-Module GPOTools

# install the GPOs.
# NB these were manually created with the "Group Policy Management" GUI and
#    then exported as, e.g.:
#       cd c:\vagrant\provision\gpo
#       mkdir set-user-photo
#       cd set-user-photo
#       rm -Recurse -Force *
#       Get-GPO 'Set User Photo' | Backup-GptPolicy -Path $PWD
Get-ChildItem -Recurse -Force -Include manifest.xml gpo | ForEach-Object {
    $path = $_.Directory.Parent.FullName
    [xml]$manifest = Get-Content $_
    $manifest.Backups.BackupInst | ForEach-Object {
        $name = $_.GPODisplayName.InnerText
        Write-Host "Importing the $name GPO from $path..."
        Restore-GptPolicy -Name $name -Path $path 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                # see https://github.com/FriedrichWeinmann/GPOTools/issues/5#issuecomment-781598022
                if ("$_" -eq "Cannot bind argument to parameter 'DistinguishedName' because it is an empty string.") {
                    "IGNORED ERROR: $_"
                } else {
                    "$_"
                }
            } else {
                "$_"
            }
        }
        Write-Host "Linking the $name GPO to $domainDn..."
        $gpo = Get-GPO -Name $name
        if ((Get-GPInheritance -Target $domainDn).GpoLinks.GpoId -notcontains $gpo.Id) {
            $gpo | New-GPLink `
                -Target $domainDn `
                -LinkEnabled Yes `
                | Out-Null
        }
    }
}
