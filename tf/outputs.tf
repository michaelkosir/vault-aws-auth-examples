output "demo_vault_id" {
  value = aws_instance.vault.id
}

output "vault_addr" {
  value = "http://${aws_instance.vault.public_ip}:8200"
}

output "vault_token" {
  value = random_uuid.this.result
}

output "demo_ec2_id" {
  value = aws_instance.demo_ec2.id
}

output "demo_ec2_public_ip" {
  value = aws_instance.demo_ec2.public_ip
}
