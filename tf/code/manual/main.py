import hvac
import os


def handler(event, context):
    client = hvac.Client()

    client.auth.aws.iam_login(
        role=os.environ['VAULT_AUTH_ROLE'],
        mount_point=os.environ['VAULT_AUTH_PROVIDER']
    )

    secrets = client.secrets.kv.v2.read_secret_version(
        mount_point="kv",
        path="demo/engineering/app01",
    )

    # do something with secrets

    # return secrets for demo purposes
    return secrets
