# Hadith of the Day API Documentation

## Overview
RESTful API for the Hadith of the Day mobile application. Built with FastAPI and PostgreSQL.

**Base URL:** `https://your-api-domain.com/api/v1`

## Authentication
The API uses JWT (JSON Web Tokens) for authentication. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

## Endpoints

### Authentication

#### POST /auth/signup
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "full_name": "John Doe"
}
```

**Response:**
```json
{
  "success": true,
  "message": "User created successfully",
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer",
    "expires_in": 1800
  },
  "user": {
    "id": 1,
    "email": "user@example.com",
    "full_name": "John Doe",
    "is_active": true,
    "is_verified": false,
    "role": "user",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

#### POST /auth/login
Authenticate user and get access token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:** Same as signup response.

#### GET /auth/me
Get current user profile (requires authentication).

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "user@example.com",
    "full_name": "John Doe",
    "is_active": true,
    "is_verified": false,
    "role": "user",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

#### PUT /auth/me
Update user profile (requires authentication).

**Request Body:**
```json
{
  "full_name": "John Smith",
  "password": "newpassword123"  // optional
}
```

### Collections

#### GET /collections
Get all hadith collections.

**Query Parameters:**
- `page` (int): Page number (default: 1)
- `page_size` (int): Items per page (default: 20, max: 100)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "riyad-us-saliheen",
      "name_en": "Riyad us-Saliheen",
      "name_ar": "رياض الصالحين",
      "description_en": "The Gardens of the Righteous",
      "description_ar": "رياض الصالحين من كلام سيد المرسلين",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 20,
    "total_count": 1,
    "total_pages": 1,
    "has_next": false,
    "has_prev": false
  }
}
```

#### GET /collections/{collection_id}
Get specific collection by ID.

#### GET /collections/{collection_id}/chapters
Get chapters for a specific collection.

### Hadiths

#### GET /hadiths
Get hadiths with search and filtering.

**Query Parameters:**
- `q` (string): Search query
- `collection_id` (string): Filter by collection
- `chapter_id` (string): Filter by chapter
- `grade` (string): Filter by grade (Sahih, Hasan, Da'if, Mawdu', Unknown)
- `narrator` (string): Filter by narrator
- `page` (int): Page number
- `page_size` (int): Items per page

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "riyad-001",
      "collection_id": "riyad-us-saliheen",
      "chapter_id": "riyad-ch-001",
      "hadith_number": 1,
      "arabic_text": "إنما الأعمال بالنيات...",
      "english_text": "Actions are but by intention...",
      "narrator": "Umar ibn al-Khattab",
      "grade": "Sahih",
      "grade_details": "Agreed upon by Al-Bukhari and Muslim",
      "refs": {
        "bukhari": "1",
        "muslim": "1907"
      },
      "tags": ["intention", "sincerity", "deeds"],
      "source_url": "https://sunnah.com/riyadussalihin:1",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z",
      "collection_name_en": "Riyad us-Saliheen",
      "collection_name_ar": "رياض الصالحين",
      "chapter_title_en": "Sincerity and the Intention",
      "chapter_title_ar": "باب الإخلاص وإحضار النية",
      "chapter_number": 1,
      "is_favorite": false
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 20,
    "total_count": 1896,
    "total_pages": 95,
    "has_next": true,
    "has_prev": false
  }
}
```

#### GET /hadiths/{hadith_id}
Get specific hadith by ID.

#### GET /hadiths/daily
Get hadith of the day.

**Query Parameters:**
- `date_param` (string): Specific date in YYYY-MM-DD format (optional)

**Response:**
```json
{
  "success": true,
  "message": "Daily hadith retrieved successfully",
  "data": {
    // Same hadith structure as above
  },
  "date": "2024-01-15"
}
```

#### GET /hadiths/random
Get a random hadith.

**Query Parameters:**
- `collection_id` (string): Filter by collection
- `grade` (string): Filter by grade
- `exclude_favorites` (bool): Exclude user's favorites (requires authentication)

#### GET /hadiths/collection/{collection_id}
Get hadiths from specific collection.

#### GET /hadiths/chapter/{chapter_id}
Get hadiths from specific chapter.

### Favorites (Requires Authentication)

#### GET /favorites
Get user's favorite hadiths.

**Query Parameters:**
- `page` (int): Page number
- `page_size` (int): Items per page
- `collection_id` (string): Filter by collection

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "user_id": 1,
      "hadith_id": "riyad-001",
      "notes": "Beautiful hadith about intention",
      "added_at": "2024-01-15T10:30:00Z",
      "hadith": {
        // Full hadith object with details
      }
    }
  ],
  "meta": {
    // Pagination metadata
  }
}
```

#### POST /favorites
Add hadith to favorites.

**Request Body:**
```json
{
  "hadith_id": "riyad-001",
  "notes": "Optional personal notes"
}
```

#### PUT /favorites/{favorite_id}
Update favorite notes.

**Request Body:**
```json
{
  "notes": "Updated notes"
}
```

#### DELETE /favorites/{favorite_id}
Remove favorite by ID.

#### DELETE /favorites/hadith/{hadith_id}
Remove favorite by hadith ID.

#### POST /favorites/hadith/{hadith_id}
Toggle favorite status of a hadith.

## Error Responses

All error responses follow this format:

```json
{
  "success": false,
  "message": "Error description",
  "details": [
    {
      "field": "email",
      "message": "Field is required",
      "code": "required"
    }
  ],
  "error_code": "VALIDATION_ERROR"
}
```

### Common HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (authentication required)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `422` - Unprocessable Entity (validation errors)
- `500` - Internal Server Error

## Rate Limits
- General API: 100 requests per minute
- Authentication endpoints: 50 requests per minute

## Pagination
All list endpoints support pagination with these query parameters:
- `page`: Page number (starts from 1)
- `page_size`: Items per page (max 100)

Response includes `meta` object with pagination information.

## Search
The search functionality supports:
- Full-text search across Arabic and English text
- Narrator names
- Collection and chapter titles
- Tags

Use the `q` parameter for general search queries.
