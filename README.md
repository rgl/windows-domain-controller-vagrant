This is an example on how to create a Windows Domain Controller using Vagrant and PowerShell.

This also shows how to add a Computer to an existing domain using PowerShell.

This will create an `example.com` Active Directory Domain Forest.

This will also install a Certification Authority with a GPO to automatically enroll
computers with a certificate signed by the trusted domain CA, Remote Desktop users
will therefore see and use trusted certificates.  

This setup will use the following static IP addresses:

| IP           | Hostname                  | Description                |
|--------------|---------------------------|----------------------------|
| 192.168.56.2 | dc.example.com            | Domain Controller Computer |
| 192.168.56.3 | test-node-one.example.com | Test Computer              |

**NB** these are hardcoded in several files. Find then with `grep -r 192.168.56. .`.

Install the [base box](https://github.com/rgl/windows-2016-vagrant).

Install the required Vagrant plugins:

```bash
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-windows-sysprep
```

Start by launching the Domain Controller environment:

```bash
vagrant up --provider=virtualbox # or --provider=libvirt
```

Launch the Test Node One Computer environment:

```bash
cd test-node-one
vagrant up --provider=virtualbox # or --provider=libvirt
```

Sign-in on the Test Node One Computer with one of the following accounts:

* Username `john.doe` and password `HeyH0Password`.
  * This account is also a Domain Administrator.
* Username `jane.doe` and password `HeyH0Password`.
* Username `Administrator` and password `HeyH0Password`.
  * This account is also a Domain Administrator.
* Username `.\vagrant` and password `password`.
  * **NB** you MUST use the **local** `vagrant` account. because the domain also has a `vagrant` account, and that will mess-up the local one...


# Active Directory LDAP

You can use a normal LDAP client for acessing the Active Directory.

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

For TLS, use `-H ldaps://dc.example.com`, after creating the `ldaprc` file with:

```bash
openssl x509 -inform der -in tmp/ExampleEnterpriseRootCA.der -out tmp/ExampleEnterpriseRootCA.pem
cat >ldaprc <<'EOF'
TLS_CACERT tmp/ExampleEnterpriseRootCA.pem
TLS_REQCERT demand
EOF
```

**NB** For TLS troubleshoot use `echo | openssl s_client -connect dc.example.com:636`.
