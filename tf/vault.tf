data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "vault" {
  instance_type               = "t3.small"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["sg-00e0cfca53a6915e2"]

  ami                  = data.aws_ami.al2023.id
  iam_instance_profile = aws_iam_instance_profile.vault.name
  user_data            = file("./config/vault-server.yml")

  tags = {
    Name = "demo-vault"
  }
}

resource "aws_iam_role" "vault" {
  name = "demo-vault"

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

  # # The ManageOwnAccessKeys stanza is necessary when you have configured Vault with 
  # # static credentials, and wish to rotate these credentials with the 
  # # Rotate Root Credentials API call.
  # statement {
  #   sid    = "ManageOwnAccessKeys"
  #   effect = "Allow"
  #   actions = [
  #     "iam:CreateAccessKey",
  #     "iam:DeleteAccessKey",
  #     "iam:GetAccessKeyLastUsed",
  #     "iam:GetUser",
  #     "iam:ListAccessKeys",
  #     "iam:UpdateAccessKey"
  #   ]
  #   resources = ["arn:aws:iam::*:user/<vault-user>"]
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
