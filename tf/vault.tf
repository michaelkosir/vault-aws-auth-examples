resource "aws_security_group" "vault" {
  name = "demo-vault-${var.name}"

  tags = {
    Name = "demo-vault-${var.name}"
  }

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "vault" {
  name = "demo-vault-${var.name}"

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

resource "aws_iam_instance_profile" "vault" {
  name = aws_iam_role.vault.name
  role = aws_iam_role.vault.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.vault.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# https://developer.hashicorp.com/vault/docs/auth/aws#recommended-vault-iam-policy
data "aws_iam_policy_document" "vault" {

  # `iam:GetUser` and `iam:GetRole` are used when using the iam auth method 
  # and binding to an IAM user or role principal to determine the AWS IAM 
  # Unique Identifiers or when using a wildcard on the bound ARN to resolve 
  # the full ARN of the user or role.
  statement {
    effect    = "Allow"
    actions   = ["iam:GetRole"] # "iam:GetUser"
    resources = ["*"]
  }

  # # The `sts:AssumeRole` stanza is necessary when you are using Cross Account Access. 
  # # The Resources specified should be a list of all the roles for which you have 
  # # configured cross-account access, and each of those roles should have this 
  # # IAM policy attached (except for the sts:AssumeRole statement).
  # statement {
  #   effect  = "Allow"
  #   actions = ["sts:AssumeRole"]
  #   resources = [
  #     "arn:aws:iam::<ACCOUNT>:role/<ROLE>"
  #   ]
  # }
}

resource "aws_iam_policy" "vault" {
  name        = aws_iam_role.vault.name
  description = "IAM Policy for AWS Auth Method within Vault"
  policy      = data.aws_iam_policy_document.vault.json
}

resource "aws_iam_role_policy_attachment" "vault" {
  role       = aws_iam_role.vault.name
  policy_arn = aws_iam_policy.vault.arn
}

resource "aws_instance" "vault" {
  instance_type               = "t3.small"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vault.id]

  ami                  = data.aws_ami.al2023.id
  iam_instance_profile = aws_iam_instance_profile.vault.name

  tags = {
    Name = "demo-vault-${var.name}"
  }

  user_data = <<-EOT
    #cloud-config
    runcmd:
      - yum install -y yum-utils
      - yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
      - yum -y install vault
      - sed -i 's|^ExecStart.*$|ExecStart=/usr/bin/vault server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200 -dev-no-store-token|' /lib/systemd/system/vault.service
      - systemctl daemon-reload
      - systemctl enable vault --now
  EOT
}
