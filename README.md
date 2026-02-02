# PWA Data Quality Production Setup

Complete production deployment guide สำหรับ Apache Airflow + OpenMetadata + Data Warehouse stack

## Quick Start

```bash
# 1. Clone repository
git clone <repo-url>
cd pwa-data-quality-deploy

# 2. Setup environment
cp .env.example .env
# Edit .env with production values

# 3. Generate FERNET_KEY
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Add the output to AIRFLOW__CORE__FERNET_KEY in .env

# 4. Deploy
bash deploy.sh
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Production Server               │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐   │
│  │   Nginx Reverse Proxy (SSL)      │   │
│  │   :80 → :8085, :8585            │   │
│  └──────────────────────────────────┘   │
│           │                    │         │
│  ┌────────▼────┐     ┌────────▼──────┐  │
│  │   Airflow   │     │  OpenMetadata │  │
│  │  :8085      │     │   :8585       │  │
│  └────────┬────┘     └────────┬──────┘  │
│           │                    │         │
│  ┌────────▼─────────────────────▼────┐   │
│  │    Application Network            │   │
│  │  (127.0.0.1 - localhost only)     │   │
│  └────────┬────────────────────────┬──┘   │
│           │                        │       │
│  ┌────────▼─────┐  ┌──────────────▼──┐   │
│  │ PostgreSQL   │  │     MySQL       │   │
│  │ + Staging    │  │  (OpenMetadata) │   │
│  │ + Quality    │  │                 │   │
│  └──────────────┘  └─────────────────┘   │
│           │                        │       │
│  ┌────────▼─────────────────────────▼──┐  │
│  │    Elasticsearch                    │  │
│  │    (OpenMetadata indices)           │  │
│  └─────────────────────────────────────┘  │
│           │                        │       │
│  ┌────────▼─────────────────────────▼──┐  │
│  │    Persistent Volumes               │  │
│  │    (Backups, Data, Configs)         │  │
│  └─────────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

## Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Airflow Webserver | 8085 | DAG scheduling & monitoring |
| Airflow Scheduler | (internal) | DAG execution |
| OpenMetadata | 8585 | Data governance & quality |
| PostgreSQL (Airflow) | 5432 | Airflow metadata DB |
| PostgreSQL (Staging) | 5433 | Data staging warehouse |
| PostgreSQL (Quality) | 5434 | Data quality warehouse |
| MySQL | 3307 | OpenMetadata DB |
| Elasticsearch | 9200 | Search & indexing |

## Configuration

### Environment Variables (.env)

**Airflow Configuration**
```env
AIRFLOW_UID=50000
AIRFLOW_DB_USER=airflow
AIRFLOW_DB_PASSWORD=changeme
AIRFLOW__CORE__FERNET_KEY=<generated-key>
AIRFLOW__CORE__PARALLELISM=32
AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG=1
```

**Database Credentials**
```env
POSTGRES_STAGING_PASSWORD=changeme
POSTGRES_QUALITY_PASSWORD=changeme
MYSQL_ROOT_PASSWORD=changeme
```

**Resource Limits** (adjust for your server)
```env
AIRFLOW_WEBSERVER_MEMORY=2G
AIRFLOW_SCHEDULER_MEMORY=2G
POSTGRES_MEMORY=1G
ELASTICSEARCH_MEMORY=2G
OPENMETADATA_MEMORY=2G
```

### Security Settings

1. **Network Security**
   - All database ports bound to `127.0.0.1` only
   - Use Nginx reverse proxy for external access
   - Enable SSL/TLS certificates

2. **Authentication**
   - Change all default passwords in `.env`
   - Enable Airflow authentication (default: airflow/airflow)
   - Configure OpenMetadata LDAP/SSO

3. **Secrets Management**
   - Store `.env` file securely (chmod 600)
   - Use environment variable injection
   - Never commit `.env` to git
   - Rotate FERNET_KEY regularly

## Deployment

### 1. Initial Deployment

```bash
# Deploy with automatic health checks
bash deploy.sh

# Or manually:
docker-compose up -d
```

### 2. Verify Deployment

```bash
# Check all services
bash health-check.sh

# Check container logs
docker-compose logs -f

# Access services
# Airflow: http://localhost:8085
# OpenMetadata: http://localhost:8585
```

### 3. Initialize Airflow

```bash
# Create Airflow admin user
docker-compose exec airflow-webserver airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password changeme

# Trigger a test DAG
docker-compose exec airflow-webserver airflow dags list
docker-compose exec airflow-webserver airflow dags trigger <dag_id>
```

## Backup & Recovery

### Automated Backups

```bash
# Setup daily backups (cron)
0 2 * * * cd /path/to/pwa-data-quality-deploy && bash backup.sh

# Manual backup
bash backup.sh

# Backups stored in ./backups directory with 30-day retention
```

### Recovery

```bash
# List available backups
ls -lah ./backups/

# Restore specific database
tar -xzf ./backups/backup_20240101_020000.tar.gz
docker-compose exec -T postgres pg_restore -U airflow -d airflow < airflow_20240101_020000.dump
```

## Monitoring

### Docker Compose Commands

```bash
# View running services
docker-compose ps

# View logs
docker-compose logs -f                    # All services
docker-compose logs -f airflow-webserver  # Specific service
docker-compose logs --tail=100            # Last 100 lines

# Check resource usage
docker stats

# Execute command in container
docker-compose exec postgres psql -U airflow -c "SELECT version();"
```

### Health Checks

```bash
# Run comprehensive health check
bash health-check.sh

# Check specific service
curl http://localhost:8085/health          # Airflow
curl http://localhost:8585/api/v1/about   # OpenMetadata
```

## Troubleshooting

### Services Won't Start

1. Check logs for errors:
   ```bash
   docker-compose logs <service-name>
   ```

2. Verify `.env` variables are set correctly:
   ```bash
   docker-compose config | grep -A5 POSTGRES_PASSWORD
   ```

3. Check disk space and memory:
   ```bash
   df -h
   free -h
   docker stats
   ```

### Database Connection Issues

```bash
# Test PostgreSQL connection
docker-compose exec postgres pg_isready -h postgres -U airflow

# Test MySQL connection
docker-compose exec mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;"

# Check database logs
docker-compose logs postgres
docker-compose logs mysql
```

### High Memory/CPU Usage

1. Check which container is consuming resources:
   ```bash
   docker stats --no-stream
   ```

2. Increase resource limits in `.env`:
   ```env
   AIRFLOW_SCHEDULER_MEMORY=4G  # Increase from 2G
   ELASTICSEARCH_MEMORY=4G       # Increase from 2G
   ```

3. Restart services:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

## Scaling

### Vertical Scaling (Single Server)

Update resource limits in `.env` for more powerful servers:
```env
AIRFLOW_WEBSERVER_MEMORY=4G
AIRFLOW_SCHEDULER_MEMORY=4G
ELASTICSEARCH_MEMORY=4G
OPENMETADATA_MEMORY=4G
```

### Horizontal Scaling (Multiple Servers)

1. Use Kubernetes (recommended for production)
2. Use Docker Swarm for multi-node deployment
3. Use managed services (RDS, Cloud SQL) for databases

## Advanced Topics

### SSL/TLS Setup

```bash
# Generate self-signed certificate (testing)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365

# Use with Nginx reverse proxy
# See DEPLOYMENT.md for full setup
```

### Centralized Logging

```bash
# Using ELK Stack or cloud-native logging
# Send logs to:
# - AWS CloudWatch
# - ELK Stack
# - Splunk
# - Datadog
```

### Monitoring with Prometheus

```bash
# Enable Prometheus metrics in Airflow
# Configure Grafana dashboards
# Setup alerting rules
```

## Maintenance

### Daily Tasks
- [ ] Check health status: `bash health-check.sh`
- [ ] Monitor disk space: `df -h`
- [ ] Review error logs: `docker-compose logs`

### Weekly Tasks
- [ ] Verify backup completion: `ls -lah ./backups/`
- [ ] Check database sizes: `docker-compose exec postgres psql -U airflow -c "SELECT datname, pg_size_pretty(pg_database.dblength(datname)) AS size FROM pg_database;"`
- [ ] Review Airflow task runs

### Monthly Tasks
- [ ] Update Docker images: `docker-compose pull`
- [ ] Test restore procedure
- [ ] Security audit
- [ ] Performance optimization

## Support & Documentation

- **Airflow Docs**: https://airflow.apache.org/docs/
- **OpenMetadata Docs**: https://docs.open-metadata.org/
- **Docker Compose Docs**: https://docs.docker.com/compose/
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **Internal Wiki**: https://wiki.example.com/pwa

## License

See LICENSE file in repository root.
