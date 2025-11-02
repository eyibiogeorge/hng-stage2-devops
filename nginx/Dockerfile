FROM nginx:stable-alpine

# Install envsubst for templating
RUN apk add --no-cache gettext

# Copy template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Default entrypoint
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
