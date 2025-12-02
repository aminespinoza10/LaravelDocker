#!/bin/bash

LOCATION="mexicocentral"
RESOURCE_GROUP="laravel-rg"
#MYSQL_USERNAME="leonadmin"
#MYSQL_PASSWORD="tu password aquí"
#ACR_USERNAME="soyleonsandboxacr"
#ACR_KEY="tu clave aquí"

#az group create --name $RESOURCE_GROUP --location $LOCATION

#echo "✅ Resource group '$RESOURCE_GROUP' creado en la ubicación '$LOCATION'."

#az mysql flexible-server create \
#    --name soy-leon-developer \
#    --resource-group $RESOURCE_GROUP \
#    --location $LOCATION \
#    --admin-user $MYSQL_USERNAME \
#    --admin-password $MYSQL_PASSWORD

#echo "✅ Azure MySQL Flexible Server 'soy-leon-developer' creado."

#echo "📤 Importando base de datos inicial..."
#./import-azure-db.sh

#echo "✅ Base de datos importada."

#az acr create \
#    --resource-group $RESOURCE_GROUP \
#    --name leonregistry \
#    --sku Basic \
#    --admin-enabled true

#echo "✅ Azure Container Registry 'leonregistry' creado."
#echo "🔐 Obteniendo credenciales de ACR..."
#az acr credential show --name leonregistry --resource-group $RESOURCE_GROUP

echo "📦 Publicando imagen Docker en ACR..."
az acr login --name soyleonsandboxacr --username $ACR_USERNAME --password $ACR_KEY

docker tag laravel-app:local soyleonsandboxacr.azurecr.io/laravel-app:local
docker push soyleonsandboxacr.azurecr.io/laravel-app:local