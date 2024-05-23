from os import getenv
import hvac


def handler(event, context):
    client = hvac.Client()

    client.auth.aws.iam_login(
        access_key=getenv("AWS_ACCESS_KEY_ID"),
        secret_key=getenv("AWS_SECRET_ACCESS_KEY"),
        session_token=getenv("AWS_SESSION_TOKEN"),
        role=getenv("VAULT_AUTH_ROLE"),
        mount_point=getenv("VAULT_AUTH_PROVIDER")
    )

    secrets = client.secrets.kv.v2.read_secret_version(
        mount_point="kv",
        path="demo/engineering/app01",
    )

    # do something with secrets

    # return secrets for demo purposes
    return secrets
