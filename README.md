
This is an example on how to create a Windows Domain Controller using Vagrant and PowerShell.

This also shows how to add a Computer to an existing domain using PowerShell.

This will create an `example.com` Active Directory Domain Forest.

This setup will use the following static IP addresses:

    IP            Hostname                   Description
    192.168.56.2  dc.example.com             Domain Controller Computer
    192.168.56.3  test-node-one.example.com  Test Computer

**NB** these are hardcoded in several files. Find then with `grep -r 192.168.56. .`.


Start by launching the Domain Controller environment:

    vagrant up

Launch the Test Node One Computer environment:

    cd test-node-one
    ./sysprep.sh

**NB** a computer can only join an Active Directory Domain if it has an unique SID.
**NB** we only need to run `sysprep` because the base image didn't did it.

Sign-in on the Test Node One Computer with one of the following accounts:

* Username `john.doe` and password `HeyH0Password`.
  * This account is also a Domain Administrator.
* Username `jane.doe` and password `HeyH0Password`.
* Username `Administrator` and password `HeyH0Password`.
  * This account is also a Domain Administrator.
* Username `.\vagrant` and password `password`.
  * **NB** you MUST use the **local** `vagrant` account. because the domain also has a `vagrant` account, and that will mess-up the local one...
