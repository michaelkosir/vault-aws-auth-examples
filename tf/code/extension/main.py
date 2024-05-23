import json


def handler(event, context):
    with open("/tmp/vault/secret.json") as fp:
        secrets = json.load(fp)

    # do stuff with secrets

    # return secrets for demo purposes
    return secrets
