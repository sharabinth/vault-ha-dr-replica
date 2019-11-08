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

e.g., Vault UI http://10.100.2.11:8200 


# SETUP and TEST DR and PERFORMANCE REPLICATIONS

## 1. Setup Vault to Test Disaster Recovery and Performance Replication
Prior to setting up DR and PR setups, configure Vault with the following.

1. Setup some static secrets at multiple paths
2. Create an admin policy
3. Create a user for userpass authentication and attach the admin policy

```
vault secrets enable -path=secret-one -version=2 kv
vault secrets enable -path=secret-two -version=2 kv
vault secrets enable -path=secret-three -version=2 kv
vault secrets enable -path=secret-four -version=2 kv

vault kv put secret-one/one ver=5.1 app=test
vault kv put secret-two/two ver=5.2 app=middleware
vault kv put secret-three/three ver=5.3 app=data
vault kv put secret-four/four ver=5.4 app=k8s

vault policy write admin /vagrant/admin.hcl

vault auth enable userpass
vault write auth/userpass/users/test password=test policies=admin

```


## 2. Setup Disaster Recovery Replication

Step 1. Enable DR Replication on the Primary Cluster (10.100.1.11)
```
vault write -f sys/replication/dr/primary/enable

WARNING! The following warnings were returned from Vault:

  * This cluster is being enabled as a primary for replication. Vault will be
  unavailable for a brief period and will resume service shortly.

```

Step 2. Generate the Secondary Token on the Primary Cluster (10.100.1.11)
```
vault write sys/replication/dr/primary/secondary-token id="drsecondary"

Key                              Value
---                              -----
wrapping_token:                  eyJhbGciOiJFUzUxMiIsImtpZCI6IiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NvciI6IiIsImFkZHIiOiJodHRwOi8vMTAuMTAwLjEuMTI6ODIwMCIsImV4cCI6MTU3MDE3Mzg0MCwiaWF0IjoxNTcwMTcyMDQwLCJqdGkiOiJzLjJIb3BLekJyNjZDUjh5ZXlvRmc1TmUwdSIsIm5iZiI6MTU3MDE3MjAzNSwidHlwZSI6IndyYXBwaW5nIn0.ARYjpEzl6xaB4C4rIUerdJrSRxcYvDQfVFw8X3WTyR-KnaWdD7AqljxBiFyE__QDhs0Q5Ki4lp8U_b_QLhiiILBKANVY28b59YMAte_yUTTVlL3KNFqiHNIM4NdEwQBlhRyHysIngbKMEbwhb4cEXHVCqha9ZrUWTDkAz4O5D4CiqVXp
wrapping_accessor:               8BlMvtASSydgetcrd3WkucBR
wrapping_token_ttl:              30m
wrapping_token_creation_time:    2019-10-04 06:54:00.022804034 +0000 UTC
wrapping_token_creation_path:    sys/replication/dr/primary/secondary-token
```

Step 3. Enable DR Replication on the Secondary Cluster (10.100.2.11)
```
vault write sys/replication/dr/secondary/enable token="xxx"

WARNING! The following warnings were returned from Vault:

  * Vault has successfully found secondary information; it may take a while to
  perform setup tasks. Vault will be unavailable until these tasks and initial
  sync complete.
```

After this DR Secondary cluster will act as a passive node but will receive the replicated data from DR Primary.  Due to replication, the unseal keys for the DR Secondary will be the same as the DR Primary.  This is required to promote DR Secondary as the DR Primary.


## 3. Setup Performance Replication
To do this, the following needs to happen.

In the PERFORMANCE PRIMARY cluster (from any node either active or standby):

Step 1. Enable the Primary for Replication.  

If Primary has a loadbalancer then make sure to set the optional primary_cluster_addr parameter to port 8201.  Make sure that the loadbalancer is configured for Layer 4 to pass through TCP traffic.  TCP traffic on port 8201 (Primary Cluster Address) should be a pass through and should not terminate TLS.
Generally, if a loadbalancer is used then both the cluster_addr and api_addr are set to the loadbalancer address in the Vault config file.  Loadbalancer has to be configured to check the /v1/sys/health endpoint to look for the active node and point the traffic to it.

```
# 1. In the Primary Cluster issue the following
vault write -f sys/replication/performance/primary/enable primary_cluster_addr=https://<vault-dns-name>:8201

# or without the primary cluster addr assuming it is specified in the Vault config file
vault write -f sys/replication/performance/primary/enable

WARNING! The following warnings were returned from Vault:

  * This cluster is being enabled as a primary for replication. Vault will be
  unavailable for a brief period and will resume service shortly.
```

Step 2. Generate the Secondary Activation token
```
# 2. Generate the Secondary token from the Primary cluster
vault write sys/replication/performance/primary/secondary-token id="prsecondary" 

Key                              Value
---                              -----
wrapping_token:                  eyJhbGciOiJFUzUxMiIsImtpZCI6IiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NvciI6IiIsImFkZHIiOiJodHRwOi8vMTAuMTAwLjEuMTI6ODIwMCIsImV4cCI6MTU3MDE3NTc5MSwiaWF0IjoxNTcwMTczOTkxLCJqdGkiOiJzLnJXbE9MOXpSNTYwTXpPMVZ2a0lNTEVheiIsIm5iZiI6MTU3MDE3Mzk4NiwidHlwZSI6IndyYXBwaW5nIn0.AOLuErGoYp22opiaSGurQx8-2TtjyQbxED-ReL92xLRGZzGDuE6Pzorwjr0p7RagbKRqIdVOJak1tANgVCza35y3AAyckJ5G3yNV-vN_ob0ycbSnMuJ0IxBi8wBxFYLmmt4_SZ04cYFpaIlIVla4eMDdrC7R6UKaL17jIP0BWA3YG6K2
wrapping_accessor:               d21zpBz3ta8vBYfyFRSYsoEk
wrapping_token_ttl:              30m
wrapping_token_creation_time:    2019-10-04 07:26:31.168313652 +0000 UTC
wrapping_token_creation_path:    sys/replication/performance/primary/secondary-token
```

In the PERFORMANCE SECONDARY cluster (from any node either active or standby): 

Step 3. Activate the Secondary Token.  If the Primary API address is different to the one in the secondary token then set the primary_api_addr optional field.
```
# 3. In the Secondary Cluster issue the following
vault write sys/replication/performance/secondary/enable token="<long-secondary-token>" primary_api_addr=https://<primary-vault-dns-name>:443

WARNING! The following warnings were returned from Vault:

  * Vault has successfully found secondary information; it may take a while to
  perform setup tasks. Vault will be unavailable until these tasks and initial
  sync complete.
```

## 4. Log into the Performance Replication Cluster and Verify

Perform the following in the Secondary cluster
```
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

Test whether the logged in user can list the auth methods

$ vault token lookup
Key                 Value
---                 -----
accessor            46RDqlcUuxAaZO0vExvCUrh0
creation_time       1570174621
creation_ttl        768h
display_name        userpass-test
entity_id           1fae3ac1-c284-2307-dfe5-b68169c2fea2
expire_time         2019-11-05T07:37:01.039086601Z
explicit_max_ttl    0s
id                  s.ZqMbLgCXjkltlZFPkvzZvbQY
issue_time          2019-10-04T07:37:01.039086422Z
meta                map[username:test]
num_uses            0
orphan              true
path                auth/userpass/login/test
policies            [admin default]
renewable           true
ttl                 735h26m11s
type                service


$ vault secrets list

Path             Type         Accessor              Description
----             ----         --------              -----------
cubbyhole/       cubbyhole    cubbyhole_0f6970b2    per-token private secret storage
identity/        identity     identity_75c11c77     identity store
kv-1/            kv           kv_df4ab8d5           n/a
kv-2/            kv           kv_0af47750           n/a
secret-four/     kv           kv_01ecb1e9           n/a
secret-one/      kv           kv_a526acd5           n/a
secret-three/    kv           kv_e8a0b8be           n/a
secret-two/      kv           kv_d9d83f62           n/a
sys/             system       system_3ec7944f       system endpoints used for control, policy and debugging
```

## 5. Monitor Replication Status

Check the status of Replication in all the clusters.

### Primary
Issue the following in the Primary cluster which acts as the DR Primary and PR Primary.
```
vault read -format=json sys/replication/status

{
  "request_id": "d0c05672-0e43-a2f7-f30a-d45fb51204a3",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "cluster_id": "af14c14a-4f45-69b3-2216-6e195dec5cc9",
      "known_secondaries": [
        "drsecondary"
      ],
      "last_reindex_epoch": "0",
      "last_wal": 25874,
      "merkle_root": "f56bea609802c1eeec381e9313a12eed0589bd84",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_secondaries": [
        "prsecondary"
      ],
      "last_reindex_epoch": "0",
      "last_wal": 25874,
      "merkle_root": "316f43188a6b81520da25402d0206c3d29bb3da7",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    }
  },
  "warnings": null
}

```

### DR Secondary

```
vault read -format=json sys/replication/status

{
  "request_id": "25c0047a-1b67-1f23-5157-97e037e17caa",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "cluster_id": "af14c14a-4f45-69b3-2216-6e195dec5cc9",
      "known_primary_cluster_addrs": [
        "https://10.100.1.12:8201",
        "https://10.100.1.11:8201"
      ],
      "last_reindex_epoch": "1570172170",
      "last_remote_wal": 25874,
      "merkle_root": "f56bea609802c1eeec381e9313a12eed0589bd84",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.1.12:8201",
      "secondary_id": "drsecondary",
      "state": "stream-wals"
    },
    "performance": {
      "mode": "disabled"
    }
  },
  "warnings": null
}
```

### PR Secondary

```
vault read -format=json sys/replication/status 

{
  "request_id": "a4f05ac9-6ba4-83cf-5270-4f6dc8424923",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_primary_cluster_addrs": [
        "https://10.100.1.12:8201",
        "https://10.100.1.11:8201"
      ],
      "last_reindex_epoch": "1570174228",
      "last_remote_wal": 25875,
      "merkle_root": "2bb4dbeca0382e19b61f3d8cf3315adea51f3474",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.1.12:8201",
      "secondary_id": "prsecondary",
      "state": "stream-wals"
    }
  },
  "warnings": null
}
```

## 6. Shutdown the Active Node of the Primary
Primary has 2 nodes and the current active node at 10.100.1.12 is shutdown.  This has updated node 10.100.1.11 as the active node. This should update the known_primary_cluster_addr filed in both DR and PR clusters.

### DR Secondary
```
vault read -format=json sys/replication/status

{
  "request_id": "9ec53510-519d-7870-ce23-1c24a79000fe",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "cluster_id": "af14c14a-4f45-69b3-2216-6e195dec5cc9",
      "known_primary_cluster_addrs": [
        "https://10.100.1.11:8201"
      ],
      "last_reindex_epoch": "1570172170",
      "last_remote_wal": 25976,
      "merkle_root": "b7e1f1d36e4e5d725e86f95449ab8a2ce10c3bd3",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.1.12:8201",
      "secondary_id": "drsecondary",
      "state": "stream-wals"
    },
    "performance": {
      "mode": "disabled"
    }
  },
  "warnings": null
}
```
Note that the primary_cluster_addr is not changed as it is set at the time of initial bootstrap. 

### PR Secondary
```
vault read -format=json sys/replication/status

{
  "request_id": "ff00cc63-4bd2-775c-4ba8-5eb9046cb47f",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_primary_cluster_addrs": [
        "https://10.100.1.11:8201"
      ],
      "last_reindex_epoch": "1570174228",
      "last_remote_wal": 25974,
      "merkle_root": "576cfb3b28975c9bdbe3f9b6812a54788cdfc135",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.1.12:8201",
      "secondary_id": "prsecondary",
      "state": "stream-wals"
    }
  },
  "warnings": null
}
```

## 7. Shutdown the Primary Cluster
Shutdown the last node of the primary cluster.  This should stop all replications from the current Primary cluster.

```
sudo systemctl stop vault
```

### DR Secondary
The known_primary_cluster_addrs is not updated after shutting down the DR Primary cluster

```
vault read -format=json sys/replication/status

{
  "request_id": "9994d8a8-1a30-76da-db88-315875fde707",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "cluster_id": "af14c14a-4f45-69b3-2216-6e195dec5cc9",
      "known_primary_cluster_addrs": [
        "https://10.100.1.11:8201"
      ],
      "last_reindex_epoch": "1570172170",
      "last_remote_wal": 26433,
      "merkle_root": "ce91323ad68e56c2d1826e8007d0139a051bed13",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.1.12:8201",
      "secondary_id": "drsecondary",
      "state": "stream-wals"
    },
    "performance": {
      "mode": "disabled"
    }
  },
  "warnings": null
}
```

### PR Secondary
The known_primary_cluster_addrs is not updated after shutting down the DR Primary cluster

```
vault read -format=json sys/replication/status

{
  "request_id": "d261df73-22aa-cd8f-db1c-7c5ea67ff46e",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_primary_cluster_addrs": [
        "https://10.100.1.11:8201"
      ],
      "last_reindex_epoch": "1570174228",
      "last_remote_wal": 26433,
      "merkle_root": "c6af199949714f98ee9db3330609ee5501313176",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.1.12:8201",
      "secondary_id": "prsecondary",
      "state": "stream-wals"
    }
  },
  "warnings": null
}
```

## 8. Promote DR Secondary Cluster as the DR Primary
Promote DR Secondary as the new DR Primary.  Then check the replication status.

Step 1. Generate a One Time Password to generate a DR Operation Token
```
vault operator generate-root -dr-token -init

A One-Time-Password has been generated for you and is shown in the OTP field.
You will need this value to decode the resulting root token, so keep it safe.
Nonce         1bbf4848-975b-3ea4-977f-3ebab7e3e2fa
Started       true
Progress      0/1
Complete      false
OTP           qZkG8AAgu4l5KOdypXG1TQS8lz
OTP Length    26
```

Step 2. Generate the encoded DR token by providing all the required threshold for the Unseal key.  Use the Nonce from the output of Step 1.  When prompted for the Unseal Key, input the unseal key of the original DR Primary's unseal key.
```
vault operator generate-root -dr-token -nonce=1bbf4848-975b-3ea4-977f-3ebab7e3e2fa
Operation nonce: 1bbf4848-975b-3ea4-977f-3ebab7e3e2fa
Unseal Key (will be hidden):


Nonce            1bbf4848-975b-3ea4-977f-3ebab7e3e2fa
Started          true
Progress         1/1
Complete         true
Encoded Token    AnQ+CEkZCyEcUit5fnoiEBI8I1MYFSlXBE4
```

Step 3. Use the One-Time Password from Step 1 to decode the encoded DR Token from Step 2.
```
vault operator generate-root -dr-token -decode="AnQ+CEkZCyEcUit5fnoiEBI8I1MYFSlXBE4" -otp="qZkG8AAgu4l5KOdypXG1TQS8lz"

s.UOqXJFifGL55FibddbLDzoh4
```

Step 4.  Promote the DR Secondary as DR Primary
```
vault write /sys/replication/dr/secondary/promote dr_operation_token=s.UOqXJFifGL55FibddbLDzoh4

WARNING! The following warnings were returned from Vault:

  * This cluster is being promoted to a replication primary. Vault will be
  unavailable for a brief period and will resume service shortly.
```

DR Secondary is now become the DR Primary.  

Do the Replication status on this new DR Primary and the existing PR Secondary to check the details including known_primary_cluster_addrs.

### DR Primary (Old DR Secondary and now Promoted as DR Primary)
```
vault read -format=json sys/replication/status

{
  "request_id": "ffddb924-7310-74fc-5256-d0f57a1848d9",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "cluster_id": "af14c14a-4f45-69b3-2216-6e195dec5cc9",
      "known_secondaries": [],
      "last_reindex_epoch": "0",
      "last_wal": 26363,
      "merkle_root": "9ae04165be9ed3b0eb9144d86ddcfed1b37b3015",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_secondaries": [
        "prsecondary"
      ],
      "last_reindex_epoch": "0",
      "last_wal": 26363,
      "merkle_root": "c6af199949714f98ee9db3330609ee5501313176",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    }
  },
  "warnings": null
}
```

Note that both the DR & PR mode show that this cluster is marked as DR Primary and PR Primary respectively.

### PR Secondary
```
vault read -format=json sys/replication/status

{
  "request_id": "3dcaf298-8e6e-8a30-635f-57f6488bbde2",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_primary_cluster_addrs": [
        "https://10.100.2.11:8201"
      ],
      "last_reindex_epoch": "1570174228",
      "last_remote_wal": 26433,
      "merkle_root": "0d68081c7db7aa6bcc9bfeffc27063f16861632f",
      "mode": "secondary",
      "primary_cluster_addr": "https://10.100.2.11:8201",
      "secondary_id": "prsecondary",
      "state": "stream-wals"
    }
  },
  "warnings": null
}
```

The known_primary_cluster_addrs is showing the promoted DR Primary cluster at 10.100.2.11.  This is done automatically and Replication from the new PR Primary to PR Secondary is continuing without any further manual configuration.

## 9. Bring up the Old Primary
Bring up the Old Primary cluster node and disable DR and Performance Replication so that the secondaries will not connect to the old Primary.

Step 1.  Start Vault
```
sudo systemctl start vault
```

Step 2. Unseal Vault using the original unseal key
```
vault operator unseal <unseal_key>
```

Step 3.  Check the replication status
The old replication config should be displayed when the Replication status is checked
```
vault read -format=json sys/replication/status

{
  "request_id": "f980caaa-6e26-c682-6a4f-ed7fb46bd7be",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "cluster_id": "af14c14a-4f45-69b3-2216-6e195dec5cc9",
      "known_secondaries": [
        "drsecondary"
      ],
      "last_reindex_epoch": "0",
      "last_wal": 26434,
      "merkle_root": "2992208c795d4ba772402ec22f9ef31a056f0b33",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_secondaries": [
        "prsecondary"
      ],
      "last_reindex_epoch": "0",
      "last_wal": 26434,
      "merkle_root": "c6af199949714f98ee9db3330609ee5501313176",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    }
  },
  "warnings": null
}
```

Step 4. Disable DR Replication
```
vault write -f sys/replication/dr/primary/disable
WARNING! The following warnings were returned from Vault:

  * This cluster is having replication disabled. Vault will be unavailable for
  a brief period and will resume service shortly.

vault read -format=json sys/replication/status
{
  "request_id": "c19f1bcd-80c0-93cb-b5a7-c3fc6051d73e",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "cluster_id": "37f97841-739a-40f4-cb13-f043e748ea74",
      "known_secondaries": [
        "prsecondary"
      ],
      "last_reindex_epoch": "0",
      "last_wal": 26435,
      "merkle_root": "c6af199949714f98ee9db3330609ee5501313176",
      "mode": "primary",
      "primary_cluster_addr": "",
      "state": "running"
    }
  },
  "warnings": null
}
```

The above shows that the DR mode is disabled but the Performance is still enabled.  

Step 5. Disable Performance Replication
```
vault write -f sys/replication/performance/primary/disable
WARNING! The following warnings were returned from Vault:

  * This cluster is having replication disabled. Vault will be unavailable for
  a brief period and will resume service shortly.

vault read -format=json sys/replication/status
{
  "request_id": "9aa1d13e-34d7-1415-ed74-a7104e274ac5",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "mode": "disabled"
    }
  },
  "warnings": null
}
```

Now performance replication mode is disabled
