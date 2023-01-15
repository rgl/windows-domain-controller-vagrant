#!/bin/bash
set -euxo pipefail

domain="${1:-example.com}"; shift
domain_ip="${1:-192.168.56.2}"; shift
domain_dn="DC=$(echo $domain | sed -E 's/\./,DC=/g')"

# NB the sssd configuration was based on:
#       https://www.youtube.com/watch?v=BvqdU6FZblw
#       https://nerdonthestreet.com/wiki?find=Authenticate+Ubuntu+19.04+against+Active+Directory

# prevent apt-get et al from asking questions.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# make sure we can can resolve the dc dns domain name.
echo "$domain_ip dc.$domain" >>/etc/hosts

# trust the ad ca.
openssl x509 \
    -inform der \
    -in /vagrant/tmp/ExampleEnterpriseRootCA.der \
    -out /usr/local/share/ca-certificates/ExampleEnterpriseRootCA.crt
update-ca-certificates --verbose

# these anwsers were obtained (after installing heimdal-clients) with:
#
#   #sudo debconf-show krb5-config
#   sudo apt-get install debconf-utils
#   # this way you can see the comments:
#   sudo debconf-get-selections
#   # this way you can just see the values needed for debconf-set-selections:
#   sudo debconf-get-selections | grep -E '^krb5-config\s+' | sort
# NB these are not really used as we create the entire krb5.conf bellow.
debconf-set-selections<<EOF
krb5-config krb5-config/default_realm string ${domain^^}
krb5-config krb5-config/kerberos_servers string dc.$domain
krb5-config krb5-config/admin_server string dc.$domain
EOF
apt-get install -y sssd sssd-tools heimdal-clients msktutil

# set configuration.
cat >/etc/krb5.conf <<EOF
[libdefaults]
default_realm = ${domain^^}
rdns = no
dns_lookup_kdc = true
dns_lookup_realm = true

[realms]
${domain^^} = {
    kdc = dc.$domain
    admin_server = dc.$domain
}
EOF

# add this computer to the ad.
kinit --password-file=STDIN administrator <<'EOF'
HeyH0Password
EOF
msktutil \
    --create \
    --keytab /etc/sssd/sssd.keytab \
    --no-reverse-lookups \
    --server dc.$domain \
    --user-creds-only
ldapmodify \
    -H ldap://dc.$domain \
    <<EOF
dn: CN=$(hostname),CN=Computers,$domain_dn
changeType: modify
replace: operatingSystem
operatingSystem: $(bash -c 'source /etc/os-release && echo $NAME')
-
replace: operatingSystemVersion
operatingSystemVersion: $(bash -c 'source /etc/os-release && echo $VERSION')
-
EOF
ldapsearch \
  -H ldap://dc.$domain \
  -b CN=Computers,$domain_dn \
  '(objectClass=computer)'
ktutil --keytab=/etc/sssd/sssd.keytab list
kdestroy

# configure sssd with this computer domain and keytab.
# see sssd(8)
# see sssd.conf(5)
# see sssd-ad(5)
# see sssd-ldap(5)
# see /var/log/sssd/sssd.log
install -o root -g root -m 600 /dev/null /etc/sssd/sssd.conf
cat >/etc/sssd/sssd.conf <<EOF
[sssd]
config_file_version = 2
domains = $domain
#debug_level = 10

[nss]
entry_negative_timeout = 0
#debug_level = 5

[pam]
#debug_level = 5

[domain/$domain]
#debug_level = 10
enumerate = false
id_provider = ad
auth_provider = ad
chpass_provider = ad
access_provider = ad
dyndns_update = false
fallback_homedir = /home/%d/%u
default_shell = /bin/bash
ad_server = dc.$domain
ad_domain = $domain
ldap_schema = ad
ldap_id_mapping = true
ldap_sasl_mech = gssapi
ldap_krb5_init_creds = true
krb5_keytab = /etc/sssd/sssd.keytab
EOF

# validate the configuration.
sssctl config-check

# restart sssd to apply the configuration.
# NB for some unknown reason sssd takes some retries to start.
while true; do
    if systemctl restart sssd; then
        break
    fi
    sleep 10
done
systemctl status sssd

# configure pam to automatically create the home directory.
sed -i -E 's,^(session\s+required\s+pam_unix.so.*),\1\nsession required pam_mkhomedir.so skel=/etc/skel umask=0077,g' /etc/pam.d/common-session

# allow domain administrators to use sudo without asking for password.
cat >/etc/sudoers.d/domain-admins <<'EOF'
# Allow members of the domain admins group to execute
# any command (as root) without asking for password.
%domain\ admins ALL=(ALL) NOPASSWD:ALL
EOF
chmod 0440 /etc/sudoers.d/domain-admins

# show domain users.
id administrator; getent passwd administrator
id john.doe; getent passwd john.doe
id jane.doe; getent passwd jane.doe
