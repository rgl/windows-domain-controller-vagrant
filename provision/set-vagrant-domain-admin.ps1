# Sets vagrant as a domain administrator. Necessary to allow vagrant to add a
# KDS key.
Add-ADGroupMember -Identity "Domain Admins" -Members "vagrant"