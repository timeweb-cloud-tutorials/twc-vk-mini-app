FROM nginx:alpine

# Install envsubst for environment variable substitution and openssl for certificate generation
RUN apk add --no-cache bash gettext openssl

# Copy nginx config template
COPY nginx.conf /etc/nginx/nginx.conf.template

# Create directory for certbot verification
RUN mkdir -p /var/www/certbot

# Expose both HTTP and HTTPS ports
EXPOSE 80 443

# Copy startup script
COPY start.sh /
RUN chmod +x /start.sh

CMD ["/start.sh"]
