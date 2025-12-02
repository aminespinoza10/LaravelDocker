# Azure Container Apps Deployment Guide

This guide explains how to deploy your Laravel application to Azure Container Apps using a single container (Nginx + PHP-FPM + Supervisor) connected to Azure MySQL.

## Architecture

- **Single Container**: Nginx and PHP-FPM run in one container managed by Supervisor
- **Database**: Azure Database for MySQL (soy-leon-developer.mysql.database.azure.com)
- **SSL**: Required for Azure MySQL connections
- **Port**: Container exposes port 80

## Prerequisites

1. Azure CLI installed and logged in
2. Azure subscription
3. Azure Container Registry (ACR) or Docker Hub account
4. Laravel application key generated

## Step 1: Prepare Your Environment

### Generate Application Key (if not already done)

```bash
# Option A: Locally (requires PHP + Composer deps installed on host)
php artisan key:generate --show

# Option B: Containerized (no local PHP needed)
docker build -t laravel-app:local .
docker run --rm -v "$PWD":/var/www/html laravel-app:local \
  php artisan key:generate --show
```

Copy this key - you'll need it for Azure Container Apps secrets.

### Create Azure MySQL Database

```bash
# If database doesn't exist, create it on your Azure MySQL instance
# You can do this via Azure Portal or MySQL client
mysql -h soy-leon-developer.mysql.database.azure.com \
  -u leonadmin \
  -p \
  -e "CREATE DATABASE IF NOT EXISTS laravel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## Step 2: Build and Push Docker Image

### Option A: Using Azure Container Registry (Recommended)

```bash
# Set variables
RESOURCE_GROUP=laravel-rg
LOCATION=eastus
ACR_NAME=laravelleonacr  # Must be globally unique, lowercase
IMAGE_TAG=${ACR_NAME}.azurecr.io/laravel-app:latest

# Create resource group (if needed)
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku Basic \
  --location $LOCATION

# Log in to ACR
az acr login --name $ACR_NAME

# Build and push image
docker build -t $IMAGE_TAG .
docker push $IMAGE_TAG
```

## Step 3: Create Azure Container Apps Environment

```bash
# Set variables (use values from Step 2)
ENV_NAME=laravel-env
APP_NAME=laravel-web

# Install/upgrade Container Apps extension
az extension add --name containerapp --upgrade

# Register providers
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

# Create Container Apps environment
az containerapp env create \
  --name $ENV_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

## Step 4: Deploy Container App

### Using Azure Container Registry

```bash
# Enable admin access for ACR (for easier authentication)
az acr update --name $ACR_NAME --admin-enabled true

# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

# Create Container App
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image ${ACR_NAME}.azurecr.io/laravel-app:latest \
  --target-port 80 \
  --ingress external \
  --registry-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --cpu 1.0 \
  --memory 2.0Gi \
  --min-replicas 1 \
  --max-replicas 3

# Get the application URL
FQDN=$(az containerapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn -o tsv)

echo "Application URL: https://$FQDN"
```

### Using Docker Hub

```bash
# Create Container App
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --image ${DOCKER_USERNAME}/laravel-app:latest \
  --target-port 80 \
  --ingress external \
  --registry-server docker.io \
  --registry-username $DOCKER_USERNAME \
  --registry-password $DOCKER_PASSWORD \
  --cpu 1.0 \
  --memory 2.0Gi \
  --min-replicas 1 \
  --max-replicas 3
```

## Step 5: Configure Secrets and Environment Variables

```bash
# Generate a strong app key if you haven't already
# Example: base64:randomstring32characterslong...

# Set secrets
az containerapp secret set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --secrets \
    app-key="base64:YOUR_GENERATED_APP_KEY_HERE" \
    db-password="eY3YcEH_cQN:AC}"

# Update environment variables
az containerapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars \
    APP_NAME=Laravel \
    APP_ENV=production \
    APP_DEBUG=false \
    APP_KEY=secretref:app-key \
    APP_URL=https://$FQDN \
    DB_CONNECTION=mysql \
    DB_HOST=soy-leon-developer.mysql.database.azure.com \
    DB_PORT=3306 \
    DB_DATABASE=laravel \
    DB_USERNAME=leonadmin \
    DB_PASSWORD=secretref:db-password \
    MYSQL_ATTR_SSL_CA=/etc/ssl/certs/ca-certificates.crt \
    MYSQL_ATTR_SSL_VERIFY_SERVER_CERT=true \
    LOG_CHANNEL=stack \
    LOG_LEVEL=error \
    SESSION_DRIVER=database \
    CACHE_STORE=database \
    QUEUE_CONNECTION=database
```

## Step 6: Run Database Migrations

You have two options to run migrations:

### Option A: Using Container Apps Jobs (Recommended)

```bash
# Create a one-time job to run migrations
az containerapp job create \
  --name "${APP_NAME}-migrate" \
  --resource-group $RESOURCE_GROUP \
  --environment $ENV_NAME \
  --trigger-type Manual \
  --image ${ACR_NAME}.azurecr.io/laravel-app:latest \
  --registry-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --command "/bin/bash" \
  --args "-c" "php artisan migrate --force" \
  --cpu 0.5 \
  --memory 1.0Gi \
  --secrets \
    app-key="base64:YOUR_GENERATED_APP_KEY_HERE" \
    db-password="eY3YcEH_cQN:AC}" \
  --env-vars \
    APP_KEY=secretref:app-key \
    DB_CONNECTION=mysql \
    DB_HOST=soy-leon-developer.mysql.database.azure.com \
    DB_PORT=3306 \
    DB_DATABASE=laravel \
    DB_USERNAME=leonadmin \
    DB_PASSWORD=secretref:db-password \
    MYSQL_ATTR_SSL_CA=/etc/ssl/certs/ca-certificates.crt

# Execute the migration job
az containerapp job start \
  --name "${APP_NAME}-migrate" \
  --resource-group $RESOURCE_GROUP
```

### Option B: Using Container Exec (Quick Method)

```bash
# Get a running replica name
REPLICA=$(az containerapp replica list \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query '[0].name' -o tsv)

# Run migrations
az containerapp exec \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --replica $REPLICA \
  --command "php artisan migrate --force"
```

## Step 7: Verify Deployment

```bash
# Check container logs
az containerapp logs show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --tail 50

# Test the application
curl https://$FQDN
```

## Optional: Set Up Persistent Storage (if needed)

If you need persistent storage for `storage/app` or logs:

```bash
# Create storage account
STORAGE_ACCOUNT=laravelstorage$RANDOM
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Create file share
az storage share create \
  --name laravel-storage \
  --account-name $STORAGE_ACCOUNT

# Get storage key
STORAGE_KEY=$(az storage account keys list \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query '[0].value' -o tsv)

# Add storage to Container Apps environment
az containerapp env storage set \
  --name $ENV_NAME \
  --resource-group $RESOURCE_GROUP \
  --storage-name laravel-storage \
  --azure-file-account-name $STORAGE_ACCOUNT \
  --azure-file-account-key $STORAGE_KEY \
  --azure-file-share-name laravel-storage \
  --access-mode ReadWrite

# Update container app to use the storage
az containerapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars FILESYSTEM_DISK=local \
  --volume-mount \
    name=laravel-storage \
    mount-path=/var/www/html/storage/app
```

## Updating the Application

```bash
# Rebuild and push new image
docker build -t $IMAGE_TAG .
docker push $IMAGE_TAG

# Update the container app (will trigger a new revision)
az containerapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $IMAGE_TAG

# Run migrations if needed
az containerapp exec \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --command "php artisan migrate --force"
```

## Troubleshooting

### View logs

```bash
az containerapp logs show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --tail 100 \
  --follow
```

### Check container status

```bash
az containerapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.runningStatus
```

### Test database connection

```bash
az containerapp exec \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --command "php artisan tinker --execute='DB::connection()->getPdo();'"
```

### Common Issues

1. **SSL Connection Error**: Ensure `MYSQL_ATTR_SSL_CA` and `MYSQL_ATTR_SSL_VERIFY_SERVER_CERT` are set
2. **Permission Denied**: Check that storage directories are writable (handled in Dockerfile)
3. **500 Error**: Check logs and ensure APP_KEY is set correctly
4. **Database Connection Failed**: Verify Azure MySQL firewall allows Azure services

## Cost Optimization

- Use scale-to-zero: `--min-replicas 0` (may add cold start delay)
- Use smaller instance: `--cpu 0.5 --memory 1.0Gi`
- Use Azure MySQL Basic tier for development
- Set up auto-scaling based on HTTP requests

## Security Checklist

- [ ] Never commit `.env.azure` with real credentials to git
- [ ] Use Container Apps secrets for sensitive values
- [ ] Enable Azure MySQL firewall rules
- [ ] Use SSL for database connections
- [ ] Set `APP_DEBUG=false` in production
- [ ] Rotate database passwords regularly
- [ ] Enable Azure Monitor for logging and alerting
- [ ] Set up Azure Key Vault for secret management (optional)

## Next Steps

1. Set up CI/CD pipeline (GitHub Actions, Azure DevOps)
2. Configure custom domain and SSL certificate
3. Set up Azure Monitor and Application Insights
4. Implement Redis cache (Azure Cache for Redis)
5. Configure email service (Azure Communication Services)
6. Set up automated backups for Azure MySQL
