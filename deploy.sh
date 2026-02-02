#!/bin/bash

# Production Deployment Helper Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if .env exists
if [ ! -f .env ]; then
    log_error ".env file not found"
    log_info "Please copy .env.example to .env and edit with production values"
    exit 1
fi

# Source .env
set -a
source .env
set +a

log_info "=== PWA Data Quality Production Deployment ==="

# 1. Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi
log_info "Docker version: $(docker --version)"

# 2. Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
fi
log_info "Docker Compose version: $(docker-compose --version)"

# 3. Validate .env variables
required_vars=(
    "AIRFLOW_UID"
    "AIRFLOW_DB_USER"
    "AIRFLOW_DB_PASSWORD"
    "MYSQL_ROOT_PASSWORD"
    "POSTGRES_STAGING_PASSWORD"
    "POSTGRES_QUALITY_PASSWORD"
)

log_info "Checking required environment variables..."
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Missing required variable: $var"
        exit 1
    fi
done
log_info "All required variables present"

# 4. Check file permissions
log_warn "Setting .env permissions to 600..."
chmod 600 .env

# 5. Validate docker-compose config
log_info "Validating docker-compose.yaml..."
docker-compose config > /dev/null || {
    log_error "docker-compose.yaml validation failed"
    exit 1
}

# 6. Check system resources
log_info "Checking system resources..."
AVAILABLE_MEMORY=$(free -m | awk 'NR==2{print $7}')
if [ "$AVAILABLE_MEMORY" -lt 8192 ]; then
    log_warn "Available memory: ${AVAILABLE_MEMORY}MB (recommended: 16GB+)"
fi

# 7. Clean up old containers/volumes
read -p "Do you want to clean up old Docker images and volumes? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cleaning up Docker resources..."
    docker system prune -a --volumes -f
fi

# 8. Start services
log_info "Starting Docker Compose services..."
docker-compose up -d

# 9. Wait for services to be ready
log_info "Waiting for services to be healthy..."
max_attempts=30
attempts=0

while [ $attempts -lt $max_attempts ]; do
    healthy=0
    total=0
    
    # Get service statuses
    services=$(docker-compose ps --services)
    total=$(echo "$services" | wc -l)
    
    healthy=$(docker-compose ps | grep -c "healthy\|running" || true)
    
    if [ "$healthy" -ge "$total" ]; then
        log_info "All services are healthy!"
        break
    fi
    
    log_info "Waiting for services... ($healthy/$total healthy) [$attempts/$max_attempts]"
    sleep 10
    ((attempts++))
done

# 10. Run health checks
log_info "Running health checks..."

# Check Airflow
if curl -s http://localhost:8085/health &> /dev/null; then
    log_info "✓ Airflow is healthy"
else
    log_warn "✗ Airflow health check failed"
fi

# Check OpenMetadata
if curl -s http://localhost:8585/api/v1/openmetadata/about &> /dev/null; then
    log_info "✓ OpenMetadata is healthy"
else
    log_warn "✗ OpenMetadata health check failed"
fi

# Check PostgreSQL
if docker-compose exec -T postgres pg_isready -h postgres -U airflow &> /dev/null; then
    log_info "✓ PostgreSQL is healthy"
else
    log_warn "✗ PostgreSQL health check failed"
fi

# Check MySQL
if docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &> /dev/null; then
    log_info "✓ MySQL is healthy"
else
    log_warn "✗ MySQL health check failed"
fi

# 11. Create backup directory
log_info "Setting up backup directory..."
mkdir -p ./backups
chmod 755 ./backups

# 12. Display access information
log_info ""
log_info "=== Deployment Complete ==="
log_info "Access your services at:"
log_info "  Airflow UI:    http://localhost:8085"
log_info "  OpenMetadata:  http://localhost:8585"
log_info "  Postgres:      localhost:5432"
log_info "  MySQL:         localhost:3307"
log_info ""
log_info "Next steps:"
log_info "  1. Verify services are healthy: docker-compose ps"
log_info "  2. Check logs: docker-compose logs -f"
log_info "  3. Setup backup schedule"
log_info "  4. Configure monitoring & alerting"
log_info "  5. Setup HTTPS/SSL certificate"

log_info "Deployment finished!"
