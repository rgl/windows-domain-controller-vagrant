param(
    $domain = 'example.com',
    $domainControllerIp = '192.168.56.2'
)

$ErrorActionPreference = 'Stop'


# use the DNS server from the Domain Controller machine.
# this way we can correctly resolve DNS entries that are only defined on the Domain Controller.
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $domainControllerIp


# add the machine to the domain.
# NB if you get the following error message, its because you MUST first run sysprep.
#       Add-Computer : Computer 'test-node-one' failed to join domain 'example.com' from its current workgroup 'WORKGROUP'
#       with following error message: The domain join cannot be completed because the SID of the domain you attempted to join
#       was identical to the SID of this machine. This is a symptom of an improperly cloned operating system install.  You
#       should run sysprep on this machine in order to generate a new machine SID. Please see
#       http://go.microsoft.com/fwlink/?LinkId=168895 for more information.
Add-Computer `
    -DomainName $domain `
    -Credential (New-Object `
                    System.Management.Automation.PSCredential(
                        "vagrant@$domain",
                        (ConvertTo-SecureString "vagrant" -AsPlainText -Force)))
