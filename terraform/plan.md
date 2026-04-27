terraform -chdir=/home/dan/work/triplea-project/infrastructure/terraform apply -input=false
[0m[33mRunning apply in the remote backend. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.[0m

Preparing the remote apply...
[0m
[0m[33mTo view this run in a browser, visit:[0m
[0m[33mhttps://app.terraform.io/app/triplea-tf/infra/runs/run-trG98nJmJZK8a4Cj[0m
[0m
Waiting for 1 run(s) to finish before being queued...
Waiting for 1 run(s) to finish before being queued... (30s elapsed)
Waiting for 1 run(s) to finish before being queued... (1m0s elapsed)

Terraform v1.14.8
on linux_amd64
Initializing plugins and modules...
[0m[1mlinode_instance.servers["Bot-us-west-1"]: Refreshing state... [id=96297148][0m
[0m[1mlinode_instance.servers["Bot-us-east-2"]: Refreshing state... [id=96297147][0m

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  [31m-[0m destroy[0m
[31m-[0m/[32m+[0m destroy and then create replacement[0m

Terraform will perform the following actions:

[1m  # linode_instance.servers["Bot-us-east-2"][0m must be [1m[31mreplaced[0m
[0m[31m-[0m/[32m+[0m[0m resource "linode_instance" "servers" {
      [31m-[0m[0m authorized_keys    = [ [31m# forces replacement[0m[0m
          [31m-[0m[0m "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAo4tUJg3cgpqaZcp41hE/01XMOJLHRXT8GQSmHc3aF root@triplea",
        ] [90m-> null[0m[0m
      [33m~[0m[0m backups            = [
          [31m-[0m[0m {
              [31m-[0m[0m available = false
              [31m-[0m[0m enabled   = false
              [31m-[0m[0m schedule  = [
                  [31m-[0m[0m {
                        [90m# (2 unchanged attributes hidden)[0m[0m
                    },
                ]
            },
        ] -> (known after apply)
      [33m~[0m[0m backups_enabled    = false -> (known after apply)
      [33m~[0m[0m boot_config_label  = "My Ubuntu 24.04 LTS Disk Profile" -> (known after apply)
      [33m~[0m[0m booted             = true -> (known after apply)
      [33m~[0m[0m capabilities       = [
          [31m-[0m[0m "Block Storage Encryption",
          [31m-[0m[0m "Maintenance Policy",
          [31m-[0m[0m "SMTP Enabled",
        ] -> (known after apply)
      [33m~[0m[0m disk_encryption    = "enabled" -> (known after apply)
      [33m~[0m[0m has_user_data      = true -> (known after apply)
      [33m~[0m[0m host_uuid          = "99fb0799c77aa6f846de86a3982d31d05aca750a" -> (known after apply)
      [33m~[0m[0m id                 = "96297147" -> (known after apply)
      [33m~[0m[0m ip_address         = "45.79.152.233" -> (known after apply)
      [33m~[0m[0m ipv4               = [
          [31m-[0m[0m "45.79.152.233",
        ] -> (known after apply)
      [33m~[0m[0m ipv6               = "2600:3c03::2000:f8ff:fece:92bf/128" -> (known after apply)
      [33m~[0m[0m lke_cluster_id     = 0 -> (known after apply)
      [31m-[0m[0m private_ip         = false [90m-> null[0m[0m
      [32m+[0m[0m private_ip_address = (known after apply)
      [33m~[0m[0m shared_ipv4        = [] -> (known after apply)
      [33m~[0m[0m specs              = [
          [31m-[0m[0m {
              [31m-[0m[0m accelerated_devices = 0
              [31m-[0m[0m disk                = 25600
              [31m-[0m[0m gpus                = 0
              [31m-[0m[0m memory              = 1024
              [31m-[0m[0m transfer            = 1000
              [31m-[0m[0m vcpus               = 1
            },
        ] -> (known after apply)
      [33m~[0m[0m status             = "running" -> (known after apply)
      [33m~[0m[0m swap_size          = 512 -> (known after apply)
        tags               = [
            "bots",
        ]
        [90m# (8 unchanged attributes hidden)[0m[0m

      [33m~[0m[0m alerts (known after apply)
      [31m-[0m[0m alerts {
          [31m-[0m[0m cpu            = 90 [90m-> null[0m[0m
          [31m-[0m[0m io             = 10000 [90m-> null[0m[0m
          [31m-[0m[0m network_in     = 10 [90m-> null[0m[0m
          [31m-[0m[0m network_out    = 10 [90m-> null[0m[0m
          [31m-[0m[0m transfer_quota = 80 [90m-> null[0m[0m
        }

      [33m~[0m[0m config (known after apply)
      [31m-[0m[0m config {
          [31m-[0m[0m id           = 99767242 [90m-> null[0m[0m
          [31m-[0m[0m kernel       = "linode/grub2" [90m-> null[0m[0m
          [31m-[0m[0m label        = "My Ubuntu 24.04 LTS Disk Profile" [90m-> null[0m[0m
          [31m-[0m[0m memory_limit = 0 [90m-> null[0m[0m
          [31m-[0m[0m root_device  = "/dev/sda" [90m-> null[0m[0m
          [31m-[0m[0m run_level    = "default" [90m-> null[0m[0m
          [31m-[0m[0m virt_mode    = "paravirt" [90m-> null[0m[0m
            [90m# (1 unchanged attribute hidden)[0m[0m

          [31m-[0m[0m devices {
              [31m-[0m[0m sda {
                  [31m-[0m[0m disk_id    = 181794995 [90m-> null[0m[0m
                  [31m-[0m[0m disk_label = "Ubuntu 24.04 LTS Disk" [90m-> null[0m[0m
                  [31m-[0m[0m volume_id  = 0 [90m-> null[0m[0m
                }
              [31m-[0m[0m sdb {
                  [31m-[0m[0m disk_id    = 181794996 [90m-> null[0m[0m
                  [31m-[0m[0m disk_label = "512 MB Swap Image" [90m-> null[0m[0m
                  [31m-[0m[0m volume_id  = 0 [90m-> null[0m[0m
                }
            }

          [31m-[0m[0m helpers {
              [31m-[0m[0m devtmpfs_automount = true [90m-> null[0m[0m
              [31m-[0m[0m distro             = true [90m-> null[0m[0m
              [31m-[0m[0m modules_dep        = true [90m-> null[0m[0m
              [31m-[0m[0m network            = false [90m-> null[0m[0m
              [31m-[0m[0m updatedb_disabled  = true [90m-> null[0m[0m
            }
        }

      [33m~[0m[0m disk (known after apply)
      [31m-[0m[0m disk {
          [31m-[0m[0m authorized_keys  = [] [90m-> null[0m[0m
          [31m-[0m[0m authorized_users = [] [90m-> null[0m[0m
          [31m-[0m[0m filesystem       = "ext4" [90m-> null[0m[0m
          [31m-[0m[0m id               = 181794995 [90m-> null[0m[0m
          [31m-[0m[0m label            = "Ubuntu 24.04 LTS Disk" [90m-> null[0m[0m
          [31m-[0m[0m read_only        = false [90m-> null[0m[0m
          [31m-[0m[0m size             = 25088 [90m-> null[0m[0m
          [31m-[0m[0m stackscript_data = (sensitive value) [90m-> null[0m[0m
          [31m-[0m[0m stackscript_id   = 0 [90m-> null[0m[0m
            [90m# (2 unchanged attributes hidden)[0m[0m
        }
      [31m-[0m[0m disk {
          [31m-[0m[0m authorized_keys  = [] [90m-> null[0m[0m
          [31m-[0m[0m authorized_users = [] [90m-> null[0m[0m
          [31m-[0m[0m filesystem       = "swap" [90m-> null[0m[0m
          [31m-[0m[0m id               = 181794996 [90m-> null[0m[0m
          [31m-[0m[0m label            = "512 MB Swap Image" [90m-> null[0m[0m
          [31m-[0m[0m read_only        = false [90m-> null[0m[0m
          [31m-[0m[0m size             = 512 [90m-> null[0m[0m
          [31m-[0m[0m stackscript_data = (sensitive value) [90m-> null[0m[0m
          [31m-[0m[0m stackscript_id   = 0 [90m-> null[0m[0m
            [90m# (2 unchanged attributes hidden)[0m[0m
        }

      [33m~[0m[0m metadata {
          [33m~[0m[0m user_data = "I2Nsb3VkLWNvbmZpZwp1c2VyczoKICAtIG5hbWU6IHJvb3QKICAgIHN1ZG86IEFMTD0oQUxMKSBOT1BBU1NXRDpBTEwKICAgIHNoZWxsOiAvYmluL2Jhc2gKICAgIHNzaF9hdXRob3JpemVkX2tleXM6CiAgICAgIC0gc3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUxBbzR0VUpnM2NncHFhWmNwNDFoRS8wMVhNT0pMSFJYVDhHUVNtSGMzYUYgcm9vdEB0cmlwbGVhCgogIC0gbmFtZTogYW5zaWJsZQogICAgZ2Vjb3M6IEFuc2libGUgVXNlcgogICAgc3VkbzogQUxMPShBTEwpIE5PUEFTU1dEOkFMTAogICAgc2hlbGw6IC9iaW4vYmFzaAogICAgc3NoX2F1dGhvcml6ZWRfa2V5czoKICAgICAgLSBzc2gtZWQyNTUxOSBBQUFBQzNOemFDMWxaREkxTlRFNUFBQUFJTEJhazFES3E1ZTdzN3VFZ1dpSWI5M2RXdGVkRElaczVHdEU1N3Vtc0R0aiBhbnNpYmxlQGdpdGh1YkFjdGlvbnMKCiAgIyBhbnNpYmxlOiBwZXJzb25hbCBhZG1pbiBhY2NvdW50IGNyZWF0ZWQgYXQgZmlyc3QgYm9vdCBzbyB0aGlzCiAgIyBtYWludGFpbmVyIGNhbiBTU0ggaW4gaW1tZWRpYXRlbHkgYW5kIHJ1biBBbnNpYmxlIHdpdGhvdXQgbmVlZGluZyB0aGUKICAjIGFuc2libGUgc2VydmljZSBhY2NvdW50IGtleS4gQW5zaWJsZSBjb252ZXJnZXMgb24gdG9wIGlkZW1wb3RlbnRseS4KICAtIG5hbWU6IGFuc2libGUKICAgIHN1ZG86IEFMTD0oQUxMKSBOT1BBU1NXRDpBTEwKICAgIHNoZWxsOiAvYmluL2Jhc2gKICAgIHNzaF9hdXRob3JpemVkX2tleXM6CiAgICAgIC0gc3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdSUXl5ODZHMk5RVU1MM3RVUXJvTjMwWmlDTHQ5cW1QZ2xyVGZKMElmQ3IgYW5zaWJsZUB0cmlwbGVhCgogICMgZGFuOiBwZXJzb25hbCBhZG1pbiBhY2NvdW50IGNyZWF0ZWQgYXQgZmlyc3QgYm9vdCBzbyB0aGlzCiAgIyBtYWludGFpbmVyIGNhbiBTU0ggaW4gaW1tZWRpYXRlbHkgYW5kIHJ1biBBbnNpYmxlIHdpdGhvdXQgbmVlZGluZyB0aGUKICAjIGFuc2libGUgc2VydmljZSBhY2NvdW50IGtleS4gQW5zaWJsZSBjb252ZXJnZXMgb24gdG9wIGlkZW1wb3RlbnRseS4KICAtIG5hbWU6IGRhbgogICAgc3VkbzogQUxMPShBTEwpIE5PUEFTU1dEOkFMTAogICAgc2hlbGw6IC9iaW4vYmFzaAogICAgc3NoX2F1dGhvcml6ZWRfa2V5czoKICAgICAgLSBzc2gtZWQyNTUxOSBBQUFBQzNOemFDMWxaREkxTlRFNUFBQUFJRU5ab1c5Mm1Od3RrcnkveURHU1FCNTFBcDdKbzJ3c1ZPTjFsNVNrN25KdCBkYW5AZGVzawoKc3NoX3B3YXV0aDogZmFsc2UK" [33m->[0m[0m "I2Nsb3VkLWNvbmZpZwojICdjbG91ZC1jb25maWcnIGZpbGUgdGhhdCBjcmVhdGVzIHVzZXIgYWNjb3VudHMgb24gZmlyc3QgYm9vdAp1c2VyczoKICAtIG5hbWU6IGFuc2libGUKICAgIHN1ZG86CiAgICAgIC0gQUxMPShBTEwpIE5PUEFTU1dEOkFMTAogICAgICAtIERlZmF1bHRzOmFuc2libGUgIXJlcXVpcmV0dHkKICAgIHNoZWxsOiAvYmluL2Jhc2gKICAgIHNzaF9hdXRob3JpemVkX2tleXM6CiAgICAgIC0gc3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdSUXl5ODZHMk5RVU1MM3RVUXJvTjMwWmlDTHQ5cW1QZ2xyVGZKMElmQ3IgYW5zaWJsZUB0cmlwbGVhCgogIC0gbmFtZTogZGFuCiAgICBzdWRvOgogICAgICAtIEFMTD0oQUxMKSBOT1BBU1NXRDpBTEwKICAgICAgLSBEZWZhdWx0czpkYW4gIXJlcXVpcmV0dHkKICAgIHNoZWxsOiAvYmluL2Jhc2gKICAgIHNzaF9hdXRob3JpemVkX2tleXM6CiAgICAgIC0gc3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUVOWm9XOTJtTnd0a3J5L3lER1NRQjUxQXA3Sm8yd3NWT04xbDVTazduSnQgZGFuQGRlc2sKCnNzaF9wd2F1dGg6IGZhbHNlCg=="
        }
    }

[1m  # linode_instance.servers["Bot-us-west-1"][0m will be [1m[31mdestroyed[0m
  # (because key ["Bot-us-west-1"] is not in for_each map)
[0m  [31m-[0m[0m resource "linode_instance" "servers" {
      [31m-[0m[0m authorized_keys   = [
          [31m-[0m[0m "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAo4tUJg3cgpqaZcp41hE/01XMOJLHRXT8GQSmHc3aF root@triplea",
        ] [90m-> null[0m[0m
      [31m-[0m[0m backups           = [
          [31m-[0m[0m {
              [31m-[0m[0m available = false
              [31m-[0m[0m enabled   = false
              [31m-[0m[0m schedule  = [
                  [31m-[0m[0m {
                        [90m# (2 unchanged attributes hidden)[0m[0m
                    },
                ]
            },
        ] [90m-> null[0m[0m
      [31m-[0m[0m backups_enabled   = false [90m-> null[0m[0m
      [31m-[0m[0m boot_config_label = "My Ubuntu 24.04 LTS Disk Profile" [90m-> null[0m[0m
      [31m-[0m[0m booted            = true [90m-> null[0m[0m
      [31m-[0m[0m capabilities      = [
          [31m-[0m[0m "Block Storage Encryption",
          [31m-[0m[0m "Maintenance Policy",
          [31m-[0m[0m "SMTP Enabled",
        ] [90m-> null[0m[0m
      [31m-[0m[0m disk_encryption   = "enabled" [90m-> null[0m[0m
      [31m-[0m[0m has_user_data     = true [90m-> null[0m[0m
      [31m-[0m[0m host_uuid         = "f81950d2dfaecd1858a9ea1fe03cdc2c501b988e" [90m-> null[0m[0m
      [31m-[0m[0m id                = "96297148" [90m-> null[0m[0m
      [31m-[0m[0m image             = "linode/ubuntu24.04" [90m-> null[0m[0m
      [31m-[0m[0m ip_address        = "45.33.50.173" [90m-> null[0m[0m
      [31m-[0m[0m ipv4              = [
          [31m-[0m[0m "45.33.50.173",
        ] [90m-> null[0m[0m
      [31m-[0m[0m ipv6              = "2600:3c01::2000:deff:fe21:7b94/128" [90m-> null[0m[0m
      [31m-[0m[0m label             = "Bot-us-west-1" [90m-> null[0m[0m
      [31m-[0m[0m lke_cluster_id    = 0 [90m-> null[0m[0m
      [31m-[0m[0m migration_type    = "cold" [90m-> null[0m[0m
      [31m-[0m[0m private_ip        = false [90m-> null[0m[0m
      [31m-[0m[0m region            = "us-west" [90m-> null[0m[0m
      [31m-[0m[0m resize_disk       = false [90m-> null[0m[0m
      [31m-[0m[0m shared_ipv4       = [] [90m-> null[0m[0m
      [31m-[0m[0m specs             = [
          [31m-[0m[0m {
              [31m-[0m[0m accelerated_devices = 0
              [31m-[0m[0m disk                = 25600
              [31m-[0m[0m gpus                = 0
              [31m-[0m[0m memory              = 1024
              [31m-[0m[0m transfer            = 1000
              [31m-[0m[0m vcpus               = 1
            },
        ] [90m-> null[0m[0m
      [31m-[0m[0m status            = "running" [90m-> null[0m[0m
      [31m-[0m[0m swap_size         = 512 [90m-> null[0m[0m
      [31m-[0m[0m tags              = [
          [31m-[0m[0m "bots",
        ] [90m-> null[0m[0m
      [31m-[0m[0m type              = "g6-nanode-1" [90m-> null[0m[0m
      [31m-[0m[0m watchdog_enabled  = true [90m-> null[0m[0m
        [90m# (1 unchanged attribute hidden)[0m[0m

      [31m-[0m[0m alerts {
          [31m-[0m[0m cpu            = 90 [90m-> null[0m[0m
          [31m-[0m[0m io             = 10000 [90m-> null[0m[0m
          [31m-[0m[0m network_in     = 10 [90m-> null[0m[0m
          [31m-[0m[0m network_out    = 10 [90m-> null[0m[0m
          [31m-[0m[0m transfer_quota = 80 [90m-> null[0m[0m
        }

      [31m-[0m[0m config {
          [31m-[0m[0m id           = 99767243 [90m-> null[0m[0m
          [31m-[0m[0m kernel       = "linode/grub2" [90m-> null[0m[0m
          [31m-[0m[0m label        = "My Ubuntu 24.04 LTS Disk Profile" [90m-> null[0m[0m
          [31m-[0m[0m memory_limit = 0 [90m-> null[0m[0m
          [31m-[0m[0m root_device  = "/dev/sda" [90m-> null[0m[0m
          [31m-[0m[0m run_level    = "default" [90m-> null[0m[0m
          [31m-[0m[0m virt_mode    = "paravirt" [90m-> null[0m[0m
            [90m# (1 unchanged attribute hidden)[0m[0m

          [31m-[0m[0m devices {
              [31m-[0m[0m sda {
                  [31m-[0m[0m disk_id    = 181794997 [90m-> null[0m[0m
                  [31m-[0m[0m disk_label = "Ubuntu 24.04 LTS Disk" [90m-> null[0m[0m
                  [31m-[0m[0m volume_id  = 0 [90m-> null[0m[0m
                }
              [31m-[0m[0m sdb {
                  [31m-[0m[0m disk_id    = 181794999 [90m-> null[0m[0m
                  [31m-[0m[0m disk_label = "512 MB Swap Image" [90m-> null[0m[0m
                  [31m-[0m[0m volume_id  = 0 [90m-> null[0m[0m
                }
            }

          [31m-[0m[0m helpers {
              [31m-[0m[0m devtmpfs_automount = true [90m-> null[0m[0m
              [31m-[0m[0m distro             = true [90m-> null[0m[0m
              [31m-[0m[0m modules_dep        = true [90m-> null[0m[0m
              [31m-[0m[0m network            = false [90m-> null[0m[0m
              [31m-[0m[0m updatedb_disabled  = true [90m-> null[0m[0m
            }
        }

      [31m-[0m[0m disk {
          [31m-[0m[0m authorized_keys  = [] [90m-> null[0m[0m
          [31m-[0m[0m authorized_users = [] [90m-> null[0m[0m
          [31m-[0m[0m filesystem       = "ext4" [90m-> null[0m[0m
          [31m-[0m[0m id               = 181794997 [90m-> null[0m[0m
          [31m-[0m[0m label            = "Ubuntu 24.04 LTS Disk" [90m-> null[0m[0m
          [31m-[0m[0m read_only        = false [90m-> null[0m[0m
          [31m-[0m[0m size             = 25088 [90m-> null[0m[0m
          [31m-[0m[0m stackscript_data = (sensitive value) [90m-> null[0m[0m
          [31m-[0m[0m stackscript_id   = 0 [90m-> null[0m[0m
            [90m# (2 unchanged attributes hidden)[0m[0m
        }
      [31m-[0m[0m disk {
          [31m-[0m[0m authorized_keys  = [] [90m-> null[0m[0m
          [31m-[0m[0m authorized_users = [] [90m-> null[0m[0m
          [31m-[0m[0m filesystem       = "swap" [90m-> null[0m[0m
          [31m-[0m[0m id               = 181794999 [90m-> null[0m[0m
          [31m-[0m[0m label            = "512 MB Swap Image" [90m-> null[0m[0m
          [31m-[0m[0m read_only        = false [90m-> null[0m[0m
          [31m-[0m[0m size             = 512 [90m-> null[0m[0m
          [31m-[0m[0m stackscript_data = (sensitive value) [90m-> null[0m[0m
          [31m-[0m[0m stackscript_id   = 0 [90m-> null[0m[0m
            [90m# (2 unchanged attributes hidden)[0m[0m
        }

      [31m-[0m[0m metadata {
          [31m-[0m[0m user_data = "I2Nsb3VkLWNvbmZpZwp1c2VyczoKICAtIG5hbWU6IHJvb3QKICAgIHN1ZG86IEFMTD0oQUxMKSBOT1BBU1NXRDpBTEwKICAgIHNoZWxsOiAvYmluL2Jhc2gKICAgIHNzaF9hdXRob3JpemVkX2tleXM6CiAgICAgIC0gc3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUxBbzR0VUpnM2NncHFhWmNwNDFoRS8wMVhNT0pMSFJYVDhHUVNtSGMzYUYgcm9vdEB0cmlwbGVhCgogIC0gbmFtZTogYW5zaWJsZQogICAgZ2Vjb3M6IEFuc2libGUgVXNlcgogICAgc3VkbzogQUxMPShBTEwpIE5PUEFTU1dEOkFMTAogICAgc2hlbGw6IC9iaW4vYmFzaAogICAgc3NoX2F1dGhvcml6ZWRfa2V5czoKICAgICAgLSBzc2gtZWQyNTUxOSBBQUFBQzNOemFDMWxaREkxTlRFNUFBQUFJTEJhazFES3E1ZTdzN3VFZ1dpSWI5M2RXdGVkRElaczVHdEU1N3Vtc0R0aiBhbnNpYmxlQGdpdGh1YkFjdGlvbnMKCiAgIyBhbnNpYmxlOiBwZXJzb25hbCBhZG1pbiBhY2NvdW50IGNyZWF0ZWQgYXQgZmlyc3QgYm9vdCBzbyB0aGlzCiAgIyBtYWludGFpbmVyIGNhbiBTU0ggaW4gaW1tZWRpYXRlbHkgYW5kIHJ1biBBbnNpYmxlIHdpdGhvdXQgbmVlZGluZyB0aGUKICAjIGFuc2libGUgc2VydmljZSBhY2NvdW50IGtleS4gQW5zaWJsZSBjb252ZXJnZXMgb24gdG9wIGlkZW1wb3RlbnRseS4KICAtIG5hbWU6IGFuc2libGUKICAgIHN1ZG86IEFMTD0oQUxMKSBOT1BBU1NXRDpBTEwKICAgIHNoZWxsOiAvYmluL2Jhc2gKICAgIHNzaF9hdXRob3JpemVkX2tleXM6CiAgICAgIC0gc3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdSUXl5ODZHMk5RVU1MM3RVUXJvTjMwWmlDTHQ5cW1QZ2xyVGZKMElmQ3IgYW5zaWJsZUB0cmlwbGVhCgogICMgZGFuOiBwZXJzb25hbCBhZG1pbiBhY2NvdW50IGNyZWF0ZWQgYXQgZmlyc3QgYm9vdCBzbyB0aGlzCiAgIyBtYWludGFpbmVyIGNhbiBTU0ggaW4gaW1tZWRpYXRlbHkgYW5kIHJ1biBBbnNpYmxlIHdpdGhvdXQgbmVlZGluZyB0aGUKICAjIGFuc2libGUgc2VydmljZSBhY2NvdW50IGtleS4gQW5zaWJsZSBjb252ZXJnZXMgb24gdG9wIGlkZW1wb3RlbnRseS4KICAtIG5hbWU6IGRhbgogICAgc3VkbzogQUxMPShBTEwpIE5PUEFTU1dEOkFMTAogICAgc2hlbGw6IC9iaW4vYmFzaAogICAgc3NoX2F1dGhvcml6ZWRfa2V5czoKICAgICAgLSBzc2gtZWQyNTUxOSBBQUFBQzNOemFDMWxaREkxTlRFNUFBQUFJRU5ab1c5Mm1Od3RrcnkveURHU1FCNTFBcDdKbzJ3c1ZPTjFsNVNrN25KdCBkYW5AZGVzawoKc3NoX3B3YXV0aDogZmFsc2UK" [90m-> null[0m[0m
        }
    }

[1mPlan:[0m [0m1 to add, 0 to change, 2 to destroy.
[0m[1m
Do you want to perform these actions in workspace "infra"?[0m
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  [1mEnter a value:[0m [0m

Interrupt received.
Please wait for Terraform to exit or data loss may occur.
Gracefully shutting down...

