# Production Laravel Docker Image (Nginx + PHP-FPM + Supervisor)
FROM php:8.3-fpm

# Set working directory
WORKDIR /var/www/html

# Install system dependencies including Nginx and Supervisor
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libzip-dev \
    nginx \
    supervisor \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip xml \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy composer files first for dependency installation
COPY composer.json composer.lock ./

# Install PHP dependencies (without scripts as application files aren't copied yet)
RUN composer install --optimize-autoloader --no-dev --no-interaction --no-scripts --prefer-dist

# Copy the rest of the application
COPY . .

# Run composer scripts that were skipped earlier
RUN composer run-script post-autoload-dump --no-interaction || true

# Optimize autoloader
RUN composer dump-autoload --optimize

# Copy Nginx configuration
COPY docker/nginx/nginx.conf /etc/nginx/sites-available/default

# Copy Supervisor configuration
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories for Nginx
RUN mkdir -p /var/log/nginx /var/lib/nginx /run/nginx

# Set permissions for Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Expose port 80 for Nginx
EXPOSE 80

# Start Supervisor (which will manage both PHP-FPM and Nginx)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
