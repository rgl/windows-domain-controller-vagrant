$adDomain = Get-ADDomain
$domainDn = $adDomain.DistinguishedName
$domain = $adDomain.NetBiosName

# install dependencies.
# see https://github.com/FriedrichWeinmann/GPOTools
# see https://www.powershellgallery.com/packages/GPOTools
Get-PackageProvider -Name NuGet -Force | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name GPOTools -Force
Import-Module GPOTools

# copy the GPOs to the guest because some of them might need to be modified.
if (Test-Path c:\tmp\gpo) {
    Remove-Item -Recurse -Force c:\tmp\gpo
}
Copy-Item -Recurse gpo c:\tmp

# install the GPOs.
# NB these were manually created with the "Group Policy Management" GUI and
#    then exported as, e.g.:
#       cd c:\vagrant\provision\gpo
#       mkdir set-user-photo
#       cd set-user-photo
#       rm -Recurse -Force *
#       Get-GPO 'Set User Photo' | Backup-GptPolicy -Path $PWD
Get-ChildItem -Recurse -Force -Include manifest.xml c:\tmp\gpo | ForEach-Object {
    $path = $_.Directory.Parent.FullName

    # patch the groups member references from the EXAMPLE domain to the current domain.
    # see https://github.com/FriedrichWeinmann/GPOTools/issues/5
    $groupsPath = Resolve-Path -ErrorAction SilentlyContinue "$path\GPO\*\DomainSysvol\GPO\Machine\Preferences\Groups\Groups.xml"
    if ($groupsPath) {
        [xml]$groups = Get-Content $groupsPath
        $groups.Groups.Group.Properties.Members.Member | ForEach-Object {
            # patch the name and sid properties of the Member element, e.g. from:
            #   <Member name="EXAMPLE\Domain Users" action="ADD" sid="S-1-5-21-3170668003-4050164859-1735224712-513"/>
            $principalAccountName = "$domain\$($_.name -replace 'EXAMPLE\\','')"
            Write-Host "Patching Group Member reference from $($_.name) to $principalAccountName..."
            $principalAccount = New-Object System.Security.Principal.NTAccount($principalAccountName)
            $principalAccountSid = $principalAccount.Translate([System.Security.Principal.SecurityIdentifier])
            $_.name = "$principalAccount"
            $_.sid = "$principalAccountSid"
        }
        Set-Content -Encoding UTF8 -Path $groupsPath -Value $groups.OuterXml
    }

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
