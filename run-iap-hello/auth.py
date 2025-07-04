import os
import requests
import logging
from flask import request
from jose import jwt, JWTError
from jose.exceptions import JWTClaimsError, ExpiredSignatureError, JWKError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

KEYS = None     # Cached public keys for verification
AUDIENCE = None # Cached value requiring information from metadata server

# Google publishes the public keys needed to verify a JWT. Save them in KEYS.
def keys():
    global KEYS
    if KEYS is None:
        resp = requests.get('https://www.gstatic.com/iap/verify/public_key')
        KEYS = resp.json()
    return KEYS

# Returns the JWT "audience" that should be in the assertion for Cloud Run
def audience():
    global AUDIENCE
    if AUDIENCE is None:
        # Get from environment variable set by Terraform
        AUDIENCE = os.environ.get('IAP_CLIENT_ID')
        logger.info(f"IAP_CLIENT_ID from environment: {AUDIENCE}")

        if AUDIENCE is None:
            raise ValueError("IAP_CLIENT_ID environment variable not set")
    return AUDIENCE

# Return the authenticated user's email address and persistent user ID if
# available from Cloud Identity Aware Proxy (IAP). If IAP is not active, returns None.
#
# Raises an exception if IAP header exists, but JWT token is invalid, which
# would indicates bypass of IAP or inability to fetch KEYS.
def user():
    try:
        # Requests coming through IAP have special headers
        iap_jwt = request.headers.get('X-Goog-IAP-JWT-Assertion')
        logger.info(f"IAP JWT header present: {bool(iap_jwt)}")
        
        if not iap_jwt:
            logger.error("No IAP JWT found in request headers")
            logger.info(f"Available headers: {dict(request.headers)}")
            return None
        
        try:
            info = jwt.decode(
                iap_jwt,
                keys(),
                algorithms=['ES256'],
                audience=audience()
            )
    
            logger.info("JWT validation successful!")
            logger.info(f"Validated user: {info.get('email')}")
            
            return (
                info.get('email'), 
                info.get('sub'), 
                info.get('aud'), 
                info.get('iss'), 
                info.get('hd'), 
                info.get('google', {})
            )
        
        except JWTClaimsError as claims_error:
            logger.error(f"JWT Claims Error: {str(claims_error)}")
            return None
            
        except ExpiredSignatureError as exp_error:
            logger.error(f"JWT Expired: {str(exp_error)}")
            return None
            
        except JWKError as jwk_error:
            logger.error(f"JWT Key Error: {str(jwk_error)}")
            return None
            
        except JWTError as jwt_error:
            logger.error(f"General JWT Error: {str(jwt_error)}")
            logger.error(f"JWT Error type: {type(jwt_error)}")
            return None
    
    except Exception as e:
        logger.error(f"Unexpected error in user(): {str(e)}")
        logger.error(f"Error type: {type(e)}")
        logger.error(f"Request URL: {request.url}")
        logger.error(f"Request method: {request.method}")
        logger.error(f"Request remote address: {request.remote_addr}")
        return None
