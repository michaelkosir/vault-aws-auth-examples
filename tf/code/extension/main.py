import json


def handler(event, context):
    with open("/tmp/vault/secret.json") as fp:
        secrets = json.load(fp)

    # alternative (Recommended)
    # Make unauthenticated requests to the extension's
    # local proxy server at http://127.0.0.1:8200

    # do stuff with secrets

    # return secrets for demo purposes
    return secrets
