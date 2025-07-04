import os
import json
from flask import Flask, request
from jose import jwt

app = Flask(__name__)

@app.route('/')
def debug_headers():
    """Display all headers and environment variables for IAP debugging purpose"""
    
    # Get all headers
    headers = dict(request.headers)
    
    # Get IAP-specific headers
    iap_jwt = request.headers.get('X-Goog-IAP-JWT-Assertion')
    user_email = request.headers.get('X-Goog-Authenticated-User-Email')
    user_id = request.headers.get('X-Goog-Authenticated-User-ID')
    
    # Get IAP Client ID from environment
    iap_client_id = os.environ.get('IAP_CLIENT_ID')
    
    # Try to decode JWT without verification to see contents
    jwt_claims = None
    jwt_header = None
    if iap_jwt:
        try:
            jwt_header = jwt.get_unverified_header(iap_jwt)
            jwt_claims = jwt.get_unverified_claims(iap_jwt)
        except Exception as e:
            jwt_claims = f"Error decoding JWT: {str(e)}"
    
    # Get all environment variables
    env_vars = dict(os.environ)
    
    # Filter for IAP-related env vars
    iap_env_vars = {k: v for k, v in env_vars.items() if 'IAP' in k or 'CLIENT' in k or 'GOOGLE' in k}
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>IAP Authentication Info</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
            .header {{ background-color: #f5f5f5; }}
            .success {{ background-color: #d4edda; }}
            .warning {{ background-color: #fff3cd; }}
            .error {{ background-color: #f8d7da; }}
            pre {{ background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }}
            .highlight {{ background-color: #ffff99; padding: 2px 4px; }}
        </style>
    </head>
    <body>
        <h1>IAP Authentication Info</h1>
        
        <div class="section header">
            <h2>🔍 IAP Status</h2>
            <p><strong>IAP Client ID (env):</strong> <span class="highlight">{iap_client_id or 'Not set'}</span></p>
            <p><strong>JWT Present:</strong> <span class="highlight">{'Yes' if iap_jwt else 'No'}</span></p>
            <p><strong>User Email Header:</strong> <span class="highlight">{user_email or 'Not present'}</span></p>
            <p><strong>User ID Header:</strong> <span class="highlight">{user_id or 'Not present'}</span></p>
        </div>
        
        <div class="section {'success' if iap_jwt else 'warning'}">
            <h2>🔑 JWT Information</h2>
            {f'''
            <h3>JWT Header:</h3>
            <pre>{json.dumps(jwt_header, indent=2) if jwt_header else 'No JWT header'}</pre>
            
            <h3>JWT Claims:</h3>
            <pre>{json.dumps(jwt_claims, indent=2) if isinstance(jwt_claims, dict) else str(jwt_claims)}</pre>
            
            <h3>Raw JWT Token (first 100 chars):</h3>
            <pre>{iap_jwt[:100] + '...' if iap_jwt else 'No JWT token'}</pre>
            ''' if iap_jwt else '<p>No JWT token found in headers.</p>'}
        </div>
        
        <div class="section">
            <h2>📋 All Request Headers</h2>
            <pre>{json.dumps(headers, indent=2)}</pre>
        </div>
        
        <div class="section">
            <h2>🌍 IAP-Related Environment Variables</h2>
            <pre>{json.dumps(iap_env_vars, indent=2) if iap_env_vars else 'No IAP-related environment variables found.'}</pre>
        </div>
        
        <div class="section">
            <h2>📊 Request Information</h2>
            <p><strong>URL:</strong> {request.url}</p>
            <p><strong>Method:</strong> {request.method}</p>
            <p><strong>Remote Address:</strong> {request.remote_addr}</p>
            <p><strong>Host:</strong> {request.host}</p>
            <p><strong>User Agent:</strong> {request.headers.get('User-Agent', 'Not set')}</p>
        </div>
        
    </body>
    </html>
    """
    
    return html

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
