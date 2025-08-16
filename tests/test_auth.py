"""
Test authentication endpoints
"""

import pytest
from httpx import AsyncClient

class TestAuth:
    """Test authentication functionality"""
    
    async def test_signup_success(self, client: AsyncClient):
        """Test successful user signup"""
        signup_data = {
            "email": "newuser@example.com",
            "password": "testpassword123",
            "full_name": "New User"
        }
        
        response = await client.post("/api/v1/auth/signup", json=signup_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert "access_token" in data["data"]
        assert "user" in data
        assert data["user"]["email"] == signup_data["email"]
        assert data["user"]["full_name"] == signup_data["full_name"]
    
    async def test_signup_duplicate_email(self, client: AsyncClient, test_user):
        """Test signup with duplicate email"""
        signup_data = {
            "email": test_user.email,
            "password": "testpassword123",
            "full_name": "Duplicate User"
        }
        
        response = await client.post("/api/v1/auth/signup", json=signup_data)
        
        assert response.status_code == 400
        data = response.json()
        assert "already registered" in data["detail"].lower()
    
    async def test_signup_invalid_email(self, client: AsyncClient):
        """Test signup with invalid email"""
        signup_data = {
            "email": "invalid-email",
            "password": "testpassword123",
            "full_name": "Test User"
        }
        
        response = await client.post("/api/v1/auth/signup", json=signup_data)
        
        assert response.status_code == 422  # Validation error
    
    async def test_signup_weak_password(self, client: AsyncClient):
        """Test signup with weak password"""
        signup_data = {
            "email": "test2@example.com",
            "password": "123",  # Too short
            "full_name": "Test User"
        }
        
        response = await client.post("/api/v1/auth/signup", json=signup_data)
        
        assert response.status_code == 422  # Validation error
    
    async def test_login_success(self, client: AsyncClient, test_user):
        """Test successful login"""
        login_data = {
            "email": test_user.email,
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert "access_token" in data["data"]
        assert "user" in data
        assert data["user"]["email"] == test_user.email
    
    async def test_login_wrong_password(self, client: AsyncClient, test_user):
        """Test login with wrong password"""
        login_data = {
            "email": test_user.email,
            "password": "wrongpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        
        assert response.status_code == 401
        data = response.json()
        assert "incorrect" in data["detail"].lower()
    
    async def test_login_nonexistent_user(self, client: AsyncClient):
        """Test login with nonexistent user"""
        login_data = {
            "email": "nonexistent@example.com",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        
        assert response.status_code == 401
        data = response.json()
        assert "incorrect" in data["detail"].lower()
    
    async def test_get_current_user(self, client: AsyncClient, user_token):
        """Test getting current user profile"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = await client.get("/api/v1/auth/me", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert data["data"]["email"] == "test@example.com"
    
    async def test_get_current_user_invalid_token(self, client: AsyncClient):
        """Test getting current user with invalid token"""
        headers = {"Authorization": "Bearer invalid-token"}
        
        response = await client.get("/api/v1/auth/me", headers=headers)
        
        assert response.status_code == 401
    
    async def test_get_current_user_no_token(self, client: AsyncClient):
        """Test getting current user without token"""
        response = await client.get("/api/v1/auth/me")
        
        assert response.status_code == 403  # No authorization header
    
    async def test_update_profile(self, client: AsyncClient, user_token):
        """Test updating user profile"""
        headers = {"Authorization": f"Bearer {user_token}"}
        update_data = {
            "full_name": "Updated Name"
        }
        
        response = await client.put("/api/v1/auth/me", json=update_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["full_name"] == "Updated Name"
    
    async def test_update_password(self, client: AsyncClient, user_token):
        """Test updating user password"""
        headers = {"Authorization": f"Bearer {user_token}"}
        update_data = {
            "password": "newpassword123"
        }
        
        response = await client.put("/api/v1/auth/me", json=update_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        
        # Test login with new password
        login_data = {
            "email": "test@example.com",
            "password": "newpassword123"
        }
        
        login_response = await client.post("/api/v1/auth/login", json=login_data)
        assert login_response.status_code == 200
    
    async def test_refresh_token(self, client: AsyncClient, user_token):
        """Test token refresh"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = await client.post("/api/v1/auth/refresh", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "data" in data
        assert "access_token" in data["data"]
        assert "user" in data
