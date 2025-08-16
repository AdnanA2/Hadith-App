"""
Pydantic models for request/response schemas
"""

from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum

class HadithGrade(str, Enum):
    SAHIH = "Sahih"
    HASAN = "Hasan"
    DAIF = "Da'if"
    MAWDU = "Mawdu'"
    UNKNOWN = "Unknown"

class UserRole(str, Enum):
    USER = "user"
    ADMIN = "admin"

# Base models
class BaseResponse(BaseModel):
    success: bool = True
    message: Optional[str] = None

class PaginationMeta(BaseModel):
    page: int
    page_size: int
    total_count: int
    total_pages: int
    has_next: bool
    has_prev: bool

# Collection models
class CollectionBase(BaseModel):
    name_en: str
    name_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None

class Collection(CollectionBase):
    id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class CollectionResponse(BaseResponse):
    data: Collection

class CollectionsResponse(BaseResponse):
    data: List[Collection]
    meta: Optional[PaginationMeta] = None

# Chapter models
class ChapterBase(BaseModel):
    collection_id: str
    chapter_number: int
    title_en: str
    title_ar: str
    description_en: Optional[str] = None
    description_ar: Optional[str] = None

class Chapter(ChapterBase):
    id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class ChapterResponse(BaseResponse):
    data: Chapter

class ChaptersResponse(BaseResponse):
    data: List[Chapter]
    meta: Optional[PaginationMeta] = None

# Hadith models
class HadithBase(BaseModel):
    collection_id: str
    chapter_id: str
    hadith_number: int
    arabic_text: str
    english_text: str
    narrator: str
    grade: HadithGrade
    grade_details: Optional[str] = None
    refs: Optional[Dict[str, Any]] = None
    tags: Optional[List[str]] = None
    source_url: Optional[str] = None

class Hadith(HadithBase):
    id: str
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class HadithWithDetails(Hadith):
    collection_name_en: Optional[str] = None
    collection_name_ar: Optional[str] = None
    chapter_title_en: Optional[str] = None
    chapter_title_ar: Optional[str] = None
    chapter_number: Optional[int] = None
    is_favorite: bool = False

class HadithResponse(BaseResponse):
    data: HadithWithDetails

class HadithsResponse(BaseResponse):
    data: List[HadithWithDetails]
    meta: Optional[PaginationMeta] = None

class DailyHadithResponse(BaseResponse):
    data: HadithWithDetails
    date: str

# User models
class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    password: Optional[str] = Field(None, min_length=8)

class User(UserBase):
    id: int
    is_active: bool
    is_verified: bool
    role: UserRole
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class UserResponse(BaseResponse):
    data: User

# Authentication models
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int

class TokenData(BaseModel):
    email: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class SignupRequest(UserCreate):
    pass

class AuthResponse(BaseResponse):
    data: Token
    user: User

# Favorite models
class FavoriteBase(BaseModel):
    hadith_id: str
    notes: Optional[str] = None

class FavoriteCreate(FavoriteBase):
    pass

class FavoriteUpdate(BaseModel):
    notes: Optional[str] = None

class Favorite(FavoriteBase):
    id: int
    user_id: int
    added_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class FavoriteWithHadith(Favorite):
    hadith: HadithWithDetails

class FavoriteResponse(BaseResponse):
    data: FavoriteWithHadith

class FavoritesResponse(BaseResponse):
    data: List[FavoriteWithHadith]
    meta: Optional[PaginationMeta] = None

# Search and filter models
class HadithSearchParams(BaseModel):
    q: Optional[str] = Field(None, description="Search query")
    collection_id: Optional[str] = Field(None, description="Filter by collection")
    chapter_id: Optional[str] = Field(None, description="Filter by chapter")
    grade: Optional[HadithGrade] = Field(None, description="Filter by grade")
    narrator: Optional[str] = Field(None, description="Filter by narrator")
    tags: Optional[List[str]] = Field(None, description="Filter by tags")
    page: int = Field(1, ge=1, description="Page number")
    page_size: int = Field(20, ge=1, le=100, description="Items per page")

class RandomHadithParams(BaseModel):
    collection_id: Optional[str] = None
    grade: Optional[HadithGrade] = None
    exclude_favorites: bool = False

# Error models
class ErrorDetail(BaseModel):
    field: Optional[str] = None
    message: str
    code: Optional[str] = None

class ErrorResponse(BaseModel):
    success: bool = False
    message: str
    details: Optional[List[ErrorDetail]] = None
    error_code: Optional[str] = None
