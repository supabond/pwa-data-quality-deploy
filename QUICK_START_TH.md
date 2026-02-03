# 🚀 Quick Start Guide - สำหรับมือใหม่

ติดตั้ง PWA Data Quality ให้สำเร็จในโปรแกรมเดียว!

---

## ✅ ตรวจสอบความพร้อมก่อน Deploy

ก่อน deploy ต้องมี:

1. **Docker Desktop** (หรือ Docker Engine)
   - Windows: [Download Docker Desktop for Windows](https://www.docker.com/products/docker-desktop)
   - Linux: `sudo apt-get install docker.io docker-compose`
   - Mac: [Download Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)

2. **Git** (เพื่อ clone repository)
   - [Download Git](https://git-scm.com/download)

3. **System Requirements**
   ```
   CPU:     ≥ 4 cores (recommended 8+)
   RAM:     ≥ 8GB (recommended 16GB+)
   Storage: ≥ 50GB available space
   ```

---

## 📋 Step-by-Step Installation

### Step 1️⃣: เตรียม Directory

เปิด Terminal/PowerShell แล้ว run:

```bash
# สร้าง directory
mkdir C:\pwa-deployment
cd C:\pwa-deployment

# Clone repository
git clone <repo-url> .
```

### Step 2️⃣: สร้าง Environment Configuration

**Copy template file:**
```bash
# Copy .env.example → .env
copy .env.example .env
```

**เปิดไฟล์ `.env` ด้วย Text Editor (Notepad, VS Code, etc.)**

เปลี่ยนค่า default ที่มี `changeme`:

```env
# === AIRFLOW ===
AIRFLOW_UID=50000
AIRFLOW_DB_USER=airflow
AIRFLOW_DB_PASSWORD=your_secure_password_here    # ← เปลี่ยนนี่
AIRFLOW__CORE__FERNET_KEY=                        # ← เก็บไว้ก่อน

# === DATABASES ===
POSTGRES_STAGING_PASSWORD=your_staging_password   # ← เปลี่ยนนี่
POSTGRES_QUALITY_PASSWORD=your_quality_password   # ← เปลี่ยนนี่
MYSQL_ROOT_PASSWORD=your_mysql_password           # ← เปลี่ยนนี่
OPENMETADATA_ADMIN_PASSWORD=your_om_password      # ← เปลี่ยนนี่

# === RESOURCE LIMITS (ปรับตามเครื่องของคุณ) ===
# ถ้า RAM < 8GB เปลี่ยนเป็น 1G
# ถ้า RAM 8-16GB เก็บค่า default (2G)
# ถ้า RAM > 16GB เปลี่ยนเป็น 4G
AIRFLOW_WEBSERVER_MEMORY=2G
AIRFLOW_SCHEDULER_MEMORY=2G
MYSQL_MEMORY=2G
ELASTICSEARCH_MEMORY=2G
OPENMETADATA_MEMORY=4G
```

### Step 3️⃣: สร้าง FERNET_KEY (สำคัญ!)

FERNET_KEY เป็น encryption key สำหรับ Airflow ต้องสร้างด้วย Python

**ตรวจสอบว่ามี Python ที่ >= 3.8:**
```bash
python --version
```

**สร้าง FERNET_KEY:**
```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

จะได้ output ประมาณนี้:
```
9u_4eH2k8vQ3tJsN5hH8vQ3tJsN5hH8vQ3tJsN5hH8=
```

**Copy ค่านี้ไปใส่ใน `.env`:**
```env
AIRFLOW__CORE__FERNET_KEY=9u_4eH2k8vQ3tJsN5hH8vQ3tJsN5hH8vQ3tJsN5hH8=
```

### Step 4️⃣: Check Docker Desktop เปิดแล้วไหม

ตรวจสอบว่า Docker ทำงาน:

```bash
docker --version
docker ps
```

ถ้า error → เปิด Docker Desktop ก่อน

### Step 5️⃣: Build & Start Services

**รัน deployment script:**

```bash
# Windows PowerShell
bash deploy.sh

สร้าง shared_pool = 1

reference data =  https://docs.google.com/spreadsheets/d/1tUYwWVKKEKMf-kCCBUOVgJklvVT51Mkmke5l3_xheHU/edit?usp=sharing

# หรือ Linux/Mac
./deploy.sh
```

Script นี้จะ:
- ✅ ตรวจสอบความพร้อม
- ✅ เพิ่ม resource limits
- ✅ ดาวน์โหลด Docker images
- ✅ สร้าง database
- ✅ ตรวจสอบ health

⏳ **รอประมาณ 3-5 นาที** ให้ services start ทั้งหมด

---

## 🎯 ตรวจสอบว่า Deploy สำเร็จ

### วิธี 1: รัน Health Check

```bash
bash health-check.sh
```

ควรเห็น ✓ สีเขียว:
```
✓ Airflow is running
✓ OpenMetadata is running
✓ PostgreSQL is running
✓ MySQL is running
✓ Elasticsearch is running
```

### วิธี 2: Check Docker Containers

```bash
docker-compose ps
```

ทุก service ควรแสดง `running` or `healthy`:
```
NAME                    STATUS
postgres                Up 2 minutes (healthy)
airflow-webserver       Up 2 minutes (healthy)
airflow-scheduler       Up 2 minutes (healthy)
mysql                   Up 2 minutes (healthy)
elasticsearch           Up 2 minutes
openmetadata-server     Up 2 minutes
ingestion               Up 2 minutes
pg_staging_data         Up 2 minutes
pg_quality_data         Up 2 minutes
```

---

## 📺 เข้าใช้งาน Services

เปิด Browser แล้ว goto:

### 1. Airflow (DAG Scheduling)
```
http://localhost:8085
```
- Username: `airflow`
- Password: `airflow`

**ทำได้อะไร:**
- ดูรายชื่อ DAGs
- Trigger DAG manually
- ดูตารางการ execute
- Check logs

### 2. OpenMetadata (Data Governance)
```
http://localhost:8585
```
- Username: `admin`
- Password: (ใส่ค่า `OPENMETADATA_ADMIN_PASSWORD` ที่ตั้งใน .env)

**ทำได้อะไร:**
- ดู data catalog
- เช็ค data quality tests
- ดู lineage diagram
- ค้นหา tables

### 3. Databases (สำหรับ Developers)

**PostgreSQL (Airflow):**
```
Host:     localhost
Port:     5432
User:     airflow
Password: (ใส่ค่า AIRFLOW_DB_PASSWORD)
Database: airflow
```

**PostgreSQL Staging (Data Warehouse):**
```
Host:     localhost
Port:     5455
User:     postgres
Password: (ใส่ค่า POSTGRES_STAGING_PASSWORD)
Database: pwa-staging-data
```

**MySQL (OpenMetadata):**
```
Host:     localhost
Port:     3307
User:     root
Password: (ใส่ค่า MYSQL_ROOT_PASSWORD)
```

---

## 🔧 Common Tasks

### ทดสอบ DAG

1. สร้าง DAG file: `airflow/dags/test_dag.py`
   ```python
   from airflow import DAG
   from airflow.operators.bash import BashOperator
   from datetime import datetime
   
   with DAG('test_dag', start_date=datetime(2024, 1, 1)) as dag:
       task1 = BashOperator(task_id='echo_hello', bash_command='echo "Hello from Airflow!"')
   ```

2. Refresh Airflow ที่ UI (หรือรอ 30 วินาที)

3. Trigger DAG → ดูผลใน Logs

### ดู Logs

```bash
# ดู logs ทั้งหมด
docker-compose logs -f

# ดู logs บริการเดียว
docker-compose logs -f airflow-scheduler

# ดู logs ของ specific container
docker logs -f <container_name>
```

### Stop/Restart Services

```bash
# หยุด services
docker-compose down

# Start ใหม่
docker-compose up -d
```

### Check Disk Space Used

```bash
docker system df
```

---

## ⚠️ Troubleshooting

### ❌ Error: "Cannot connect to Docker daemon"

**วิธีแก้:** 
- เปิด Docker Desktop
- ตรวจสอบ Docker ทำงาน: `docker ps`

### ❌ Error: "No space left on device"

**วิธีแก้:**
```bash
# ลบ unused images
docker system prune -a --volumes

# ลบ old backups
rm -rf ./backups/*
```

### ❌ Services ไม่ start / restart ตลอด

**วิธีแก้:**
```bash
# ดู logs
docker-compose logs -f <service_name>

# อาจเป็นหน่วยความจำไม่พอ - ลด resource limits ใน .env
# หรือ restart Docker Desktop
```

### ❌ ลืม Password

**วิธีแก้:** ดูค่าใน `.env` ไฟล์

### ❌ Airflow UI not responding

**วิธีแก้:**
```bash
# Restart webserver
docker-compose restart airflow-webserver

# ดู logs
docker-compose logs airflow-webserver
```

---

## 📚 Next Steps

### 1. สร้าง DAG แรก
- ดู `airflow/dags/` directory
- ศึกษา DAG template ใน `README.md`

### 2. Load Data to Database

```bash
# Connect ไป PostgreSQL (Staging)
psql -h localhost -p 5455 -U postgres -d pwa-staging-data

# Create table
CREATE TABLE test_data (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW()
);
```

### 3. Setup Backup Schedule

```bash
# Manual backup
bash backup.sh

# Automated (Linux/Mac cron):
# 0 2 * * * cd /path/to/pwa-data-quality-deploy && bash backup.sh
```

### 4. Configure Monitoring

```bash
# Health checks
bash health-check.sh

# ตั้ง alert ให้ดูแล services
```

---

## 📞 Help & Support

### ดูเอกสารเพิ่มเติม
- `README.md` - Complete documentation
- `DEPLOYMENT.md` - Advanced topics
- Official docs:
  - Airflow: https://airflow.apache.org/docs/
  - OpenMetadata: https://docs.open-metadata.org/
  - Docker: https://docs.docker.com/

### Common Commands Quick Reference

```bash
# ตรวจสอบสถานะ
docker-compose ps
bash health-check.sh

# Logs
docker-compose logs -f
docker-compose logs -f <service>

# Manage
docker-compose restart <service>
docker-compose down
docker-compose up -d

# Backup
bash backup.sh

# Clean up
docker system prune -a --volumes
```

---

## ✨ ขั้นตอนสรุป

```
1. ✅ ติดตั้ง Docker
2. ✅ Clone repository
3. ✅ Copy .env.example → .env
4. ✅ เปลี่ยน passwords ใน .env
5. ✅ สร้าง FERNET_KEY
6. ✅ รัน bash deploy.sh
7. ✅ รอ 3-5 นาที
8. ✅ เข้า Airflow: http://localhost:8085
9. ✅ เข้า OpenMetadata: http://localhost:8585
10. ✅ เสร็จ! 🎉
```

---

## 🆘 ติดปัญหาไหม?

1. ดู logs: `docker-compose logs`
2. ตรวจสอบ `.env` format (ไม่มี quotes)
3. ลอง restart: `docker-compose down && docker-compose up -d`
4. Clear cache: `docker system prune -a`
5. ดูไฟล์ `README.md` ส่วน Troubleshooting
