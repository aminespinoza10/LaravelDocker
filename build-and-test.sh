#!/bin/bash
# Local Docker build

set -e

echo "🐳 Creando imagen de Laravel(Nginx + PHP-FPM + Supervisor)..."
docker build -t laravel-app:local .

echo "✅ ¡Imagen completa!"
echo ""

if [ -z "$APP_KEY" ]; then
    echo "🔑 Generando Laravel APP_KEY..."
    APP_KEY=$(docker run --rm laravel-app:local php artisan key:generate --show)
    echo "Llave generada: $APP_KEY"
    echo ""
fi

DB_HOST="soy-leon-developer.mysql.database.azure.com"
DB_PORT="3306"
DB_DATABASE="laravel"
DB_USERNAME="leonadmin"
DB_PASSWORD="eY3YcEH_cQN:AC}"

echo "🚀 Iniciando contenedor en el puerto 8080..."
docker run -d --name laravel-test -p 8080:80 \
  -e APP_KEY="$APP_KEY" \
  -e APP_ENV=local \
  -e APP_DEBUG=true \
  -e DB_CONNECTION=mysql \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e DB_DATABASE="$DB_DATABASE" \
  -e DB_USERNAME="$DB_USERNAME" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e MYSQL_ATTR_SSL_CA=/etc/ssl/certs/ca-certificates.crt \
  -e MYSQL_ATTR_SSL_VERIFY_SERVER_CERT=true \
  laravel-app:local

echo "⏳ Esperando a que el contenedor inicie..."
sleep 5

echo "🔍 Verificando el estado del contenedor..."
docker ps | grep laravel-test || {
    echo "❌ El contenedor no pudo iniciar. Verificando logs..."
    docker logs laravel-test
    docker rm -f laravel-test 2>/dev/null || true
    exit 1
}

echo "📋 Registros del contenedor:"
docker logs laravel-test

echo ""
echo "🧪 Probando respuesta HTTP..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Prueba HTTP fallida. Verificando registros de Laravel..."
    docker exec laravel-test cat /var/www/html/storage/logs/laravel.log 2>&1 | tail -30
    echo ""
    echo "Para depurar, ejecuta:"
    echo "  docker exec -it laravel-test bash"
    echo "  docker logs -f laravel-test"
else
    echo ""
    echo "✅ ¡El contenedor se está ejecutando correctamente!"
    echo "🌐 Visita: http://localhost:8080"
    echo ""
    echo "📊 Probando conexión a Azure MySQL..."
    docker exec laravel-test php artisan tinker --execute="echo 'MySQL Version: ' . DB::connection()->getPdo()->getAttribute(PDO::ATTR_SERVER_VERSION);" 2>/dev/null && echo "✅ Conexión a la base de datos exitosa!" || echo "⚠️  Prueba de conexión a la base de datos fallida"
fi

echo ""
echo "Comandos útiles:"
echo "  Ver registros:   docker logs -f laravel-test"
echo "  Acceso a shell:  docker exec -it laravel-test bash"
echo "  Probar BD:       docker exec laravel-test php artisan migrate:status"
echo "  Detener contenedor:  docker stop laravel-test"
echo "  Eliminar:        docker rm -f laravel-test"
echo ""
echo "Para detener y eliminar el contenedor de prueba, ejecuta:"
echo "  docker rm -f laravel-test"
