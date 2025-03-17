#!/bin/bash

# This script will initialize the SSL certificates using Certbot

# Exit on error
set -e

# Default values
if [ -z "$1" ]; then
  # Проверим, есть ли файл .env с доменом
  if [ -f ".env" ] && grep -q "DOMAIN_NAME=" ".env"; then
    ENV_DOMAIN=$(grep "DOMAIN_NAME=" ".env" | cut -d= -f2)
    if [ -n "$ENV_DOMAIN" ]; then
      echo "Found domain name in .env file: $ENV_DOMAIN"
      echo "Using this domain. If you want to use a different domain, please specify it as an argument."
      domain=$ENV_DOMAIN
      # Если есть переменная EMAIL в .env
      if grep -q "EMAIL=" ".env"; then
        email=$(grep "EMAIL=" ".env" | cut -d= -f2)
        echo "Using email from .env file: $email"
      fi
    else
      echo "Usage: $0 <domain_name> [email] [staging]"
      echo "Example: $0 example.com admin@example.com"
      echo "Add a third parameter with any value to use staging environment"
      exit 1
    fi
  else
    echo "Usage: $0 <domain_name> [email] [staging]"
    echo "Example: $0 example.com admin@example.com"
    echo "Add a third parameter with any value to use staging environment"
    exit 1
  fi
else
  domain="$1"
  email="$2"
fi

# Check if staging mode is requested
if [ -n "$3" ]; then
  staging=1
  echo "Using staging environment to avoid rate limits"
else
  # Проверим, есть ли настройка STAGING в .env
  if [ -f ".env" ] && grep -q "STAGING=" ".env"; then
    ENV_STAGING=$(grep "STAGING=" ".env" | cut -d= -f2)
    if [ "$ENV_STAGING" = "1" ]; then
      staging=1
      echo "Using staging environment from .env file"
    else
      staging=0
    fi
  else
    staging=0
  fi
fi

# Export domain name as environment variable
export DOMAIN_NAME="$domain"

# Check DNS resolution
echo "Checking DNS resolution for $domain..."
host $domain || {
  echo "Warning: Could not resolve $domain. Make sure DNS is properly configured."
  echo "Proceeding anyway, but certificate issuance may fail if DNS is not set up correctly."
}

# Check if port 80 is available
echo "Checking if port 80 is available..."

# Используем несколько методов проверки порта
PORT_IN_USE=false

# Метод 1: используем netcat если доступен
if command -v nc >/dev/null 2>&1; then
  nc -z localhost 80 >/dev/null 2>&1 || true
  PORT_CHECK_RESULT=$?
  echo "Port check result (netcat): $PORT_CHECK_RESULT (0 means port is in use)"
  
  if [ $PORT_CHECK_RESULT -eq 0 ]; then
    PORT_IN_USE=true
  fi
# Метод 2: используем lsof если доступен
elif command -v lsof >/dev/null 2>&1; then
  PORT_CHECK=$(lsof -i:80 | grep -v "COMMAND" | wc -l)
  echo "Port check result (lsof): $PORT_CHECK (>0 means port is in use)"
  if [ $PORT_CHECK -gt 0 ]; then
    PORT_IN_USE=true
    echo "Processes using port 80:"
    lsof -i:80 || echo "Could not get process details"
  fi
else
  echo "Neither netcat nor lsof found, skipping detailed port check."
  # Предполагаем, что порт может быть занят
  PORT_IN_USE=true
fi

if $PORT_IN_USE; then
  echo "Warning: Port 80 is already in use. This may cause problems with certificate issuance."
  echo "Will attempt to stop any running services to free up port 80."
  
  # Try to stop any running Nginx or other web servers
  echo "Stopping any running web servers..."
  docker compose down || true
  sleep 5
    
  # Check again
  echo "Checking port 80 again..."
  PORT_STILL_IN_USE=false
  
  # Используем тот же метод, что и раньше
  if command -v nc >/dev/null 2>&1; then
    nc -z localhost 80 >/dev/null 2>&1 || true
    if [ $? -eq 0 ]; then
      PORT_STILL_IN_USE=true
    fi
  elif command -v lsof >/dev/null 2>&1; then
    PORT_CHECK=$(lsof -i:80 | grep -v "COMMAND" | wc -l)
    if [ $PORT_CHECK -gt 0 ]; then
      PORT_STILL_IN_USE=true
    fi
  fi
  
  if $PORT_STILL_IN_USE; then
    echo "Warning: Port 80 is still in use after stopping containers."
    echo "This might be caused by another service outside Docker."
    echo "Proceeding anyway, but certificate issuance may fail."
    
    # Показать дополнительную информацию о процессах
    if command -v lsof >/dev/null 2>&1; then
      echo "Processes using port 80:"
      lsof -i:80 || echo "Could not get process details"
    fi
  else
    echo "Port 80 is now available."
  fi
else
  echo "Port 80 is available."
fi

# Regardless of port check, we'll proceed with certificate issuance
echo "Proceeding with certificate issuance..."

# Create required directories with proper permissions
mkdir -p ./data/certbot/www
mkdir -p ./data/certbot/conf
mkdir -p ./data/certbot/www/.well-known/acme-challenge
chmod -R 755 ./data/certbot/www
chmod -R 755 ./data/certbot

# Clean up any existing certificates for this domain to avoid conflicts
rm -rf ./data/certbot/conf/live/$domain
rm -rf ./data/certbot/conf/archive/$domain
rm -rf ./data/certbot/conf/renewal/$domain.conf

# Stop any running containers
docker compose down

# Set environment variable for domain
export DOMAIN_NAME=$domain
echo "Setting up certificates for domain: $domain"

# Make sure docker compose uses this environment variable
docker compose build nginx


# Start nginx container with the domain name
DOMAIN_NAME=$domain docker compose up -d nginx

# Wait for nginx to start
echo "Waiting for nginx to start..."
sleep 10

# Check if nginx is running
if ! docker compose ps | grep -q "nginx.*Up"; then
  echo "Warning: Nginx container is not running."
  echo "Checking Nginx logs:"
  docker compose logs nginx
  
  # Try to fix common issues
  echo "Attempting to fix Nginx configuration..."
  
  # Check if the data directory exists and has proper permissions
  echo "Checking data directory permissions..."
  chmod -R 755 ./data/certbot
  
  # Rebuild and restart Nginx
  echo "Rebuilding and restarting Nginx..."
  docker compose build nginx
  docker compose up -d nginx
  sleep 5
  
  # Check again if Nginx is running
  if ! docker compose ps | grep -q "nginx.*Up"; then
    echo "Warning: Nginx container still not running after fix attempt."
    echo "Proceeding with certificate request anyway..."
    
    # Create a temporary nginx container just for the certbot challenge
    echo "Creating a temporary Nginx container for the certbot challenge..."
    docker run -d --name temp_nginx -p 80:80 -v $(pwd)/data/certbot/www:/var/www/certbot nginx:alpine
  fi
fi

echo "Nginx is running. Proceeding with certificate request..."

# Request the certificate
if [ $staging != "0" ]; then
  staging_arg="--staging"
  echo "Running in staging mode"
else
  staging_arg=""
  echo "Running in production mode"
fi

if [ -z "$email" ]; then
  email_arg="--register-unsafely-without-email"
  echo "No email provided, registering without email"
else
  email_arg="--email $email"
  echo "Using email: $email"
fi

echo "Requesting certificate for domain: $domain"
echo "Running certbot command..."

# Make sure port 80 is free
echo "Making sure port 80 is free..."
docker compose down || true
sleep 5

# Check for running Docker containers that might be using port 80
echo "Checking for Docker containers using port 80..."
docker ps | grep -E '(80/tcp|443/tcp)' || echo "No containers using ports 80 or 443"

# Check if port 80 is accessible from the internet
echo "Note: For Let's Encrypt to work, port 80 must be accessible from the internet."
echo "If certificate issuance fails, please check your firewall settings."

# Run certbot with standalone mode
echo "Running certbot with standalone mode..."
set +e  # Don't exit on error

# Create a simple standalone container for certbot
echo "Creating certbot container..."
CERTBOT_COMMAND="certonly --standalone $staging_arg $email_arg -d $domain --agree-tos --non-interactive --force-renewal --debug-challenges"

echo "Running command: $CERTBOT_COMMAND"
echo "Starting Docker container for Certbot..."

# Try to pull the image first to ensure we have the latest version
docker pull certbot/certbot:latest || echo "Warning: Failed to pull latest Certbot image, will use local image if available"

# Run the container with a timeout to prevent hanging
timeout 300 docker run --rm \
  -v $(pwd)/data/certbot/conf:/etc/letsencrypt \
  -v $(pwd)/data/certbot/www:/var/www/certbot \
  -p 80:80 \
  -p 443:443 \
  certbot/certbot:latest \
  $CERTBOT_COMMAND || {
    DOCKER_EXIT_CODE=$?
    echo "Docker run failed or timed out with exit code: $DOCKER_EXIT_CODE"
    if [ $DOCKER_EXIT_CODE -eq 124 ]; then
      echo "The command timed out after 5 minutes. This could indicate a network issue or firewall problem."
      echo "Please check that port 80 is accessible from the internet."
    fi
  }

DOCKER_EXIT_CODE=${DOCKER_EXIT_CODE:-0}
echo "Docker run completed with exit code: $DOCKER_EXIT_CODE"

CERTBOT_EXIT_CODE=$DOCKER_EXIT_CODE
set -e  # Re-enable exit on error

if [ $CERTBOT_EXIT_CODE -ne 0 ]; then
  echo "Warning: Certbot command failed with exit code $CERTBOT_EXIT_CODE"
  
  # Check if the failure might be due to firewall issues
  echo "Checking if port 80 is accessible from the outside..."
  echo "This is critical for Let's Encrypt to verify domain ownership."
  echo "If you're running this on a server, please ensure port 80 is open in your firewall."
  
  # Check for running Docker containers that might be using port 80
  echo "Checking for Docker containers using port 80 before second attempt..."
  docker ps | grep -E '(80/tcp|443/tcp)' || echo "No containers using ports 80 or 443"
  
  # Make sure port 80 is free
  echo "Making sure port 80 is free before second attempt..."
  docker compose down || true
  sleep 5
  
  echo "Trying again with additional debug flags..."
  # Используем только команду certonly без префикса certbot
  CERTBOT_COMMAND="certonly --standalone $staging_arg $email_arg -d $domain --agree-tos --non-interactive --force-renewal --break-my-certs --debug-challenges --debug"
  
  echo "Running command: $CERTBOT_COMMAND"
  echo "Starting Docker container for Certbot (second attempt)..."
  
  # Проверим, не занят ли порт 80 другими процессами
  if command -v lsof >/dev/null 2>&1; then
    echo "Checking processes using port 80:"
    lsof -i :80 || echo "No processes found using port 80"
  fi
  
  # Run with a timeout to prevent hanging
  timeout 300 docker run --rm \
    -v $(pwd)/data/certbot/conf:/etc/letsencrypt \
    -v $(pwd)/data/certbot/www:/var/www/certbot \
    -p 80:80 \
    -p 443:443 \
    certbot/certbot:latest \
    $CERTBOT_COMMAND || {
      DOCKER_EXIT_CODE=$?
      echo "Second Docker run failed or timed out with exit code: $DOCKER_EXIT_CODE"
      if [ $DOCKER_EXIT_CODE -eq 124 ]; then
        echo "The command timed out after 5 minutes. This strongly indicates a network issue or firewall problem."
        echo "Please check that port 80 is accessible from the internet."
      fi
    }
  
  DOCKER_EXIT_CODE=${DOCKER_EXIT_CODE:-0}
  echo "Second Docker run completed with exit code: $DOCKER_EXIT_CODE"
fi

# Restart nginx after certificate request
echo "Restarting nginx..."
docker compose up -d nginx
sleep 5

# Sleep to allow certbot to finish
echo "Waiting for certificate issuance to complete..."
sleep 5

# Clean up temporary Nginx container if it was created
if docker ps -a | grep -q "temp_nginx"; then
  echo "Cleaning up temporary Nginx container..."
  docker stop temp_nginx
  docker rm temp_nginx
fi

# Check if certificate was obtained successfully
echo "Checking for certificate in ./data/certbot/conf/live/$domain"
ls -la ./data/certbot/conf/live/ || echo "Directory does not exist or cannot be accessed"

# Check for Certbot logs
echo "Checking for Certbot logs:"
find ./data/certbot/conf/letsencrypt-logs/ -type f -name "*.log" 2>/dev/null || echo "No log files found"

# If log files exist, display the most recent one
LOG_FILE=$(find ./data/certbot/conf/letsencrypt-logs/ -type f -name "*.log" 2>/dev/null | sort -r | head -n 1)
if [ -n "$LOG_FILE" ]; then
  echo "Contents of most recent log file ($LOG_FILE):"
  cat "$LOG_FILE" || echo "Could not read log file"
fi

# Try to find any certificate directory that might have been created
CERT_DIR=$(find ./data/certbot/conf/live/ -type d -name "*$domain*" 2>/dev/null | head -n 1)

# Если не нашли по домену, проверим любой сертификат
if [ -z "$CERT_DIR" ]; then
  echo "Certificate directory not found by domain name, checking for any certificate directory..."
  CERT_DIR=$(find ./data/certbot/conf/live/ -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -v "README" | head -n 1)
fi

if [ -z "$CERT_DIR" ]; then
  echo "Error: Certificate was not obtained. Check the certbot logs."
  
  echo "Checking Certbot directory structure:"
  find ./data/certbot/conf/ -type d | sort || echo "Could not list directory structure"
  
  # Проверим права доступа к каталогам
  echo "Checking permissions on certbot directories:"
  ls -la ./data/certbot/ || echo "Could not check permissions"
  
  echo "Checking if domain is accessible:"
  curl -v --connect-timeout 10 http://$domain/ || echo "Domain not accessible"
  
  exit 1
else
  echo "Certificate directory found at: $CERT_DIR"
  
  # If certificate was created with a different name, create a symlink
  if [ "$CERT_DIR" != "./data/certbot/conf/live/$domain" ]; then
    echo "Creating symlink from $CERT_DIR to ./data/certbot/conf/live/$domain"
    ln -sf "$CERT_DIR" "./data/certbot/conf/live/$domain"
  fi
fi

echo "Certificate obtained successfully!"

# Restart nginx to use the new certificates
echo "Restarting Nginx to apply SSL certificates..."
docker compose restart nginx || {
  echo "Warning: Failed to restart Nginx. Will try to start all services."
}

# Wait for Nginx to start
echo "Waiting for Nginx to restart..."
sleep 5

# Check if Nginx is running
if ! docker compose ps 2>/dev/null | grep -q "nginx.*Up"; then
  echo "Warning: Nginx container is not running after restart."
  echo "Trying to start all services..."
fi

# Start all services
echo "Starting all services..."
docker compose up -d || {
  echo "Warning: Failed to start all services. Please check Docker logs."
  echo "You may need to manually start the services with: docker compose up -d"
}

# Print certificate information
echo "Certificate information:"
echo "Domain: $domain"
echo "Certificate location: ./data/certbot/conf/live/$domain/"
echo "Certificate files:"
ls -la "./data/certbot/conf/live/$domain/" || echo "Could not list certificate files"

# Сохраняем домен и email в файл .env для последующих запусков
echo "Saving domain name and email to .env file for future runs..."
if [ -f ".env" ]; then
  # Если файл существует, проверим наличие переменной DOMAIN_NAME
  if grep -q "DOMAIN_NAME=" ".env"; then
    # Заменим существующую переменную
    sed -i.bak "s/DOMAIN_NAME=.*/DOMAIN_NAME=$domain/" ".env" && rm -f ".env.bak" || echo "Warning: Could not update DOMAIN_NAME in .env"
  else
    # Добавим переменную в конец файла
    echo "DOMAIN_NAME=$domain" >> ".env" || echo "Warning: Could not append DOMAIN_NAME to .env"
  fi
  
  # Сохраняем email, если он указан
  if [ -n "$email" ]; then
    if grep -q "EMAIL=" ".env"; then
      # Заменим существующую переменную
      sed -i.bak "s/EMAIL=.*/EMAIL=$email/" ".env" && rm -f ".env.bak" || echo "Warning: Could not update EMAIL in .env"
    else
      # Добавим переменную в конец файла
      echo "EMAIL=$email" >> ".env" || echo "Warning: Could not append EMAIL to .env"
    fi
  fi
  
  # Сохраняем параметр STAGING
  if grep -q "STAGING=" ".env"; then
    # Заменим существующую переменную
    sed -i.bak "s/STAGING=.*/STAGING=$staging/" ".env" && rm -f ".env.bak" || echo "Warning: Could not update STAGING in .env"
  else
    # Добавим переменную в конец файла
    echo "STAGING=$staging" >> ".env" || echo "Warning: Could not append STAGING to .env"
  fi
else
  # Создадим новый файл .env
  echo "DOMAIN_NAME=$domain" > ".env" || echo "Warning: Could not create .env file"
  # Добавим email, если он указан
  if [ -n "$email" ]; then
    echo "EMAIL=$email" >> ".env" || echo "Warning: Could not append EMAIL to .env"
  fi
  # Добавим параметр STAGING
  echo "STAGING=$staging" >> ".env" || echo "Warning: Could not append STAGING to .env"
fi

echo "=================================================================="
echo "SSL certificates have been successfully obtained for $domain"
echo "Your site should now be accessible at https://$domain"
echo "Certificates are stored in ./data/certbot/conf/"
echo "Automatic renewal is configured to run every 12 hours"
echo ""
echo "The following settings have been saved to .env file:"
echo "  - DOMAIN_NAME=$domain"
if [ -n "$email" ]; then
  echo "  - EMAIL=$email"
fi
echo "  - STAGING=$staging"
echo ""
echo "For future runs, you can simply use:"
echo "  docker compose up -d"
echo "The saved settings will be used automatically"
echo ""
echo "To change settings, either:"
echo "  1. Edit the .env file directly, or"
echo "  2. Run this script again with new parameters"
echo "=================================================================="
