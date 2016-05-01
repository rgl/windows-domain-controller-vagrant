#!/bin/bash
set -eux
vagrant up --no-provision
vagrant powershell -c 'cp C:/vagrant/provision/Autounattend_sysprep.xml C:/Windows/Temp/'
vagrant powershell -c 'cd C:/Windows/System32/Sysprep; ./sysprep /generalize /oobe /quiet /shutdown /unattend:C:/Windows/Temp/Autounattend_sysprep.xml'
# wait for sysprep to shutdown the machine.
bash -c 'set -eu; while [ -z "$(vagrant status | grep poweroff)" ]; do sleep 3; done'
vagrant up
