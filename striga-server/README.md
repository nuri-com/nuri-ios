# Striga Sandbox Server

This is a simple Node.js backend for testing Striga API flows in sandbox mode.

## Setup
1. Copy .env.example to .env and add your Striga sandbox API key.
2. Run `npm install`.
3. Run `node server.js`.
4. Open http://localhost:3000 for the dashboard.

## Endpoints
- POST /create-user: Create a user (body: {email, phone, etc.})
- POST /send-phone-otp: Send phone OTP (body: {userId})
- ... (see server.js for more)

## Responses
Responses are documented in code comments and displayed in the dashboard as JSON.

## Docker (Later)
To dockerize, add Dockerfile and run docker build.
