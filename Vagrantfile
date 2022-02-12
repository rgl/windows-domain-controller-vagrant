# to be able to configure hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

$domain = "example.com"
$domain_ip_address = "192.168.56.2"

Vagrant.configure("2") do |config|
    config.vm.box = "windows-2022-amd64"
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

    config.vm.provider :hyperv do |hv, config|
        hv.linked_clone = true
        hv.enable_virtualization_extensions = false # nested virtualization.
        hv.cpus = 2
        hv.memory = 2048
        hv.vlan_id = ENV['HYPERV_VLAN_ID']
        # set the management network adapter.
        # see https://github.com/hashicorp/vagrant/issues/7915
        # see https://github.com/hashicorp/vagrant/blob/10faa599e7c10541f8b7acf2f8a23727d4d44b6e/plugins/providers/hyperv/action/configure.rb#L21-L35
        config.vm.network :private_network,
            bridge: ENV['HYPERV_SWITCH_NAME'] if ENV['HYPERV_SWITCH_NAME']
        config.vm.synced_folder '.', '/vagrant',
            type: 'smb',
            smb_username: ENV['VAGRANT_SMB_USERNAME'] || ENV['USER'],
            smb_password: ENV['VAGRANT_SMB_PASSWORD']
        # further configure the VM (e.g. manage the network adapters).
        config.trigger.before :'VagrantPlugins::HyperV::Action::StartInstance', type: :action do |trigger|
            trigger.ruby do |env, machine|
                # see https://github.com/hashicorp/vagrant/blob/v2.2.10/lib/vagrant/machine.rb#L13
                # see https://github.com/hashicorp/vagrant/blob/v2.2.10/plugins/kernel_v2/config/vm.rb#L716
                bridges = machine.config.vm.networks.select{|type, options| type == :private_network && options.key?(:hyperv__bridge)}.map do |type, options|
                    mac_address_spoofing = false
                    mac_address_spoofing = options[:hyperv__mac_address_spoofing] if options.key?(:hyperv__mac_address_spoofing)
                    [options[:hyperv__bridge], mac_address_spoofing]
                end
                system(
                    'PowerShell',
                    '-NoLogo',
                    '-NoProfile',
                    '-ExecutionPolicy',
                    'Bypass',
                    '-File',
                    'provision/configure-hyperv-host.ps1',
                    machine.id,
                    bridges.to_json
                )
                raise "failed to configure hyper-v with exit code #{$?.exitstatus}" if $?.exitstatus != 0
            end
        end
    end

    config.vm.network "private_network",
        ip: $domain_ip_address,
        libvirt__forward_mode: "route",
        libvirt__dhcp_enabled: false,
        hyperv__bridge: "windows-domain-controller"

    config.vm.provision "shell", path: "provision/ps.ps1", args: ["configure-hyperv-guest.ps1", $domain_ip_address]
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["domain-controller.ps1", $domain]
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-wait-for-ready.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "set-vagrant-domain-admin.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-configure.ps1"
    config.vm.provision "shell", inline: "$env:chocolateyVersion='0.12.1'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-base.ps1"
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "domain-controller-wait-for-ready.ps1"
    # TODO after https://github.com/FriedrichWeinmann/GPOTools/issues/5#issuecomment-781598022 is fixed use ps.ps1 to call provision-gpos.ps1.
    config.vm.provision "shell", inline: "cd c:/vagrant/provision; ./provision-gpos.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "ad-explorer.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "ca.ps1"
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-winrm-https-listener.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-msys2.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-firewall.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "summary.ps1"
end
