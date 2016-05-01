$ErrorActionPreference = 'Stop'


# disable IPv6 on all network interfaces.
Get-NetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6
