#!/bin/bash

# Default domain if not provided
if [ -z "$DOMAIN_NAME" ]; then
  echo "DOMAIN_NAME environment variable not set, using default value: localhost"
  export DOMAIN_NAME=localhost
fi

echo "Configuring Nginx for domain: $DOMAIN_NAME"

# Process the Nginx config template
envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Check if SSL certificates exist, if not, use a self-signed certificate for initial setup
SSL_DIR="/etc/letsencrypt/live/${DOMAIN_NAME}"
if [ ! -d "$SSL_DIR" ]; then
  echo "SSL certificates not found for ${DOMAIN_NAME}, creating self-signed certificates for initial setup"
  
  # Create directory structure
  mkdir -p "$SSL_DIR"
  
  # Generate self-signed certificate
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${SSL_DIR}/privkey.pem" \
    -out "${SSL_DIR}/fullchain.pem" \
    -subj "/CN=${DOMAIN_NAME}" \
    -addext "subjectAltName=DNS:${DOMAIN_NAME}"
    
  echo "Self-signed certificates created. Replace with Let's Encrypt certificates when available."
fi

# Start Nginx
echo "Starting Nginx with configuration for ${DOMAIN_NAME}"
nginx -g "daemon off;"
