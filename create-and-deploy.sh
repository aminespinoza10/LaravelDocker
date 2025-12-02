#!/bin/bash

LOCATION="mexicocentral"
RESOURCE_GROUP="laravel-rg"
MYSQL_USERNAME="leonadmin"
MYSQL_PASSWORD="tu password aquí"
ACR_USERNAME="soyleonsandboxacr"
ACR_KEY="tu clave aquí"

az group create --name $RESOURCE_GROUP --location $LOCATION

echo "✅ Resource group '$RESOURCE_GROUP' creado en la ubicación '$LOCATION'."

az mysql flexible-server create \
    --name soy-leon-developer \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --admin-user $MYSQL_USERNAME \
    --admin-password $MYSQL_PASSWORD

echo "✅ Azure MySQL Flexible Server 'soy-leon-developer' creado."

echo "📤 Importando base de datos inicial..."
./import-azure-db.sh

echo "✅ Base de datos importada."

az acr create \
    --resource-group $RESOURCE_GROUP \
    --name leonregistry \
    --sku Basic \
    --admin-enabled true

echo "✅ Azure Container Registry 'leonregistry' creado."
echo "🔐 Obteniendo credenciales de ACR..."
az acr credential show --name leonregistry --resource-group $RESOURCE_GROUP

echo "📦 Publicando imagen Docker en ACR..."
az acr login --name soyleonsandboxacr --username $ACR_USERNAME --password $ACR_KEY

docker tag laravel-app:local soyleonsandboxacr.azurecr.io/laravel-app:local
docker push soyleonsandboxacr.azurecr.io/laravel-app:local

echo "✅ Imagen Docker publicada en ACR."

echo "🚀 Desplegando en Azure Container Apps"
az containerapp env create \
    --name laravel-env \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION

az containerapp up \
    --name laravel-app \
    --resource-group $RESOURCE_GROUP \
    --environment laravel-env \
    --image soyleonsandboxacr.azurecr.io/laravel-app:local \
    --cpu 0.5 \
    --memory 1Gi \
    --port 80 \
    --registry-server soyleonsandboxacr.azurecr.io \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_KEY \
    --env-vars APP_ENV=production APP_DEBUG=false DB_CONNECTION=mysql DB_HOST=soy-leon-developer.mysql.database.azure.com DB_PORT=3306 DB_DATABASE=laravel DB_USERNAME=leonadmin DB_PASSWORD='tu password aquí' MYSQL_ATTR_SSL_CA=/etc/ssl/certs/ca-certificates.crt MYSQL_ATTR_SSL_VERIFY_SERVER_CERT=true