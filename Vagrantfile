# -*- mode: ruby -*-
# vi: set ft=ruby :

# this Vagranfile needs vagrant-reload, you have to install it with:
#
#   vagrant plugin install vagrant-reload

Vagrant.require_version ">= 1.8.1"

Vagrant.configure("2") do |config|
    config.vm.box = "windows_2012_r2"
    config.vm.define "windows-domain-controller"
    config.vm.hostname = "dc"

    config.vm.provider :virtualbox do |v, override|
        v.linked_clone = true
        v.cpus = 2
        v.memory = 2048
        v.customize ["modifyvm", :id, "--vram", 64]
        v.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    end

    config.vm.network "private_network", ip: "192.168.56.2"

    config.vm.provision "shell", path: "provision/locale.ps1"
    config.vm.provision :reload
    config.vm.provision "shell", path: "provision/domain-controller.ps1"
    config.vm.provision :reload
    # we need to wait a bit for the DC to be ready.
    # 3 minutes should be enough.
    # TODO find a way to known when the DC is ready. Maybe by trying to connect to the AD?
    config.vm.provision "shell", inline: "Sleep -Seconds (3*60)", name: "Sleeping until the DC is ready"
    config.vm.provision "shell", path: "provision/configure-domain-controller.ps1"
    config.vm.provision "shell", path: "provision/summary.ps1"
end
