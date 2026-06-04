import openai
import httpx
import os

from dotenv import load_dotenv
import os

# Load .env from project root explicitly
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(BASE_DIR, ".env")

load_dotenv(dotenv_path=ENV_PATH)


# Constants (from env)
AUTH_URL = "https://api.uhg.com/oauth2/token"
SCOPE = "https://api.uhg.com/.default"
GRANT_TYPE = "client_credentials"

CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")

PROJECT_ID = os.getenv("PROJECT_ID")
AZURE_ENDPOINT = os.getenv("AZURE_ENDPOINT")
DEPLOYMENT_NAME = os.getenv("DEPLOYMENT_NAME")
API_VERSION = os.getenv("API_VERSION")


def get_access_token():
    
    if not CLIENT_ID or not CLIENT_SECRET:
        raise RuntimeError("CLIENT_ID and CLIENT_SECRET must be set in .env file")

    body = {
        "grant_type": GRANT_TYPE,
        "scope": SCOPE,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
    }

    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }

    with httpx.Client() as client:
        resp = client.post(AUTH_URL, headers=headers, data=body, timeout=60)
        resp.raise_for_status()
        return resp.json()["access_token"]


def get_client():
    access_token = get_access_token()

    client = openai.AzureOpenAI(
        azure_endpoint=AZURE_ENDPOINT,
        api_version=API_VERSION,
        azure_deployment=DEPLOYMENT_NAME,
        azure_ad_token=access_token,
        default_headers={
            "projectId": PROJECT_ID,
        },
    )

    return client


def call_llm(messages, temperature=0):
    """
    Generic function to call GPT model
    """
    client = get_client()

    response = client.chat.completions.create(
        model="gpt-4.1",
        messages=messages,
        temperature=temperature,
    )
    # Just to see the full response for debugging - can remove later
    print(response.model_dump_json(indent=2))
    
    return response.choices[0].message.content