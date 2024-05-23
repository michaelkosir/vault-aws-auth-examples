resource "aws_iam_role" "demo_ec2" {
  name = "demo-ec2"

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
  vpc_security_group_ids      = ["sg-00e0cfca53a6915e2"]

  ami                  = data.aws_ami.al2023.id
  iam_instance_profile = aws_iam_instance_profile.demo_ec2.name

  user_data = templatefile("./config/vault-agent-proxy.yml.tpl", {
    vault_address = "http://${aws_instance.vault.public_ip}:8200"
  })

  tags = {
    Name = "demo-ec2"
  }
}
