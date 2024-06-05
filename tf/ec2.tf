resource "aws_security_group" "demo_ec2" {
  name = "demo-ec2-${var.name}"

  tags = {
    Name = "demo-ec2-${var.name}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "demo_ec2" {
  name = "demo-ec2-${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "demo_ec2" {
  name = aws_iam_role.demo_ec2.name
  role = aws_iam_role.demo_ec2.name
}

resource "aws_iam_role_policy_attachment" "demo_ec2" {
  role       = aws_iam_role.demo_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "demo_ec2" {
  instance_type               = "t3.small"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.demo_ec2.id]

  ami                  = data.aws_ami.al2023.id
  iam_instance_profile = aws_iam_instance_profile.demo_ec2.name

  tags = {
    Name = "demo-ec2-${var.name}"
  }

  user_data = <<-EOT
    #cloud-config
    write_files:
      - path: /etc/vault.d/secret.ctmpl
        content: |
          This will appear above the rendered secrets.
          {{- with secret "kv/demo/engineering/app02" }}
          username={{ .Data.data.username }}
          password={{ .Data.data.password }}
          {{ end -}}
          This will appear below the rendered secrets.

      - path: /etc/vault.d/agent.hcl
        content: |
          vault {
            address = "http://${aws_instance.vault.public_ip}:8200"
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
          }

      - path: /etc/vault.d/proxy.hcl
        content: |
          vault {
            address = "http://${aws_instance.vault.public_ip}:8200"
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
  EOT
}
