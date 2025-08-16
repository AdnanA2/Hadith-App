"""
Test hadith endpoints
"""

import pytest
from httpx import AsyncClient

class TestHadiths:
    """Test hadith functionality"""
    
    async def test_get_hadiths(self, client: AsyncClient, test_hadith):
        """Test getting hadiths list"""
        response = await client.get("/api/v1/hadiths/")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert len(data["data"]) >= 1
        assert "meta" in data
        
        # Check hadith structure
        hadith = data["data"][0]
        assert "id" in hadith
        assert "arabic_text" in hadith
        assert "english_text" in hadith
        assert "narrator" in hadith
        assert "grade" in hadith
    
    async def test_get_hadiths_pagination(self, client: AsyncClient, test_hadith):
        """Test hadiths pagination"""
        response = await client.get("/api/v1/hadiths/?page=1&page_size=5")
        
        assert response.status_code == 200
        data = response.json()
        assert data["meta"]["page"] == 1
        assert data["meta"]["page_size"] == 5
    
    async def test_get_hadiths_search(self, client: AsyncClient, test_hadith):
        """Test hadith search"""
        response = await client.get("/api/v1/hadiths/?q=intention")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        # Should find our test hadith with "intention" in tags or text
    
    async def test_get_hadiths_filter_by_grade(self, client: AsyncClient, test_hadith):
        """Test filtering hadiths by grade"""
        response = await client.get("/api/v1/hadiths/?grade=Sahih")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        
        # All returned hadiths should be Sahih
        for hadith in data["data"]:
            assert hadith["grade"] == "Sahih"
    
    async def test_get_hadith_by_id(self, client: AsyncClient, test_hadith):
        """Test getting specific hadith by ID"""
        response = await client.get(f"/api/v1/hadiths/{test_hadith.id}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["id"] == test_hadith.id
        assert data["data"]["arabic_text"] == test_hadith.arabic_text
        assert data["data"]["english_text"] == test_hadith.english_text
    
    async def test_get_hadith_by_id_not_found(self, client: AsyncClient):
        """Test getting nonexistent hadith"""
        response = await client.get("/api/v1/hadiths/nonexistent-id")
        
        assert response.status_code == 404
        data = response.json()
        assert "not found" in data["detail"].lower()
    
    async def test_get_daily_hadith(self, client: AsyncClient, test_hadith):
        """Test getting daily hadith"""
        response = await client.get("/api/v1/hadiths/daily")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert "date" in data
        
        # Check hadith structure
        hadith = data["data"]
        assert "id" in hadith
        assert "arabic_text" in hadith
        assert "english_text" in hadith
        assert hadith["grade"] == "Sahih"  # Daily hadith should be high quality
    
    async def test_get_daily_hadith_specific_date(self, client: AsyncClient, test_hadith):
        """Test getting daily hadith for specific date"""
        response = await client.get("/api/v1/hadiths/daily?date_param=2024-01-15")
        
        assert response.status_code == 200
        data = response.json()
        assert data["date"] == "2024-01-15"
    
    async def test_get_daily_hadith_invalid_date(self, client: AsyncClient):
        """Test getting daily hadith with invalid date"""
        response = await client.get("/api/v1/hadiths/daily?date_param=invalid-date")
        
        assert response.status_code == 400
        data = response.json()
        assert "invalid date format" in data["detail"].lower()
    
    async def test_get_random_hadith(self, client: AsyncClient, test_hadith):
        """Test getting random hadith"""
        response = await client.get("/api/v1/hadiths/random")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        
        # Check hadith structure
        hadith = data["data"]
        assert "id" in hadith
        assert "arabic_text" in hadith
        assert "english_text" in hadith
    
    async def test_get_random_hadith_with_filters(self, client: AsyncClient, test_hadith):
        """Test getting random hadith with filters"""
        response = await client.get(f"/api/v1/hadiths/random?collection_id={test_hadith.collection_id}&grade=Sahih")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        
        hadith = data["data"]
        assert hadith["collection_id"] == test_hadith.collection_id
        assert hadith["grade"] == "Sahih"
    
    async def test_get_hadiths_by_collection(self, client: AsyncClient, test_hadith):
        """Test getting hadiths from specific collection"""
        response = await client.get(f"/api/v1/hadiths/collection/{test_hadith.collection_id}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        
        # All hadiths should be from the specified collection
        for hadith in data["data"]:
            assert hadith["collection_id"] == test_hadith.collection_id
    
    async def test_get_hadiths_by_collection_not_found(self, client: AsyncClient):
        """Test getting hadiths from nonexistent collection"""
        response = await client.get("/api/v1/hadiths/collection/nonexistent-collection")
        
        assert response.status_code == 404
        data = response.json()
        assert "not found" in data["detail"].lower()
    
    async def test_get_hadiths_by_chapter(self, client: AsyncClient, test_hadith):
        """Test getting hadiths from specific chapter"""
        response = await client.get(f"/api/v1/hadiths/chapter/{test_hadith.chapter_id}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        
        # All hadiths should be from the specified chapter
        for hadith in data["data"]:
            assert hadith["chapter_id"] == test_hadith.chapter_id
    
    async def test_get_hadiths_by_chapter_not_found(self, client: AsyncClient):
        """Test getting hadiths from nonexistent chapter"""
        response = await client.get("/api/v1/hadiths/chapter/nonexistent-chapter")
        
        assert response.status_code == 404
        data = response.json()
        assert "not found" in data["detail"].lower()
    
    async def test_get_hadiths_with_favorites(self, client: AsyncClient, test_hadith, user_token):
        """Test getting hadiths with favorite status for authenticated user"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = await client.get("/api/v1/hadiths/", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        
        # Check that is_favorite field is present
        for hadith in data["data"]:
            assert "is_favorite" in hadith
            assert isinstance(hadith["is_favorite"], bool)
