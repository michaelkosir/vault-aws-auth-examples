import os
import requests


def handler(event, context):
    secret = os.getenv('VAULT_SECRET_PATH')
    r = requests.get(f"http://localhost:8200/v1/{secret}")

    # do stuff with secrets

    # return secrets for demo purposes
    return r.json()
