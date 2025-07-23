# run-iap-hello

A Flask app that verifies Google Cloud IAP authentication and displays user info in a friendly web page.

## Features

- Reads IAP authentication headers and JWT assertion
- Verifies JWT tokens against Google's public keys at runtime
- Shows authentication status, user email, and JWT claims in the browser
- Uses a clean HTML template for display
- Logs verification steps and errors

## Setup

1. Clone the repo, and change directory to `run-iap-hello`.
2. Install dependencies: `pip install -r requirements.txt`.
3. Run the app: `python main.py`.

