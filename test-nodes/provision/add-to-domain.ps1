param(
    $domain = 'example.com',
    $domainControllerIp = '192.168.56.2'
)

$ErrorActionPreference = 'Stop'


$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor


$adapters = @(Get-NetAdapter -Physical)
if ($systemVendor -eq 'Microsoft Corporation') {
    $adapters = $adapters | Sort-Object MacAddress
}
$vagrantManagementAdapter = $adapters[0]
$domainControllerAdapter = $adapters[1]


# do not dynamically register the vagrant management interface address in the domain dns server.
$vagrantManagementAdapter | Set-DNSClient -RegisterThisConnectionsAddress $false


# make sure the dns requests on this interface fail fast.
# NB we need to do this because there is no way to remove the DNS server from
#    a DHCP interface.
# NB this will basically force dns requests to fail with icmp destination port
#    unreachable (instead of timing out and delaying everything), which in turn
#    will force windows to query other dns servers (our domain dns server that
#    is set on the domain adapter).
# NB we cannot set this to the domain controller dns server because windows will
#    always use this interface to connect the dns server, but since its only
#    reachable through the domain adapter, the dns responses will never arrive
#    and dns client will eventually timeout and give up, and that breaks WDS
#    because dns takes too long to reply.
$vagrantManagementAdapter | Set-DnsClientServerAddress -ServerAddresses 127.127.127.127

# use the DNS server from the Domain Controller machine.
# this way we can correctly resolve DNS entries that are only defined on the Domain Controller.
$domainControllerAdapter | Set-DnsClientServerAddress -ServerAddresses $domainControllerIp


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
