resource "aws_iam_role" "lambda" {
  name = "demo-lambda-${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "null_resource" "manual" {
  triggers = {
    requirements = sha256(file("./code/manual/requirements.txt"))
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r ./code/manual/requirements.txt -t ./code/manual"
  }
}

resource "null_resource" "extension" {
  triggers = {
    requirements = sha256(file("./code/extension/requirements.txt"))
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r ./code/extension/requirements.txt -t ./code/extension"
  }
}

data "archive_file" "manual" {
  depends_on = [null_resource.manual]

  type        = "zip"
  source_dir  = "./code/manual"
  output_path = "./code/archives/manual.zip"
}

data "archive_file" "extension" {
  depends_on = [null_resource.extension]

  type        = "zip"
  source_dir  = "./code/extension"
  output_path = "./code/archives/extension.zip"
}

resource "aws_lambda_function" "manual" {
  function_name    = "demo-lambda-manual-${var.name}"
  description      = "Demo app connecting to Vault from Lambda"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.manual.output_path
  source_code_hash = data.archive_file.manual.output_base64sha256
  handler          = "main.handler"
  runtime          = "python3.10"

  environment {
    variables = {
      VAULT_ADDR          = "http://${aws_instance.vault.public_ip}:8200",
      VAULT_AUTH_ROLE     = "demo-lambda",
      VAULT_AUTH_PROVIDER = "aws",
    }
  }
}

resource "aws_lambda_function" "extension" {
  function_name    = "demo-lambda-extension-${var.name}"
  description      = "Demo app using Vault AWS Lambda extension"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.extension.output_path
  source_code_hash = data.archive_file.extension.output_base64sha256
  handler          = "main.handler"
  runtime          = "python3.10"

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:634166935893:layer:vault-lambda-extension:19"
  ]

  environment {
    variables = {
      VAULT_ADDR          = "http://${aws_instance.vault.public_ip}:8200",
      VAULT_AUTH_ROLE     = "demo-lambda",
      VAULT_AUTH_PROVIDER = "aws",
      VAULT_SECRET_PATH   = "kv/data/demo/engineering/app01"
    }
  }
}
