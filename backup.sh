#!/bin/bash

# Backup Script for Production Data

set -e

# Configuration
BACKUP_DIR="./backups"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Starting backup at $DATE"

# 1. Backup Airflow PostgreSQL
log_info "Backing up Airflow database..."
docker-compose exec -T postgres pg_dump \
    -U airflow \
    -d airflow \
    -F custom \
    > "$BACKUP_DIR/airflow_${DATE}.dump" || {
    log_error "Failed to backup Airflow database"
    exit 1
}

# 2. Backup Staging PostgreSQL
log_info "Backing up Staging database..."
docker-compose exec -T pg_staging_data pg_dump \
    -U postgres \
    -d "pwa-staging-data" \
    -F custom \
    > "$BACKUP_DIR/staging_${DATE}.dump" || {
    log_error "Failed to backup Staging database"
    exit 1
}

# 3. Backup Quality PostgreSQL
log_info "Backing up Quality database..."
docker-compose exec -T pg_quality_data pg_dump \
    -U postgres \
    -d "pwa-quality-data" \
    -F custom \
    > "$BACKUP_DIR/quality_${DATE}.dump" || {
    log_error "Failed to backup Quality database"
    exit 1
}

# 4. Backup MySQL (OpenMetadata)
log_info "Backing up MySQL database..."
docker-compose exec -T mysql mysqldump \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --all-databases \
    --single-transaction \
    > "$BACKUP_DIR/mysql_${DATE}.sql" || {
    log_error "Failed to backup MySQL database"
    exit 1
}

# 5. Backup Elasticsearch indices
log_info "Backing up Elasticsearch..."
docker-compose exec -T elasticsearch curl -s -X GET \
    "localhost:9200/_cat/indices?format=json" \
    > "$BACKUP_DIR/es_indices_${DATE}.json" || {
    log_error "Failed to backup Elasticsearch indices"
    exit 1
}

# 6. Compress backups
log_info "Compressing backups..."
cd "$BACKUP_DIR"
tar -czf "backup_${DATE}.tar.gz" \
    "airflow_${DATE}.dump" \
    "staging_${DATE}.dump" \
    "quality_${DATE}.dump" \
    "mysql_${DATE}.sql" \
    "es_indices_${DATE}.json" || {
    log_error "Failed to compress backups"
    exit 1
}

# 7. Remove individual backup files
rm -f "airflow_${DATE}.dump" \
      "staging_${DATE}.dump" \
      "quality_${DATE}.dump" \
      "mysql_${DATE}.sql" \
      "es_indices_${DATE}.json"

# 8. Cleanup old backups
log_info "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

# 9. Calculate backup size
backup_size=$(du -sh "$BACKUP_DIR/backup_${DATE}.tar.gz" | cut -f1)

log_info "Backup complete!"
log_info "Backup file: $BACKUP_DIR/backup_${DATE}.tar.gz ($backup_size)"
log_info "Backups older than $RETENTION_DAYS days have been removed"

# Optional: Upload to cloud storage
# aws s3 cp "$BACKUP_DIR/backup_${DATE}.tar.gz" s3://my-backup-bucket/
