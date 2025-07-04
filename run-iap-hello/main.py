import logging
from auth import user
from flask import Flask, render_template, request

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Disable browser caching so changes in each step are always shown
@app.after_request
def set_response_headers(response):
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    return response

@app.route('/', methods=['GET'])
def say_hello():
    # Get IAP headers (these are set by Google Cloud IAP)
    user_email = request.headers.get('X-Goog-Authenticated-User-Email')
    user_id = request.headers.get('X-Goog-Authenticated-User-ID')
    serverless_auth = request.headers.get('X-Serverless-Authorization')
    iap_jwt = request.headers.get('X-Goog-IAP-JWT-Assertion')

    # Handle the case where user() returns None (no IAP)
    user_result = user()

    if user_result is None:
        # No IAP authentication - use default values
        verified_email = None
        verified_id = None
        verified_aud = None
        verified_iss = None
        verified_hd = None
        verified_goog = {}
        logger.info("Running without IAP authentication")
    else:
        # Unpack the tuple when we know it's not None
        verified_email, verified_id, verified_aud, verified_iss, verified_hd, verified_goog = user_result
        logger.info(f"IAP authentication successful for {verified_email}")

    page = render_template('index.html',
        email=user_email,
        id=user_id,
        serverless_auth=serverless_auth,
        iap_jwt=iap_jwt,
        verified_email=verified_email,
        verified_id=verified_id,
        verified_aud=verified_aud,
        verified_iss=verified_iss,
        verified_hd=verified_hd,
        verified_goog=verified_goog)
    return page
