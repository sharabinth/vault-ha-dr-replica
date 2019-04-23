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


