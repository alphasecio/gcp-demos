# run-iap-auth

A simple Flask app to debug Google Cloud Identity-Aware Proxy (IAP) authentication headers and JWT tokens. It displays IAP headers, JWT claims, environment variables, and request info in a clean HTML page.

## Features

- Shows IAP JWT assertion header and decodes it (without verification)
- Displays authenticated user email and ID from IAP headers
- Lists IAP-related environment variables
- Prints all request headers and basic request info

## Setup

1. Clone the repo, and change directory to `run-iap-auth`.
2. Install dependencies: `pip install -r requirements.txt`.
3. Run the app `python main.py`.
