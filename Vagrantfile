$domain = "example.com"
$domain_ip_address = "192.168.56.2"

Vagrant.configure("2") do |config|
    config.vm.box = "windows-2019-amd64"
    config.vm.define "windows-domain-controller"
    config.vm.hostname = "dc"

    # use the plaintext WinRM transport and force it to use basic authentication.
    # NB this is needed because the default negotiate transport stops working
    #    after the domain controller is installed.
    #    see https://groups.google.com/forum/#!topic/vagrant-up/sZantuCM0q4
    config.winrm.transport = :plaintext
    config.winrm.basic_auth_only = true

    config.vm.provider :libvirt do |lv, config|
        lv.memory = 2048
        lv.cpus = 2
        lv.cpu_mode = 'host-passthrough'
        lv.keymap = 'pt'
        # replace the default synced_folder with something that works in the base box.
        # NB for some reason, this does not work when placed in the base box Vagrantfile.
        config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end

    config.vm.provider :virtualbox do |v, override|
        v.linked_clone = true
        v.cpus = 2
        v.memory = 2048
        v.customize ["modifyvm", :id, "--clipboard-mode", "bidirectional"]
        v.customize ["storageattach", :id,
                        "--storagectl", "SATA Controller",
                        "--device", "0",
                        "--port", "1",
                        "--type", "dvddrive",
                        "--medium", "emptydrive"]
    end

    config.vm.network "private_network", ip: $domain_ip_address, libvirt__forward_mode: "route", libvirt__dhcp_enabled: false

    config.vm.provision "shell", path: "provision/ps.ps1", args: ["domain-controller.ps1", $domain]
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-configure.ps1"
    config.vm.provision "shell", inline: "$env:chocolateyVersion='0.10.15'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-base.ps1"
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "ad-explorer.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "ca.ps1"
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-msys2.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-firewall.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "summary.ps1"
end
