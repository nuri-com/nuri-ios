# Nuri Passkey Server

A self-hostable WebAuthn passkey server for the Nuri iOS app. Built with Node.js, PostgreSQL, and Docker for easy deployment.

## Quick Start

1. Generate SSL certificates for local HTTPS:
   ```bash
   ./generate-certs.sh
   ```

2. Install dependencies (if running without Docker):
   ```bash
   npm install
   ```

3. Start with Docker Compose:
   ```bash
   docker-compose up
   ```

The server will be available at:
- HTTPS: https://localhost (via nginx)
- HTTP: http://localhost:3000 (direct)

## Configuration

Copy `.env.example` to `.env` and adjust settings:

```env
# Database
DATABASE_URL=postgresql://passkey_user:passkey_password@localhost:5432/passkey_db

# WebAuthn
RP_ID=localhost
RP_NAME=Nuri Passkey Server
ORIGIN=https://localhost
```

## API Endpoints

- `GET /generate-registration-options?username=USER` - Start passkey registration
- `POST /verify-registration` - Complete passkey registration
- `GET /generate-authentication-options` - Start passkey authentication
- `POST /verify-authentication` - Complete passkey authentication
- `GET /health` - Health check

## iOS App Integration

Update your iOS app to point to the local server:
- For simulator: Use `https://localhost`
- For device: Use your Mac's IP address with HTTPS

## Database

The server uses PostgreSQL to store:
- Users (username, user_id)
- Authenticators (credentials, public keys, counters)

Data persists in Docker volumes between restarts.

## Deployment

This server is designed to be easily self-hosted:

1. Clone the repository
2. Set environment variables for your domain
3. Deploy with Docker to any cloud provider
4. Update iOS app to use your server endpoint

## Security Notes

- Always use HTTPS in production
- The provided certificates are self-signed for local development only
- Configure proper certificates for production deployment
- Challenges are stored in memory - use Redis or sessions for production