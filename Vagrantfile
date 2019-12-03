# -*- mode: ruby -*-
# vi: set ft=ruby :

### Define environment variables to pass on to provisioner

# Define Vault Primary HA server details
VAULT_HA_SERVER_IP_PREFIX = ENV['VAULT_HA_SERVER_IP_PREFIX'] || "10.100.1.1"
VAULT_HA_SERVER_IPS = ENV['VAULT_HA_SERVER_IPS'] || '"10.100.1.11", "10.100.1.12"'

# Define Vault Secondary DR server details
VAULT_DR_SERVER_IP_PREFIX = ENV['VAULT_DR_SERVER_IP_PREFIX'] || "10.100.2.1"
VAULT_DR_SERVER_IPS = ENV['VAULT_DR_SERVER_IPS'] || '"10.100.2.11", "10.100.2.12"'

# Define Vault Secondary Performance Replica server details
VAULT_REPLICA_SERVER_IP_PREFIX = ENV['VAULT_REPLICA_SERVER_IP_PREFIX'] || "10.100.3.1"
VAULT_REPLICA_SERVER_IPS = ENV['VAULT_REPLICA_SERVER_IPS'] || '"10.100.3.11", "10.100.3.12"'


Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  #config.vm.box_version = "20190411.0.0"

  # set up the 2 node Vault Primary HA servers
  (1..2).each do |i|
    config.vm.define "vault#{i}" do |v1|
      v1.vm.hostname = "v#{i}"
      
      v1.vm.network "private_network", ip: VAULT_HA_SERVER_IP_PREFIX+"#{i}"
      v1.vm.provision "shell", 
              path: "scripts/setupConsulServer.sh",
              env: {'VAULT_HA_SERVER_IPS' => VAULT_HA_SERVER_IPS, 'VAULT_DC' => 'dc1'}

      v1.vm.provision "shell", path: "scripts/setupVaultServer.sh"
    end
  end

  # set up the 2 node Vault Secondary DR servers
  (1..2).each do |i|
    config.vm.define "vault-dr#{i}" do |v1|
      v1.vm.hostname = "v-dr#{i}"
      
      v1.vm.network "private_network", ip: VAULT_DR_SERVER_IP_PREFIX+"#{i}"
      v1.vm.provision "shell", 
              path: "scripts/setupConsulServer.sh",
              env: {'VAULT_HA_SERVER_IPS' => VAULT_DR_SERVER_IPS, 'VAULT_DC' => 'dc2'}

      v1.vm.provision "shell", path: "scripts/setupVaultServer.sh"
    end
  end

  # set up the 2 node Vault Secondary Replication servers
  (1..2).each do |i|
    config.vm.define "vault-pr#{i}" do |v1|
      v1.vm.hostname = "v-pr#{i}"
      
      v1.vm.network "private_network", ip: VAULT_REPLICA_SERVER_IP_PREFIX+"#{i}"
      v1.vm.provision "shell", 
              path: "scripts/setupConsulServer.sh",
              env: {'VAULT_HA_SERVER_IPS' => VAULT_REPLICA_SERVER_IPS, 'VAULT_DC' => 'dc3'}

      v1.vm.provision "shell", path: "scripts/setupVaultServer.sh"
    end
  end

end
