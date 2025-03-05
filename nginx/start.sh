#!/bin/bash

# Exit on error
set -e

# Default domain if not provided
if [ -z "$DOMAIN_NAME" ]; then
  echo "DOMAIN_NAME environment variable not set, using default value: localhost"
  export DOMAIN_NAME=localhost
fi

echo "Configuring Nginx for domain: $DOMAIN_NAME"

# Create directory for custom configurations
mkdir -p /etc/nginx/conf.d

# Remove default configuration
rm -f /etc/nginx/conf.d/default.conf

# Check if SSL certificates exist
SSL_DIR="/etc/letsencrypt/live/${DOMAIN_NAME}"
if [ -f "${SSL_DIR}/fullchain.pem" ] && [ -f "${SSL_DIR}/privkey.pem" ]; then
  echo "SSL certificates found for ${DOMAIN_NAME}. Enabling HTTPS."
  
  # Create base nginx.conf
  cat > /etc/nginx/nginx.conf << EOF
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Include all configuration files from conf.d directory
    include /etc/nginx/conf.d/*.conf;
}
EOF

  # Create SSL configuration
  cat > /etc/nginx/conf.d/ssl.conf << EOF
server {
    listen 443 ssl;
    server_name ${DOMAIN_NAME};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    
    # API proxy
    location /api/ {
        proxy_pass http://backend:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Frontend proxy
    location / {
        proxy_pass http://frontend:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  # Create HTTP to HTTPS redirect
  cat > /etc/nginx/conf.d/http_redirect.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    
    # Certbot challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

else
  echo "SSL certificates not found for ${DOMAIN_NAME}. Running with HTTP only."
  
  # Create base nginx.conf with HTTP configuration
  cat > /etc/nginx/nginx.conf << EOF
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # HTTP server for handling Certbot challenges and serving content
    server {
        listen 80;
        server_name ${DOMAIN_NAME};
        
        # Certbot challenge location
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # API requests to backend
        location /api/ {
            proxy_pass http://backend:8000/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Frontend requests
        location / {
            proxy_pass http://frontend:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
fi

# Start Nginx
echo "Starting Nginx for ${DOMAIN_NAME}"
exec nginx -g "daemon off;"
