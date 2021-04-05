import requests


def lambda_handler(event, context):
    r = requests.get("https://google.com")
    return {
        "statusCode": r.status_code,
        "body": r.text
    }
