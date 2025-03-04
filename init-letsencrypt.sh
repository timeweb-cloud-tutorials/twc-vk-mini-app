#!/bin/bash

# This script will initialize the SSL certificates using Certbot

# Exit on error
set -e

# Default values
if [ -z "$1" ]; then
  echo "Usage: $0 <domain_name> [email]"
  echo "Example: $0 example.com admin@example.com"
  exit 1
fi

domain="$1"
email="$2"
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

# Create required directories
mkdir -p ./data/certbot/conf/live/$domain
mkdir -p ./data/certbot/www

# Stop any running containers
docker-compose down

# Set environment variable for domain
export DOMAIN_NAME=$domain

# Start nginx container
docker-compose up -d nginx

# Wait for nginx to start
echo "Waiting for nginx to start..."
sleep 5

# Request the certificate
if [ $staging != "0" ]; then
  staging_arg="--staging"
fi

if [ -z "$email" ]; then
  email_arg="--register-unsafely-without-email"
else
  email_arg="--email $email"
fi

docker-compose run --rm certbot certonly --webroot -w /var/www/certbot \
  $staging_arg \
  $email_arg \
  -d $domain \
  --agree-tos \
  --force-renewal

# Reload nginx to use the new certificates
docker-compose exec nginx nginx -s reload

# Start all services
docker-compose up -d

echo "SSL certificates have been successfully obtained for $domain"
echo "Certificates are stored in ./data/certbot/conf/"
echo "Automatic renewal is configured to run every 12 hours"
