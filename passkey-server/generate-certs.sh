#!/bin/bash

# Generate self-signed certificate for localhost
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/certs/localhost.key \
    -out nginx/certs/localhost.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

echo "Self-signed certificate generated for localhost"