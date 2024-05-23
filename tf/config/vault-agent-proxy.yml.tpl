#cloud-config

write_files:
  - path: /etc/vault.d/secret.ctmpl
    content: |
      This will appear above the rendered secrets.
      {{- with secret "kv/demo/engineering/app02" -}}
      username={{ .Data.data.username }}
      password={{ .Data.data.password }}
      {{- end -}}
      This will appear below the rendered secrets.

  - path: /etc/vault.d/agent.hcl
    content: |
      vault {
        address = "${vault_address}"
      }

      auto_auth {
        method "aws" {
            config = {
                type = "iam"
                role = "demo-ec2"
            }
        }
      }

      template {
        source = "/etc/vault.d/secret.ctmpl"
        destination = "/run/vault/secret"
        perms = "640"
        group = "www-data"
      }

  - path: /etc/vault.d/proxy.hcl
    content: |
      vault {
        address = "${vault_address}"
      }

      auto_auth {
        method "aws" {
            config = {
                type = "iam"
                role = "demo-ec2"
            }
        }
      }

      api_proxy {
        use_auto_auth_token = true
      }

      # can use a unix socket for additional security
      # https://developer.hashicorp.com/vault/docs/configuration/listener/unix
      listener "tcp" {
        address = "127.0.0.1:8100"
        tls_disable = true
      }

  - path: /lib/systemd/system/vault-agent.service
    permissions: "0644"
    content: |
      [Unit]
      Description="HashiCorp Vault Agent - A tool for managing secrets"
      Documentation=https://developer.hashicorp.com/vault/docs
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=/etc/vault.d/agent.hcl
      StartLimitIntervalSec=60
      StartLimitBurst=3

      [Service]
      Type=notify
      User=vault
      Group=vault
      ProtectSystem=full
      ProtectHome=read-only
      PrivateTmp=yes
      PrivateDevices=yes
      SecureBits=keep-caps
      AmbientCapabilities=CAP_IPC_LOCK
      CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
      NoNewPrivileges=yes
      ExecStart=/usr/bin/vault agent -config=/etc/vault.d/agent.hcl
      ExecReload=/bin/kill --signal HUP $MAINPID
      KillMode=process
      KillSignal=SIGINT
      Restart=on-failure
      RestartSec=5
      TimeoutStopSec=30
      LimitNOFILE=65536
      LimitMEMLOCK=infinity

      [Install]
      WantedBy=multi-user.target

  - path: /lib/systemd/system/vault-proxy.service
    permissions: "0644"
    content: |
      [Unit]
      Description="HashiCorp Vault Proxy - A tool for managing secrets"
      Documentation=https://developer.hashicorp.com/vault/docs
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=/etc/vault.d/proxy.hcl
      StartLimitIntervalSec=60
      StartLimitBurst=3

      [Service]
      Type=notify
      User=vault
      Group=vault
      ProtectSystem=full
      ProtectHome=read-only
      PrivateTmp=yes
      PrivateDevices=yes
      SecureBits=keep-caps
      AmbientCapabilities=CAP_IPC_LOCK
      CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
      NoNewPrivileges=yes
      ExecStart=/usr/bin/vault proxy -config=/etc/vault.d/proxy.hcl
      ExecReload=/bin/kill --signal HUP $MAINPID
      KillMode=process
      KillSignal=SIGINT
      Restart=on-failure
      RestartSec=5
      TimeoutStopSec=30
      LimitNOFILE=65536
      LimitMEMLOCK=infinity

      [Install]
      WantedBy=multi-user.target

runcmd:
  - yum install -y yum-utils
  - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  - yum -y install vault

  - chown root:vault /etc/vault.d/*
  - chmod 0640 /etc/vault.d/*

  - mkdir /run/vault
  - chown root:vault /run/vault
  - chmod 0775 /run/vault

  - systemctl enable vault-agent vault-proxy
