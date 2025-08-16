# Deployment Guide

This guide covers deploying the Hadith of the Day backend API to various cloud platforms.

## Prerequisites

1. **Docker** and **Docker Compose** installed
2. **PostgreSQL** database (managed or self-hosted)
3. **Domain name** (for production)
4. **SSL certificates** (for HTTPS)

## Environment Variables

Create a `.env` file with the following variables:

```bash
# Database
DATABASE_URL=postgresql://username:password@host:5432/database_name

# JWT
SECRET_KEY=your-super-secret-jwt-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS
ALLOWED_ORIGINS=["https://yourdomain.com","https://www.yourdomain.com"]

# App
APP_NAME="Hadith of the Day API"
DEBUG=false
ENVIRONMENT=production

# Optional
REDIS_URL=redis://localhost:6379/0
```

## Local Development

1. **Clone and setup:**
   ```bash
   git clone <your-repo>
   cd Hadith-App
   cp .env.example .env
   # Edit .env with your settings
   ```

2. **Start with Docker Compose:**
   ```bash
   docker-compose up -d
   ```

3. **Run database migrations:**
   ```bash
   # Create PostgreSQL schema
   psql -h localhost -U hadith_user -d hadith_db -f database/postgresql_schema.sql
   
   # Migrate data from SQLite (if needed)
   python scripts/migrate_sqlite_to_postgres.py --postgres "postgresql://hadith_user:hadith_password@localhost:5432/hadith_db"
   ```

4. **Import hadith data:**
   ```bash
   # Import from existing JSON data
   python scripts/import_data.py --db postgresql://hadith_user:hadith_password@localhost:5432/hadith_db --json data/sample_riyad.json
   ```

## Deployment Options

### 1. Railway

Railway provides easy deployment with managed PostgreSQL.

1. **Install Railway CLI:**
   ```bash
   npm install -g @railway/cli
   railway login
   ```

2. **Initialize project:**
   ```bash
   railway init
   railway add postgresql
   ```

3. **Deploy:**
   ```bash
   railway up
   ```

4. **Set environment variables:**
   ```bash
   railway variables set SECRET_KEY=your-secret-key
   railway variables set ENVIRONMENT=production
   railway variables set DEBUG=false
   ```

### 2. Render

Render offers free tier with PostgreSQL.

1. **Create `render.yaml`:**
   ```yaml
   services:
     - type: web
       name: hadith-api
       env: python
       buildCommand: pip install -r requirements.txt
       startCommand: gunicorn src.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
       envVars:
         - key: DATABASE_URL
           fromDatabase:
             name: hadith-db
             property: connectionString
         - key: SECRET_KEY
           generateValue: true
         - key: ENVIRONMENT
           value: production
   
   databases:
     - name: hadith-db
       databaseName: hadith_db
       user: hadith_user
   ```

2. **Deploy:**
   - Connect GitHub repository
   - Render will auto-deploy on push

### 3. Heroku

1. **Install Heroku CLI and login:**
   ```bash
   heroku login
   ```

2. **Create app:**
   ```bash
   heroku create your-app-name
   heroku addons:create heroku-postgresql:essential-0
   ```

3. **Set environment variables:**
   ```bash
   heroku config:set SECRET_KEY=your-secret-key
   heroku config:set ENVIRONMENT=production
   heroku config:set DEBUG=false
   ```

4. **Deploy:**
   ```bash
   git push heroku main
   ```

### 4. DigitalOcean App Platform

1. **Create `app.yaml`:**
   ```yaml
   name: hadith-api
   services:
   - name: api
     source_dir: /
     github:
       repo: your-username/hadith-app
       branch: main
     run_command: gunicorn src.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
     environment_slug: python
     instance_count: 1
     instance_size_slug: basic-xxs
     envs:
     - key: DATABASE_URL
       value: ${db.DATABASE_URL}
     - key: SECRET_KEY
       value: your-secret-key
     - key: ENVIRONMENT
       value: production
   databases:
   - name: db
     engine: PG
     num_nodes: 1
     size: db-s-dev-database
     version: "13"
   ```

2. **Deploy:**
   ```bash
   doctl apps create app.yaml
   ```

### 5. AWS (EC2 + RDS)

1. **Launch EC2 instance** (Ubuntu 20.04 LTS)

2. **Install Docker:**
   ```bash
   sudo apt update
   sudo apt install docker.io docker-compose
   sudo usermod -aG docker ubuntu
   ```

3. **Create RDS PostgreSQL instance**

4. **Clone and deploy:**
   ```bash
   git clone <your-repo>
   cd Hadith-App
   # Set up .env with RDS connection string
   docker-compose -f docker-compose.prod.yml up -d
   ```

5. **Set up Nginx and SSL:**
   ```bash
   sudo apt install nginx certbot python3-certbot-nginx
   sudo certbot --nginx -d yourdomain.com
   ```

## Database Setup

### Create PostgreSQL Database

1. **Local PostgreSQL:**
   ```bash
   sudo -u postgres psql
   CREATE DATABASE hadith_db;
   CREATE USER hadith_user WITH PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE hadith_db TO hadith_user;
   ```

2. **Run schema:**
   ```bash
   psql -h localhost -U hadith_user -d hadith_db -f database/postgresql_schema.sql
   ```

### Data Migration

1. **From SQLite to PostgreSQL:**
   ```bash
   python scripts/migrate_sqlite_to_postgres.py \
     --sqlite database/hadith.db \
     --postgres "postgresql://user:pass@host:5432/db"
   ```

2. **Import new data:**
   ```bash
   # Fetch fresh data
   python scripts/fetch_sunnah_data.py --collection riyadussaliheen --output data/riyad.json
   
   # Import to PostgreSQL
   python scripts/import_data.py --db "postgresql://user:pass@host:5432/db" --json data/riyad.json
   ```

## Production Checklist

### Security
- [ ] Change default SECRET_KEY
- [ ] Set DEBUG=false
- [ ] Configure ALLOWED_ORIGINS
- [ ] Enable HTTPS/SSL
- [ ] Set up rate limiting
- [ ] Configure CORS properly
- [ ] Use environment variables for secrets

### Performance
- [ ] Set up Redis for caching
- [ ] Configure database connection pooling
- [ ] Enable gzip compression
- [ ] Set up CDN for static files
- [ ] Configure database indexes

### Monitoring
- [ ] Set up application logging
- [ ] Configure error tracking (Sentry)
- [ ] Monitor database performance
- [ ] Set up uptime monitoring
- [ ] Configure backup strategy

### Backup
- [ ] Database backups (daily)
- [ ] Application data backups
- [ ] Environment configuration backup
- [ ] SSL certificate backup

## Scaling

### Horizontal Scaling
```bash
# Scale API instances
docker-compose up -d --scale api=3

# Load balancer configuration
# Update nginx.conf with multiple upstream servers
```

### Database Optimization
```sql
-- Add indexes for common queries
CREATE INDEX CONCURRENTLY idx_hadiths_search ON hadiths USING gin(to_tsvector('english', english_text));

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM hadiths WHERE grade = 'Sahih';
```

### Caching Strategy
```python
# Redis caching for frequently accessed data
# - Daily hadith
# - Popular hadiths
# - User favorites
# - Search results
```

## Troubleshooting

### Common Issues

1. **Database connection errors:**
   ```bash
   # Check connection string
   psql $DATABASE_URL
   
   # Verify network access
   telnet hostname 5432
   ```

2. **SSL/HTTPS issues:**
   ```bash
   # Check certificate
   openssl x509 -in /path/to/cert.pem -text -noout
   
   # Renew Let's Encrypt
   sudo certbot renew
   ```

3. **Performance issues:**
   ```bash
   # Check logs
   docker logs hadith_api
   
   # Monitor resources
   docker stats
   
   # Database queries
   SELECT * FROM pg_stat_activity;
   ```

### Health Checks

The API includes health check endpoints:
- `GET /health` - Basic health check
- `GET /` - API information

Monitor these endpoints for uptime.

## Support

For deployment issues:
1. Check application logs
2. Verify environment variables
3. Test database connectivity
4. Review network/firewall settings
5. Check SSL certificate validity
