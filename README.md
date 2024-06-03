# HashiCorp Vault AWS Auth Examples

## Overview
This repository contains various examples of AWS workloads leveraging HashiCorp Vault via the AWS Auth method.

- Lambda (Vault AWS Lambda Extension)
- Lambda (SDK/Library)
- EC2

## Multi Account
To allow Vault to authenticate IAM principals and EC2 instances in other accounts, Vault assumes AWS IAM Roles in other accounts. For each target AWS account ID, you configure the IAM Role for Vault to assume using the `auth/aws/config/sts/<account_id>` and Vault will use credentials from assuming that role to validate IAM principals and EC2 instances in the target account.

<p align="center">
  <img src="./img/aws-auth.drawio.svg">
</p>

## Usage

### Infrastructure Setup
```shell
git clone ...
cd ./vault-aws-auth-examples/tf
terraform apply
```

### Vault Setup
```shell
aws ssm start-session --target $(terraform output -raw demo_vault_id)
export VAULT_ADDR="http://localhost:8200"
vault operator init -format=json -key-shares=1 -key-threshold=1 | sudo tee /home/ssm-user/init.json
source /home/ssm-user/vault.env
vault operator unseal $VAULT_UNSEAL
exit
```

### AWS Auth Setup
```shell
vault secrets enable -version=2 kv

vault kv put kv/demo/engineering/app01 \
  hello=world \
  foo=bar uuid=$(uuidgen) \
  random=$RANDOM

vault kv put kv/demo/engineering/app02 \
  username=$(uuidgen) \
  password=$(base64 < /dev/urandom | head -c 64)

vault secrets enable transit

vault write transit/keys/app02 type=rsa-4096

vault auth enable aws

vault write -f auth/aws/config/client

vault policy write app01 - <<EOF
path "kv/data/demo/engineering/app01" {
  capabilities = ["read"]
}
EOF

vault policy write app02 - <<EOF
path "kv/data/demo/engineering/app02" {
  capabilities = ["read"]
}
path "transit/encrypt/app02" {
  capabilities = ["update"]
}
EOF

# Lambda max timeout is 900 seconds (15 minutes).
vault write auth/aws/role/demo-lambda \
  auth_type="iam" \
  bound_iam_principal_arn="arn:aws:iam::$AWS_ACCOUNT_ID:role/demo-lambda" \
  token_ttl="1000s" \
  token_max_ttl="1000s" \
  token_policies="app01"

# ec2, renew daily, reauth monthly
vault write auth/aws/role/demo-ec2 \
  auth_type="iam" \
  bound_iam_principal_arn="arn:aws:iam::$AWS_ACCOUNT_ID:role/demo-ec2" \
  token_ttl="24h" \
  token_max_ttl="30d" \
  token_policies="app02"
```

### AWS Lambda
```shell
# manual
aws lambda invoke --function-name demo-lambda-manual /dev/stdout | jq

# extension
aws lambda invoke --function-name demo-lambda-extension /dev/stdout | jq
```

### AWS EC2
```shell
aws ssm start-session --target $(terraform output -raw demo_ec2_id)
sudo cloud-init status --wait

sudo systemctl start vault-agent && sudo journalctl -u vault-agent
sudo ls -al /run/vault
sudo cat /run/vault/secret

sudo systemctl start vault-proxy && sudo journalctl -u vault-proxy
export VAULT_ADDR=http://localhost:8100
vault write transit/encrypt/app02 plaintext=$(echo "secret message" | base64 -w0)

exit
```
