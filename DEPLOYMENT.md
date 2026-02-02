# Production Deployment Guide

## Pre-Deployment Checklist

### 1. Security
- [ ] Generate FERNET_KEY สำหรับ Airflow:
  ```bash
  python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
  ```
- [ ] เปลี่ยนทุก default password ใน `.env`
- [ ] ตั้งค่า firewall rules ให้ block external access
- [ ] ใช้ HTTPS/SSL certificates (Let's Encrypt)
- [ ] Enable authentication ทั้งหมด

### 2. Network Security
- [ ] Bind ports ให้ localhost เท่านั้น (127.0.0.1)
- [ ] ใช้ reverse proxy (Nginx) หรือ load balancer
- [ ] Set up VPN/SSH tunnel สำหรับ access
- [ ] Restrict security groups/firewall

### 3. Database
- [ ] ใช้ managed database (RDS, Cloud SQL) แทน container
- [ ] ตั้งค่า automated backups
- [ ] ทำ backup restore test
- [ ] ตั้งค่า replication สำหรับ HA

### 4. Monitoring & Logging
- [ ] Setup centralized logging (ELK, Loki)
- [ ] Configure Prometheus + Grafana
- [ ] Setup alerts สำหรับ critical services
- [ ] Monitor disk space & resources

### 5. Resource Planning
- [ ] CPU: minimum 8 cores (recommendation 16+)
- [ ] Memory: minimum 16GB (recommendation 32GB+)
- [ ] Storage: minimum 200GB SSD
- [ ] Network bandwidth: min 100 Mbps

## Deployment Steps

### 1. Clone & Setup
```bash
git clone <repo>
cd pwa-data-quality-deploy
cp .env.example .env
# Edit .env with production values
```

### 2. Generate Secrets
```bash
# Generate FERNET_KEY
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Add to .env

# Generate JWT tokens if needed
```

### 3. Pre-flight Checks
```bash
docker-compose config > /dev/null && echo "Config OK"
docker system prune -a --volumes  # Clean old images
```

### 4. Start Services
```bash
# Start databases first
docker-compose up -d postgres mysql elasticsearch

# Wait for health checks
sleep 30

# Start remaining services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

### 5. Post-Deployment
- [ ] Verify all services are healthy
- [ ] Test Airflow UI: http://localhost:8085
- [ ] Test OpenMetadata: http://localhost:8585
- [ ] Run smoke tests
- [ ] Setup backup schedule
- [ ] Document environment specifics

## Backup & Recovery

### Automated Backups
```bash
# Create backup script
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup PostgreSQL
docker-compose exec -T postgres pg_dump -U airflow airflow > $BACKUP_DIR/airflow_$DATE.sql
docker-compose exec -T pg_staging_data pg_dump -U postgres pwa-staging-data > $BACKUP_DIR/staging_$DATE.sql
docker-compose exec -T pg_quality_data pg_dump -U postgres pwa-quality-data > $BACKUP_DIR/quality_$DATE.sql

# Backup MySQL
docker-compose exec -T mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases > $BACKUP_DIR/mysql_$DATE.sql

# Backup Elasticsearch
docker-compose exec -T elasticsearch curl -X GET "localhost:9200/_snapshot" > $BACKUP_DIR/es_snapshot_$DATE.json
EOF

chmod +x backup.sh
```

### Recovery
```bash
# Restore PostgreSQL
docker-compose exec -T postgres psql -U airflow airflow < /backups/airflow_YYYYMMDD_HHMMSS.sql

# Restore MySQL
docker-compose exec -T mysql mysql -u root -p$MYSQL_ROOT_PASSWORD < /backups/mysql_YYYYMMDD_HHMMSS.sql
```

## Troubleshooting

### Services Not Starting
```bash
# Check logs
docker-compose logs -f <service_name>

# Check resource limits
docker stats

# Increase memory if needed (update .env)
```

### Database Connection Issues
```bash
# Test connectivity
docker-compose exec postgres pg_isready -h postgres -U airflow
docker-compose exec mysql mysql -u root -p$MYSQL_ROOT_PASSWORD -h mysql -e "SELECT 1"
```

### Performance Issues
- Increase resource limits in `.env`
- Scale horizontally with load balancer
- Optimize database queries
- Use database indexing

## Scaling for Production

### Vertical Scaling
Update resource limits in `.env`:
```env
AIRFLOW_WEBSERVER_MEMORY=4G
AIRFLOW_SCHEDULER_MEMORY=4G
OPENMETADATA_MEMORY=8G
```

### Horizontal Scaling
Use Docker Swarm or Kubernetes:
```bash
# For Kubernetes
helm repo add airflow https://airflow.apache.org
helm install airflow airflow/airflow
```

### Multi-Node Setup
- Use managed Kubernetes (EKS, GKE, AKS)
- Setup persistent volumes across nodes
- Use distributed databases (RDS, Cloud SQL)
- Setup multi-region backup

## Security Hardening

### 1. Update Base Images
```bash
docker pull postgres:13
docker pull mysql:latest
docker pull docker.elastic.co/elasticsearch/elasticsearch:7.10.2
```

### 2. Network Policies
```yaml
# Example network isolation
networks:
  frontend:
    ipam:
      config:
        - subnet: 172.20.0.0/16
  backend:
    ipam:
      config:
        - subnet: 172.21.0.0/16
```

### 3. Secrets Management
- Use HashiCorp Vault
- AWS Secrets Manager
- Kubernetes Secrets
- Never commit secrets to git

### 4. RBAC & Access Control
- Setup IAM roles
- Enable audit logging
- Implement MFA
- Principle of least privilege

## Maintenance

### Regular Tasks
- [ ] Weekly: Check backups
- [ ] Monthly: Update Docker images
- [ ] Quarterly: Security audit
- [ ] Quarterly: Disaster recovery drill
- [ ] Yearly: Capacity planning

### Updates
```bash
# Pull latest images
docker-compose pull

# Rebuild and restart
docker-compose up -d --force-recreate
```

## Contact & Support
- Email: ops@example.com
- Slack: #pwa-data-quality-ops
- Docs: https://wiki.example.com/pwa
