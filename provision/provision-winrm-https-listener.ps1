$adDomain = Get-ADDomain
$domain = $adDomain.DNSRoot
$fqdn = "$env:COMPUTERNAME.$domain".ToLowerInvariant()
$certificate = Get-ChildItem -Path Cert:\LocalMachine\My -DnsName $fqdn
$certificateThumbprint = $certificate.Thumbprint

# Add the WinRM HTTPS listener.
# NB this can be used from a client machine as, e.g.:
#       $session = New-PSSession `
#           -UseSSL `
#           -SessionOption (New-PSSessionOption -SkipRevocationCheck) `
#           -ComputerName "dc.$domain" `
#           -Credential $domainAdminstratorCredential
#       Invoke-Command -Session $session -ScriptBlock {
#           $domain = Get-ADDomain
#           $domainDn = $domain.DistinguishedName
#           Write-Output "Hello from $domainDn!"
#       }
#       Remove-PSSession $session
# NB we must use -SkipRevocationCheck because the DC certificate has a CRL
#    Distribution Point URL of ldap: that does not seem to work. maybe we
#    should configure the DC CA to include an http: URL too? feel free to
#    contribute it :-)
#    NB without this, it errors with:
#           The SSL certificate could not be checked for revocation
Write-Output 'Creating the WinRM HTTPS listener...'
New-Item `
    -Path WSMan:\localhost\Listener `
    -Transport HTTPS `
    -Address * `
    -Port 5986 `
    -Hostname $fqdn `
    -CertificateThumbprint $certificateThumbprint `
    -Force `
    | Out-Null

Write-Output 'Current WinRM listeners:'
winrm enumerate winrm/config/listener

Write-Output 'Current WinRM configuration:'
winrm get winrm/config

Write-Output 'Current WinRM ID:'
winrm id

# make sure winrm can be accessed from any network location.
New-NetFirewallRule `
    -DisplayName WINRM-HTTPS-In-TCP-VAGRANT `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 5986 `
    | Out-Null
