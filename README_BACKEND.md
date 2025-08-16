# 📖 Hadith of the Day - Backend API

A modern, scalable REST API for the Hadith of the Day mobile application, built with FastAPI and PostgreSQL.

## 🚀 Features

- **RESTful API** with comprehensive hadith data
- **JWT Authentication** for user management
- **Advanced Search** with full-text search capabilities
- **Favorites System** for personalized collections
- **Daily Hadith** algorithm with consistent selection
- **Pagination & Filtering** for efficient data access
- **PostgreSQL** with optimized indexes and queries
- **Docker Support** for easy deployment
- **Comprehensive Testing** with pytest
- **API Documentation** with interactive Swagger UI

## 📋 API Endpoints

### Authentication
- `POST /api/v1/auth/signup` - User registration
- `POST /api/v1/auth/login` - User login
- `GET /api/v1/auth/me` - Get current user profile
- `PUT /api/v1/auth/me` - Update user profile
- `POST /api/v1/auth/refresh` - Refresh JWT token

### Collections & Chapters
- `GET /api/v1/collections` - List all collections
- `GET /api/v1/collections/{id}` - Get specific collection
- `GET /api/v1/collections/{id}/chapters` - Get collection chapters

### Hadiths
- `GET /api/v1/hadiths` - Search and list hadiths
- `GET /api/v1/hadiths/{id}` - Get specific hadith
- `GET /api/v1/hadiths/daily` - Get daily hadith
- `GET /api/v1/hadiths/random` - Get random hadith
- `GET /api/v1/hadiths/collection/{id}` - Get hadiths by collection
- `GET /api/v1/hadiths/chapter/{id}` - Get hadiths by chapter

### Favorites (Authenticated)
- `GET /api/v1/favorites` - Get user's favorites
- `POST /api/v1/favorites` - Add hadith to favorites
- `PUT /api/v1/favorites/{id}` - Update favorite notes
- `DELETE /api/v1/favorites/{id}` - Remove favorite
- `POST /api/v1/favorites/hadith/{id}` - Toggle favorite status

## 🛠️ Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Clone the repository
git clone <your-repo-url>
cd Hadith-App

# Run automated setup
python scripts/setup_backend.py --start-server
```

### Option 2: Manual Setup

1. **Install Dependencies:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Set up Environment:**
   ```bash
   cp config/.env.example .env
   # Edit .env with your configuration
   ```

3. **Set up Database:**
   ```bash
   # Create PostgreSQL database
   createdb hadith_db
   
   # Run schema
   psql hadith_db -f database/postgresql_schema.sql
   
   # Import sample data
   python scripts/import_data.py --json data/sample_riyad.json
   ```

4. **Start Development Server:**
   ```bash
   uvicorn src.main:app --reload
   ```

Visit http://localhost:8000/docs for interactive API documentation.

## 🐳 Docker Deployment

### Development
```bash
docker-compose up -d
```

### Production
```bash
# Build and deploy
docker-compose -f docker-compose.prod.yml up -d

# Or use individual commands
docker build -t hadith-api .
docker run -p 8000:8000 --env-file .env hadith-api
```

## 🗄️ Database Schema

The API uses PostgreSQL with the following main tables:

- **collections** - Hadith collections (Riyad us-Saliheen, etc.)
- **chapters** - Book chapters within collections
- **hadiths** - Individual hadith texts with metadata
- **users** - User accounts and authentication
- **favorites** - User's favorite hadiths

Key features:
- Full-text search indexes on Arabic and English text
- JSON fields for references and tags
- Optimized indexes for common query patterns
- Foreign key constraints for data integrity

## 📊 Data Sources

The API supports hadith data from:
- **Sunnah.com API** (primary source)
- **Custom JSON format** (normalized structure)
- **Migration from SQLite** (existing data)

### Import Data

```bash
# Fetch from Sunnah.com
python scripts/fetch_sunnah_data.py --collection riyadussaliheen

# Import to database
python scripts/import_data.py --json data/riyad.json

# Migrate from SQLite
python scripts/migrate_sqlite_to_postgres.py \
  --sqlite database/hadith.db \
  --postgres "postgresql://user:pass@localhost/hadith_db"
```

## 🔍 Search & Filtering

The API provides powerful search capabilities:

```bash
# Text search across Arabic and English
GET /api/v1/hadiths?q=prayer

# Filter by collection
GET /api/v1/hadiths?collection_id=riyad-us-saliheen

# Filter by grade (authenticity)
GET /api/v1/hadiths?grade=Sahih

# Combine filters with pagination
GET /api/v1/hadiths?q=intention&grade=Sahih&page=1&page_size=20
```

## 🔐 Authentication

JWT-based authentication with:
- User registration and login
- Secure password hashing (bcrypt)
- Token refresh mechanism
- Role-based access control (user/admin)

Example usage:
```bash
# Register user
curl -X POST "http://localhost:8000/api/v1/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123","full_name":"John Doe"}'

# Login
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Use token in requests
curl -H "Authorization: Bearer <your-token>" \
  "http://localhost:8000/api/v1/favorites"
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src tests/

# Run specific test file
pytest tests/test_auth.py -v

# Run tests in parallel
pytest -n auto
```

Test coverage includes:
- Authentication endpoints
- Hadith search and retrieval
- Favorites management
- Database operations
- Error handling

## 🚀 Deployment

### Supported Platforms

1. **Railway** (recommended for quick deployment)
2. **Render** (free tier available)
3. **Heroku** (with PostgreSQL add-on)
4. **DigitalOcean App Platform**
5. **AWS** (EC2 + RDS)

### Environment Variables

Required environment variables:
```bash
DATABASE_URL=postgresql://user:pass@host:5432/db
SECRET_KEY=your-secret-key
ENVIRONMENT=production
DEBUG=false
ALLOWED_ORIGINS=["https://yourdomain.com"]
```

See [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) for detailed instructions.

## 📈 Performance & Scaling

### Database Optimization
- Indexed columns for common queries
- Full-text search indexes
- Connection pooling
- Query optimization

### Caching Strategy
- Redis integration for frequently accessed data
- Daily hadith caching
- Search result caching
- User favorites caching

### Monitoring
- Health check endpoints
- Structured logging
- Error tracking integration
- Performance metrics

## 🔧 Development

### Project Structure
```
Hadith-App/
├── src/                    # Application source code
│   ├── routers/           # API route handlers
│   ├── models.py          # Pydantic models
│   ├── database.py        # Database configuration
│   ├── auth.py            # Authentication utilities
│   ├── config.py          # Settings management
│   └── main.py            # FastAPI application
├── tests/                 # Test suite
├── scripts/               # Utility scripts
├── database/              # Database schemas
├── data/                  # Sample data files
├── docs/                  # Documentation
└── requirements.txt       # Python dependencies
```

### Code Quality
- Type hints throughout
- Comprehensive error handling
- Consistent code formatting
- Extensive documentation
- Security best practices

## 📚 Documentation

- [API Documentation](docs/API_DOCUMENTATION.md) - Complete API reference
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) - Production deployment
- [Data Setup Guide](docs/data_setup_guide.md) - Data import process
- Interactive docs at `/docs` when running

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License. See LICENSE file for details.

## 🙏 Acknowledgments

- **Sunnah.com** for providing authentic hadith data
- **FastAPI** for the excellent web framework
- **PostgreSQL** for robust database capabilities
- The Muslim community for inspiration and support

---

**Built with ❤️ for the Muslim community**

For questions or support, please open an issue or contact the maintainers.
