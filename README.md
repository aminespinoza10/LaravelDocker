# LaravelDocker

A Laravel application configured for Docker deployment.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/aminespinoza10/LaravelDocker.git
cd LaravelDocker
```

### 2. Set up environment variables

```bash
cp .env.example .env
```

Update the `.env` file with your database configuration:

```env
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=your_secure_password
```

> **Security Note**: Always use strong, unique passwords for your database credentials. Never use default passwords like 'secret' or 'password' in production environments.

### 3. Build and run with Docker Compose

```bash
docker compose up -d --build
```

### 4. Install dependencies and generate key

```bash
docker compose exec app composer install
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
```

### 5. Access the application

Open your browser and navigate to `http://localhost:8080`

## Docker Commands

### Start containers
```bash
docker compose up -d
```

### Stop containers
```bash
docker compose down
```

### View logs
```bash
docker compose logs -f
```

### Run artisan commands
```bash
docker compose exec app php artisan <command>
```

### Access container shell
```bash
docker compose exec app bash
```

## Production Deployment

For production deployment, you can build and run just the Dockerfile:

```bash
# Build the image
docker build -t laravel-app .

# Run the container
docker run -d -p 9000:9000 laravel-app
```

Note: For production, you'll need to:
- Set up a separate web server (nginx) to serve the application
- Configure a production database with strong credentials
- Set appropriate environment variables
- Use HTTPS/TLS for secure connections
- Generate a new application key using `php artisan key:generate`

## Project Structure

```
├── Dockerfile          # PHP-FPM container configuration
├── docker-compose.yml  # Multi-container orchestration
├── docker/
│   └── nginx/
│       └── nginx.conf  # Nginx web server configuration
├── app/                # Laravel application code
├── config/             # Laravel configuration files
├── database/           # Database migrations and seeds
├── public/             # Publicly accessible files
├── resources/          # Views, CSS, and JavaScript
├── routes/             # Application routes
├── storage/            # Application storage
└── tests/              # Application tests
```

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
