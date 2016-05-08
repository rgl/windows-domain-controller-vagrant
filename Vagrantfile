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
        v.customize ["storageattach", :id,
                        "--storagectl", "IDE Controller",
                        "--device", "0",
                        "--port", "1",
                        "--type", "dvddrive",
                        "--medium", "emptydrive"]
    end

    config.vm.network "private_network", ip: "192.168.56.2"

    config.vm.provision "shell", path: "provision/locale.ps1"
    config.vm.provision :reload
    config.vm.provision "shell", path: "provision/domain-controller.ps1"
    config.vm.provision :reload
    config.vm.provision "shell", path: "provision/domain-controller-configure.ps1"
    config.vm.provision "shell", path: "provision/ad-explorer.ps1"
    config.vm.provision "shell", path: "provision/ca.ps1"
    config.vm.provision :reload
    config.vm.provision "shell", path: "provision/summary.ps1"
end
