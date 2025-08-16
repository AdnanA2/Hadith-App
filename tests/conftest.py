"""
Test configuration and fixtures
"""

import pytest
import asyncio
from httpx import AsyncClient
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock
import os

# Set test environment
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["SECRET_KEY"] = "test-secret-key"
os.environ["ENVIRONMENT"] = "testing"

from src.main import app
from src.database import database, metadata, engine
from src.auth import create_access_token

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
async def test_db():
    """Set up test database"""
    # Create all tables
    metadata.create_all(engine)
    
    # Connect to database
    await database.connect()
    
    yield database
    
    # Cleanup
    await database.disconnect()
    metadata.drop_all(engine)

@pytest.fixture
async def client(test_db):
    """Create test client"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
def sync_client():
    """Create synchronous test client"""
    return TestClient(app)

@pytest.fixture
async def test_user(test_db):
    """Create a test user"""
    from src.database import users_table
    from src.auth import get_password_hash
    
    user_data = {
        "email": "test@example.com",
        "hashed_password": get_password_hash("testpassword"),
        "full_name": "Test User",
        "is_active": True,
        "is_verified": True,
        "role": "user"
    }
    
    # Insert user
    query = users_table.insert().values(**user_data)
    user_id = await test_db.execute(query)
    
    # Fetch created user
    user_query = users_table.select().where(users_table.c.id == user_id)
    user = await test_db.fetch_one(user_query)
    
    return user

@pytest.fixture
async def test_admin(test_db):
    """Create a test admin user"""
    from src.database import users_table
    from src.auth import get_password_hash
    
    user_data = {
        "email": "admin@example.com",
        "hashed_password": get_password_hash("adminpassword"),
        "full_name": "Admin User",
        "is_active": True,
        "is_verified": True,
        "role": "admin"
    }
    
    # Insert user
    query = users_table.insert().values(**user_data)
    user_id = await test_db.execute(query)
    
    # Fetch created user
    user_query = users_table.select().where(users_table.c.id == user_id)
    user = await test_db.fetch_one(user_query)
    
    return user

@pytest.fixture
def user_token(test_user):
    """Create access token for test user"""
    return create_access_token(data={"sub": test_user.email})

@pytest.fixture
def admin_token(test_admin):
    """Create access token for test admin"""
    return create_access_token(data={"sub": test_admin.email})

@pytest.fixture
async def test_collection(test_db):
    """Create a test collection"""
    from src.database import collections_table
    
    collection_data = {
        "id": "test-collection",
        "name_en": "Test Collection",
        "name_ar": "مجموعة اختبار",
        "description_en": "A test collection",
        "description_ar": "مجموعة للاختبار"
    }
    
    query = collections_table.insert().values(**collection_data)
    await test_db.execute(query)
    
    # Fetch created collection
    collection_query = collections_table.select().where(collections_table.c.id == "test-collection")
    collection = await test_db.fetch_one(collection_query)
    
    return collection

@pytest.fixture
async def test_chapter(test_db, test_collection):
    """Create a test chapter"""
    from src.database import chapters_table
    
    chapter_data = {
        "id": "test-chapter-001",
        "collection_id": test_collection.id,
        "chapter_number": 1,
        "title_en": "Test Chapter",
        "title_ar": "فصل اختبار",
        "description_en": "A test chapter",
        "description_ar": "فصل للاختبار"
    }
    
    query = chapters_table.insert().values(**chapter_data)
    await test_db.execute(query)
    
    # Fetch created chapter
    chapter_query = chapters_table.select().where(chapters_table.c.id == "test-chapter-001")
    chapter = await test_db.fetch_one(chapter_query)
    
    return chapter

@pytest.fixture
async def test_hadith(test_db, test_collection, test_chapter):
    """Create a test hadith"""
    from src.database import hadiths_table
    import json
    
    hadith_data = {
        "id": "test-hadith-001",
        "collection_id": test_collection.id,
        "chapter_id": test_chapter.id,
        "hadith_number": 1,
        "arabic_text": "إنما الأعمال بالنيات",
        "english_text": "Actions are but by intention",
        "narrator": "Umar ibn al-Khattab",
        "grade": "Sahih",
        "grade_details": "Agreed upon",
        "refs": json.dumps({"bukhari": "1", "muslim": "1907"}),
        "tags": json.dumps(["intention", "deeds"]),
        "source_url": "https://example.com/hadith/1"
    }
    
    query = hadiths_table.insert().values(**hadith_data)
    await test_db.execute(query)
    
    # Fetch created hadith
    hadith_query = hadiths_table.select().where(hadiths_table.c.id == "test-hadith-001")
    hadith = await test_db.fetch_one(hadith_query)
    
    return hadith
