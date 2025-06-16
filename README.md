# About

This is an example on how to create a Windows Domain Controller using Vagrant and PowerShell.

This also shows how to add a Computer to an existing domain using PowerShell.

This will create an `example.com` Active Directory Domain Forest.

This will also install a Certification Authority with a GPO to automatically enroll
computers with a certificate signed by the trusted domain CA, Remote Desktop users
will therefore see and use trusted certificates.

This will also set the user photo with a GPO.

This will also set the Remote Desktop Users group with a GPO.

This will also setup the `whoami` group Managed Service Account (gMSA).

This setup will use the following static IP addresses:

| IP           | Hostname            | Description                |
|--------------|---------------------|----------------------------|
| 192.168.56.2 | dc.example.com      | Domain Controller Computer |
| 192.168.56.3 | windows.example.com | Test Windows Computer      |
| 192.168.56.4 | ubuntu.example.com  | Test Ubuntu Computer       |

**NB** these are hardcoded in several files. Find then with `grep -r 192.168.56. .`.

# Usage

Install the [Windows 2022 UEFI base box](https://github.com/rgl/windows-vagrant).

Install the [Ubuntu 22.04 UEFI base box](https://github.com/rgl/ubuntu-vagrant).

Install the required Vagrant plugins:

```bash
vagrant plugin install vagrant-windows-sysprep
vagrant plugin install vagrant-reload
```

Start by launching the Domain Controller environment:

```bash
# or --provider=hyperv (first see the Hyper-V Usage section bellow).
vagrant up --provider=libvirt
```

Launch the test nodes:

```bash
cd test-nodes
# or --provider=hyperv
vagrant up --provider=libvirt
```

Sign-in on the test nodes with one of the following accounts:

* Username `john.doe` and password `HeyH0Password`.
  * This account is also a Domain Administrator.
* Username `jane.doe` and password `HeyH0Password`.
* Username `Administrator` and password `HeyH0Password`.
  * This account is also a Domain Administrator.
* Username `.\vagrant` and password `password`.
  * **NB** you MUST use the **local** `vagrant` account. because the domain also has a `vagrant` account, and that will mess-up the local one...

You can login at the machine console.

You can login with remote desktop, e.g.:

```bash
xfreerdp \
  /v:dc.example.com \
  /u:john.doe \
  /p:HeyH0Password \
  /size:1440x900 \
  /dynamic-resolution \
  +clipboard
```

**NB** For an headless RDP example see the [winps repository](https://github.com/rgl/winps).

You can login with ssh, e.g.:

```bash
ssh john.doe@dc.example.com
```

# Active Directory LDAP

You can use a normal LDAP client for accessing the Active Directory.

It accepts the following _Bind DN_ formats:

* `<userPrincipalName>@<DNS domain>`, e.g. `jane.doe@example.com`
* `<sAMAccountName>@<NETBIOS domain>`, e.g. `jane.doe@EXAMPLE`
* `<NETBIOS domain>\<sAMAccountName>`, e.g. `EXAMPLE\jane.doe`
* `<DN for an entry with a userPassword attribute>`, e.g. `CN=jane.doe,CN=Users,DC=example,DC=com`

**NB** `sAMAccountName` MUST HAVE AT MOST 20 characters.

Some attributes are available in environment variables:

| Attribute        | Environment variable | Example             |
|------------------|----------------------|---------------------|
| `sAMAccountName` | `USERNAME`           | `jane.doe`          |
| `sAMAccountName` | `USERPROFILE`        | `C:\Users\jane.doe` |
| `NETBIOS domain` | `USERDOMAIN`         | `EXAMPLE`           |
| `DNS domain`     | `USERDNSDOMAIN`      | `EXAMPLE.COM`       |

You can list all of the active users using [ldapsearch](http://www.openldap.org/software/man.cgi?query=ldapsearch) as:

```bash
ldapsearch \
  -H ldap://dc.example.com \
  -D jane.doe@example.com \
  -w HeyH0Password \
  -x -LLL \
  -b CN=Users,DC=example,DC=com \
  '(&(objectClass=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))' \
  sAMAccountName userPrincipalName userAccountControl displayName cn mail
```

**NB** To have `ldapsearch` you can install the [msys2 mingw-w64-openldap package](https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-openldap) with `pacman -Sy mingw-w64-x86_64-openldap`.

For TLS, use `-H ldaps://dc.example.com`, after creating the `ldaprc` file with:

```bash
openssl x509 -inform der -in tmp/ExampleEnterpriseRootCA.der -out tmp/ExampleEnterpriseRootCA.pem
cat >ldaprc <<'EOF'
TLS_CACERT tmp/ExampleEnterpriseRootCA.pem
TLS_REQCERT demand
EOF
```

Troubleshoot TLS with:

```bash
# see the TLS certificate validation result:
echo | openssl s_client -connect dc.example.com:636 -servername dc.example.com -CAfile tmp/ExampleEnterpriseRootCA.pem
# see the TLS certificate being returned by the server:
echo | openssl s_client -connect dc.example.com:636 -servername dc.example.com | openssl x509 -noout -text -in -
```

# Active Directory DNS

You can update the DNS zone using the computer principal credentials, e.g.:

```bash
kinit --keytab=/etc/sssd/sssd.keytab 'ubuntu$'
nsupdate -g <<'EOF'
server dc.example.com
zone example.com.
update delete ubuntu.example.com. in A
update add ubuntu.example.com. 60 in A 192.168.56.4
update delete ubuntu.example.com. in TXT
update add ubuntu.example.com. 60 in TXT "hello world"
send
EOF
kdestroy
```

# Hyper-V Usage

Follow the [rgl/windows-vagrant Hyper-V Usage section](https://github.com/rgl/windows-vagrant#hyper-v-usage).

Create the required virtual switches:

```bash
PowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass <<'EOF'
@(
  @{Name='windows-domain-controller'; IpAddress='192.168.56.1'}
) | ForEach-Object {
  $switchName = $_.Name
  $switchIpAddress = $_.IpAddress
  $networkAdapterName = "vEthernet ($switchName)"
  $networkAdapterIpAddress = $switchIpAddress
  $networkAdapterIpPrefixLength = 24

  # create the vSwitch.
  Hyper-V\New-VMSwitch -Name $switchName -SwitchType Internal | Out-Null

  # assign it an host IP address.
  $networkAdapter = Get-NetAdapter $networkAdapterName
  $networkAdapter | New-NetIPAddress `
    -IPAddress $networkAdapterIpAddress `
    -PrefixLength $networkAdapterIpPrefixLength `
    | Out-Null
}

# remove all virtual switches from the windows firewall.
Set-NetFirewallProfile `
  -DisabledInterfaceAliases (
        Get-NetAdapter -name "vEthernet*" | Where-Object {$_.ifIndex}
    ).InterfaceAlias
EOF
```
