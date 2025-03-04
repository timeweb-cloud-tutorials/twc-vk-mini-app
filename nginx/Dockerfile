FROM nginx:alpine

# Install envsubst for environment variable substitution
RUN apk add --no-cache bash gettext

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
