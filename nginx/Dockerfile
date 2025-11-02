FROM nginx:stable-alpine

RUN apk add --no-cache gettext

# Copy the nginx config template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Ensure default.conf exists so Docker mount works
RUN mkdir -p /etc/nginx/conf.d && touch /etc/nginx/conf.d/default.conf

# Copy startup script
COPY docker-entrypoint.sh /docker-entrypoint.d/50-render-nginx-template.sh
RUN chmod +x /docker-entrypoint.d/50-render-nginx-template.sh