# Vault Enterprise HA, DR and Performance Replica Setup
This repo has a vagrant file to create an enterprise Vault Cluster with Consul backend.  This configuration is used to learn DR and Performance Replica options.  This is NOT following the reference architecture for Vault.

There are 3 Vault + Consul clusters created by the Vagrant file.  Each cluster consists of 2 nodes and each node has Vault and Consul servers.

```
Cluster 1: Vault Primary cluster in DC1 

Cluster 2: Vault Secondary DR cluster in DC2 

Cluster 3: Vault Performance Replica cluster in DC3
```

All servers are set without TLS.

## Pre-Requisites
Create a folder named as ```ent``` and copy the Consul and Vault enterprise binary zip files

```e.g., consul-enterprise_1.4.4+prem_linux_amd64.zip```

## Vault Primary Cluster
2 node cluster is created with each node containing Vault and Consul servers. The server details are shown below

```
vault1   10.100.1.11
vault2   10.100.1.12
```

One of the Consul servers would become the leader.  Similarly one of Vault servers would become the Active node and the other node acts as Read Replica.

## Vault Secondary DR Cluster
2 node DR cluster is created with each node containing Vault and Consul servers. The server details are shown below

```
vault-dr1   10.100.2.11
vault-dr2   10.100.2.12
```

## Vault Performance Replica Cluster
2 node Performance Replica cluster is created with each node containing Vault and Consul servers. The server details are shown below

```
vault-pr1   10.100.3.11
vault-pr2   10.100.3.12
```

## Usage
If the ubuntu box is not available then it will take sometime to download the base box for the first time.  After the initial download, servers can be destroyed and recreated quickly with Vagrant

```
$vagrant up

$vagrant status

```

To check the status of the servers ssh into one of the nodes and check the cluster members and identify the leader.

```
$vagrant ssh vault1

vagrant@v1: $consul members

vagrant@v1: $consul operator raft list-peers 

vagrant@v1: $consul info

vagrant@v1: $vault status

```

Vault status would be shown as uninitialised and sealed.

## Initialising and Unsealing Vault

Perform the following to initialise the unseal the Vault clusters.  Initialisation is only required at one of the servers but unsealing needs to happen in all Vault servers.

```
$vagrant ssh vault1

vagrant@v1: $vault status

vagrant@v1: $vault operator init -key-shares=1 -key-threshold=1

vagrant@v1: $vault operator unseal <unseal-key>

vagrant@v1: $vault status

vagrant@v1: $exit

$vagrant ssh vault1

vagrant@v2: $vault operator unseal <unseal-key>

```

## Accessing UI

Use one of the server nodes to access the Consul UI on port 8500 and the Vault UI on port 8200.  The UI for Consul will not work if the leader is not elected.

e.g., Consul UI http://10.100.1.11:8500 

e.g., Vault UI http://10.100.2.11:8500 

## Setup Performance Replication
To do this, the following needs to happen.

In the Primary cluster (from any node either active or standby):

1. Enable the Primary for Replication.  If Primary has a loadbalancer then make sure to set the optional primary_cluster_addr parameter to port 8201.  Make sure that the loadbalancer is configured for Layer 4 to passthrough TCP traffic.  TCP traffic on port 8201 (Primary Cluster Address) should be a passthrough and should not terminate TLS.
Generally, if a loadbalancer is used then both the cluster_addr and api_addr are set to the loadbalancer address in the Vault config file.  Loadbalancer has to be configured to check the /v1/sys/health endpoint to look for the active node and point the traffic to it.

2. Generate the Secondary Activation token

In the Secondary clustere (from any node either active or standby): 

3. Activate the Secondary Token.  If the Primary API address is different to the one in the secondary token then set the primary_api_addr optional field.

The following shows the CLI commands

```
# In the Primary Cluster issue the following
$ vault write -f sys/replication/performance/primary/enable primary_cluster_addr=https://<vault-dns-name>:8201
$ vault write sys/replication/performance/primary/secondary-token id=<some_id> 

# In the Secondary Cluster issue the following
$ vault write sys/replication/performance/secondary/enable token=<long-secondary-token> primary_api_addr=https://<primary-vault-dns-name>:443
```

Once the Performance Replication is enabled, the secondary cluster will be sealed.  This can be unsealed using the Primary cluster's unseal key. Note that the data in the secondary cluster will be lost when it is enabled as a performance replication. 

To log into the Performance Replication cluster, make sure to create a user in the auth method of the Primary cluster so it will get replicated so that this user can be used to loginto the secondary cluster.

To loginto the Performance Replication cluster, let's create a user in userpass auth method and attach the admin policy.  This is done as a test to quickly check things at the secondary cluster.

```
Perform the following in the Primary cluster
$ vault policy write admin admin.hcl
$ vault auth enable userpass
$ vault write auth/userpass/users/test password=test policies=admin

Perform the following in the Secondary cluster
$ vault login -method=userpass username=test
Password (will be hidden):
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.YySpv9BVOHI6417gg5pxrtFh
token_accessor         mjhrFngsru7HmwYq4E0oKhuQ
token_duration         768h
token_renewable        true
token_policies         ["admin" "default"]
identity_policies      []
policies               ["admin" "default"]
token_meta_username    test

Test whether the loggedin user can list the auth methods
$ vault secrets list
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_9c8d5cf5    per-token private secret storage
identity/     identity     identity_d38cc667     identity store
sys/          system       system_da3d3f43       system endpoints used for control, policy and debugging
```
