# install the AD services and administration tools.
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

$caCommonName = 'Example Enterprise Root CA'

# configure the CA DN using the default DN suffix (which is based on the
# current Windows Domain, example.com) to:
#
#   CN=Example Enterprise Root CA,DC=example,DC=com
#
# NB to install a EnterpriseRootCa the current user must be on the
#    Enterprise Admins group. 
Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCa `
    -CACommonName $caCommonName `
    -HashAlgorithmName SHA256 `
    -KeyLength 4096 `
    -ValidityPeriodUnits 8 `
    -ValidityPeriod Years `
    -Force

# export the CA certificate to the Vagrant project directory, so it can be used by other machines.
mkdir -Force C:\vagrant\tmp | Out-Null
dir Cert:\LocalMachine\My -DnsName $caCommonName `
    | Export-Certificate -FilePath "C:\vagrant\tmp\$($caCommonName -replace ' ','').der" `
    | Out-Null

# add the `RDPAuth` certificate template to the AD.
#
# this was manually created using the instructions available at:
#
#   http://www.darkoperator.com/blog/2015/3/26/rdp-tls-certificate-deployment-using-gpo
#
# and exported with:
#
#   $domainDn = (Get-ADDomain).DistinguishedName
#   $certificateTemplatesDn = "CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$domainDn"
#   ldifde -f c:/vagrant/rdpauth-certificate-template.ldif -d "CN=RDPAuth,$certificateTemplatesDn"
(Get-Content c:/vagrant/provision/rdpauth-certificate-template.ldif) `
    -replace 'when(Created|Changed):.+','' `
    -replace 'uSN(Created|Changed):.+','' `
    -replace 'objectGUID:.+','' `
    -notmatch '^$' `
    | Set-Content c:/tmp/rdpauth-certificate-template.ldif
# get the ACL from the existing Machine Certificate Template.
$domainDn = (Get-ADDomain).DistinguishedName
$certificateTemplatesDn = "CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$domainDn"
ldifde -f c:/tmp/machine-certificate-template-sd.ldif -d "CN=Machine,$certificateTemplatesDn" -l nTSecurityDescriptor
Get-Content c:/tmp/machine-certificate-template-sd.ldif `
    | Select -Skip 2 `
    | Add-Content c:/tmp/rdpauth-certificate-template.ldif
ldifde -f c:/tmp/rdpauth-certificate-template.ldif -i


# add the template to the CA.
#
# NB the just added template is not immediately available. it will
#    only be available when something decides to poll the AD.
#    e.g. it works immediatelly when you open the Certification
#    Authority UI and select the `Certificate Templates node`... but
#    I don't known how to do that here...
# NB the polling interval seem to be 10 minutes (600 seconds).
# NB restarting the Active Directory Certificate Services does not
#    seem do the trick.
# NB restarting Windows does not do the trick either.
echo 'Adding the Certificate Template to the CA'
while ($true) {
    try {
        Add-CATemplate -Name 'RDPAuth' -Force
        break
    } catch {
        #echo "The CA has not yet refreshed the Available Certificate Templates: $($_.Exception)" 
        Sleep 10
    }
}


# save the GPO before we do any changes.
Get-GPOReport -All -ReportType Xml -Path c:/tmp/gpo-initial.xml


# configure the GPO as described at:
#
#   http://www.darkoperator.com/blog/2015/3/26/rdp-tls-certificate-deployment-using-gpo
$gpoName = 'Default Domain Policy'

# Computer Configuration
#  Policies
#   Administrative Template
#    Windows Components
#     Remote Desktop Services
#      Remote Desktop Session Host
#       Security
#         Server authentication certificate template
Set-GPRegistryValue `
    -Name $gpoName `
    -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
    -ValueName 'CertTemplateName' `
    -Type 'String' `
    -Value 'RDPAuth' `
    | Out-Null

# Computer Configuration
#  Policies
#   Administrative Template
#    Windows Components
#     Remote Desktop Services
#      Remote Desktop Session Host
#       Security
#         Require use of specific security layer for remote (RDP) connections
Set-GPRegistryValue `
    -Name $gpoName `
    -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
    -ValueName 'SecurityLayer' `
    -Type 'DWORD' `
    -Value 2 `
    | Out-Null

# Computer Configuration
#  Policies
#   Administrative Template
#    Windows Components
#     Remote Desktop Services
#      Remote Desktop Connection Client
#        Configure server authentication for client
Set-GPRegistryValue `
    -Name $gpoName `
    -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
    -ValueName 'AuthenticationLevel' `
    -Type 'DWORD' `
    -Value 2 `
    | Out-Null

# Computer Configuration
#  Policies
#   Administrative Template
#    Windows Components
#     Remote Desktop Services
#      Remote Desktop Session Host
#       Connections
#         Allow users to connect remotely by using Remote Desktop Services
Set-GPRegistryValue `
    -Name $gpoName `
    -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
    -ValueName 'fDenyTSConnections' `
    -Type 'DWORD' `
    -Value 0 `
    | Out-Null


# save the GPO after we have changed it.
Get-GPOReport -All -ReportType Xml -Path c:/tmp/gpo-final.xml
