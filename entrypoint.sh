#!/bin/sh

: "${RELEASE_ID:=unknown}"
envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
exec nginx -g 'daemon off;'