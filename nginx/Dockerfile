FROM nginx:stable-alpine

# Install envsubst for templating
RUN apk add --no-cache gettext

# Copy config template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Ensure target directory and placeholder config exist
RUN mkdir -p /etc/nginx/conf.d && touch /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]