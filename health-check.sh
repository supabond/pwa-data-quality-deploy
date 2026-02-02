#!/bin/bash

# Health Check and Monitoring Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=== PWA Data Quality Health Check ==="
echo ""

# 1. Check Docker
echo "1. Docker Status:"
if docker info &> /dev/null; then
    log_ok "Docker daemon is running"
else
    log_error "Docker daemon is not running"
    exit 1
fi

# 2. Check Containers
echo ""
echo "2. Container Status:"
docker-compose ps

# 3. Check Services Health
echo ""
echo "3. Service Health Checks:"

# Airflow
if curl -s http://localhost:8085/health > /dev/null 2>&1; then
    log_ok "Airflow is running (http://localhost:8085)"
else
    log_error "Airflow is not responding"
fi

# OpenMetadata
if curl -s http://localhost:8585/api/v1/openmetadata/about > /dev/null 2>&1; then
    log_ok "OpenMetadata is running (http://localhost:8585)"
else
    log_error "OpenMetadata is not responding"
fi

# PostgreSQL
if docker-compose exec -T postgres pg_isready -h postgres -U airflow &> /dev/null; then
    log_ok "PostgreSQL is running"
else
    log_error "PostgreSQL is not responding"
fi

# MySQL
if docker-compose exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" &> /dev/null 2>&1; then
    log_ok "MySQL is running"
else
    log_error "MySQL is not responding"
fi

# Elasticsearch
if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
    health=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*' | cut -d'"' -f4)
    log_ok "Elasticsearch is running (Status: $health)"
else
    log_error "Elasticsearch is not responding"
fi

# 4. Check Disk Space
echo ""
echo "4. Disk Space:"
df -h | grep -E "Filesystem|/$|/var"

# 5. Check Memory Usage
echo ""
echo "5. Memory Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}"

# 6. Check CPU Usage
echo ""
echo "6. CPU Usage (last 10 seconds):"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}"

# 7. Check Database Connections
echo ""
echo "7. Database Connections:"

# PostgreSQL connections
pg_connections=$(docker-compose exec -T postgres psql -U airflow -d airflow -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null || echo "N/A")
echo "  PostgreSQL connections: $pg_connections"

# MySQL connections
mysql_connections=$(docker-compose exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}' || echo "N/A")
echo "  MySQL connections: $mysql_connections"

# 8. Check Logs for Errors
echo ""
echo "8. Recent Errors (last 20 lines):"
docker-compose logs --tail=20 | grep -i "error\|exception\|failed" || echo "  No recent errors found"

# 9. Check DAGs
echo ""
echo "9. Airflow DAGs:"
docker-compose exec -T airflow-webserver airflow dags list 2>/dev/null | tail -10 || echo "  Unable to fetch DAG list"

# 10. Check Volumes
echo ""
echo "10. Docker Volumes:"
docker volume ls | grep -E "airflow|postgres|mysql|elasticsearch" || echo "  No volumes found"

echo ""
echo "=== Health Check Complete ==="
