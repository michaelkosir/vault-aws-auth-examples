output "demo_vault_id" {
  value = aws_instance.vault.id
}

output "demo_vault_public_ip" {
  value = aws_instance.vault.public_ip
}

output "demo_ec2_id" {
  value = aws_instance.demo_ec2.id
}

output "demo_ec2_public_ip" {
  value = aws_instance.demo_ec2.public_ip
}
