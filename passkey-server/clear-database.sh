#!/bin/bash

echo "🗑️  Clearing Passkey Server Database..."
echo ""
echo "This will delete all users and passkeys from the database."
read -p "Are you sure? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Clear using the API endpoint
    curl -X DELETE -k https://localhost/api/clear-database | jq
    echo ""
    echo "✅ Database cleared successfully!"
else
    echo "❌ Cancelled"
fi