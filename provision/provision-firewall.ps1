# Allow Remote Desktop (RDP).
Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Direction Inbound -Enable True
