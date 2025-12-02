#!/bin/bash
# Import SQL file into Azure MySQL database

set -e

DB_HOST="${DB_HOST:-soy-leon-developer.mysql.database.azure.com}"
DB_USERNAME="${DB_USERNAME:-leonadmin}"
DB_PASSWORD="${DB_PASSWORD}"  # Set via: export DB_PASSWORD='your-password'
DB_NAME="${DB_NAME:-laravel}"
SQL_FILE="${SQL_FILE:-docs/propedeutico.sql}"

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Error: DB_PASSWORD environment variable not set."
    echo "   Set it with: export DB_PASSWORD='your-password'"
    exit 1
fi

echo "🗄️  Importing SQL file to Azure MySQL..."
echo "Host: $DB_HOST"
echo "Database: $DB_NAME"
echo "File: $SQL_FILE"
echo ""

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "❌ Error: SQL file not found: $SQL_FILE"
    exit 1
fi

# Option 1: Using Azure CLI (recommended)
echo "📤 Attempting import via Azure CLI..."
if command -v az &> /dev/null; then
    az mysql flexible-server execute \
      --name soy-leon-developer \
      --admin-user "$DB_USERNAME" \
      --admin-password "$DB_PASSWORD" \
      --database-name "$DB_NAME" \
      --file-path "$SQL_FILE" && {
        echo "✅ Import successful via Azure CLI!"
        exit 0
    } || {
        echo "⚠️  Azure CLI import failed, trying MySQL client..."
    }
else
    echo "⚠️  Azure CLI not found, trying MySQL client..."
fi

# Option 2: Using MySQL client
echo "📤 Attempting import via MySQL client..."
if command -v mysql &> /dev/null; then
    mysql -h "$DB_HOST" \
      -u "$DB_USERNAME" \
      -p"$DB_PASSWORD" \
      --ssl-mode=REQUIRED \
      "$DB_NAME" < "$SQL_FILE" && {
        echo "✅ Import successful via MySQL client!"
        exit 0
    } || {
        echo "❌ MySQL client import failed"
        exit 1
    }
else
    echo "⚠️  MySQL client not found, trying Docker..."
fi

# Option 3: Using Docker with MySQL image
echo "📤 Attempting import via Docker MySQL client..."
if command -v docker &> /dev/null; then
    docker run --rm -i \
      -v "$(pwd)/$SQL_FILE:/sql/import.sql" \
      mysql:8.0 \
      mysql -h "$DB_HOST" \
        -u "$DB_USERNAME" \
        -p"$DB_PASSWORD" \
        --ssl-mode=REQUIRED \
        "$DB_NAME" < /sql/import.sql && {
        echo "✅ Import successful via Docker!"
        exit 0
    } || {
        echo "❌ Docker import failed"
        exit 1
    }
else
    echo "❌ No available method to import. Install Azure CLI, MySQL client, or Docker."
    exit 1
fi
