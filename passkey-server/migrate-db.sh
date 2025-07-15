#!/bin/bash

echo "🔄 Migrating database to support encrypted user data..."

# Add new columns if they don't exist
docker-compose exec postgres psql -U passkey_user -d passkey_db << EOF
-- Add email column if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Add encrypted_data column if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS encrypted_data JSONB;

-- Add updated_at column if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Show updated table structure
\d users
EOF

echo "✅ Migration complete!"