"""
Favorites router - handles user favorite hadiths
"""

from fastapi import APIRouter, HTTPException, status, Query, Depends
from sqlalchemy import select, insert, delete, update, func, and_
from sqlalchemy.exc import IntegrityError
from typing import Optional

from ..database import database, favorites_table, hadiths_table, collections_table, chapters_table
from ..models import (
    FavoritesResponse, FavoriteResponse, FavoriteCreate, FavoriteUpdate,
    FavoriteWithHadith, HadithWithDetails, PaginationMeta
)
from ..auth import get_current_active_user
from ..config import get_settings

router = APIRouter()
settings = get_settings()

@router.get("/", response_model=FavoritesResponse)
async def get_user_favorites(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    collection_id: Optional[str] = Query(None, description="Filter by collection"),
    current_user: dict = Depends(get_current_active_user)
):
    """Get user's favorite hadiths"""
    
    # Build query with joins
    query = select(
        favorites_table.c.id,
        favorites_table.c.user_id,
        favorites_table.c.hadith_id,
        favorites_table.c.notes,
        favorites_table.c.added_at,
        hadiths_table.c.hadith_number,
        hadiths_table.c.arabic_text,
        hadiths_table.c.english_text,
        hadiths_table.c.narrator,
        hadiths_table.c.grade,
        hadiths_table.c.grade_details,
        hadiths_table.c.refs,
        hadiths_table.c.tags,
        hadiths_table.c.source_url,
        hadiths_table.c.created_at.label("hadith_created_at"),
        hadiths_table.c.updated_at.label("hadith_updated_at"),
        hadiths_table.c.collection_id,
        hadiths_table.c.chapter_id,
        collections_table.c.name_en.label("collection_name_en"),
        collections_table.c.name_ar.label("collection_name_ar"),
        chapters_table.c.title_en.label("chapter_title_en"),
        chapters_table.c.title_ar.label("chapter_title_ar"),
        chapters_table.c.chapter_number,
        func.literal(True).label("is_favorite")
    ).select_from(
        favorites_table
        .join(hadiths_table, favorites_table.c.hadith_id == hadiths_table.c.id)
        .join(collections_table, hadiths_table.c.collection_id == collections_table.c.id)
        .join(chapters_table, hadiths_table.c.chapter_id == chapters_table.c.id)
    ).where(favorites_table.c.user_id == current_user.id)
    
    # Apply collection filter if specified
    if collection_id:
        query = query.where(hadiths_table.c.collection_id == collection_id)
    
    # Get total count
    count_query = select(func.count()).select_from(
        favorites_table.join(hadiths_table, favorites_table.c.hadith_id == hadiths_table.c.id)
    ).where(
        and_(
            favorites_table.c.user_id == current_user.id,
            hadiths_table.c.collection_id == collection_id if collection_id else True
        )
    )
    total_count = await database.fetch_val(count_query)
    
    # Apply pagination
    offset = (page - 1) * page_size
    query = query.order_by(favorites_table.c.added_at.desc()).limit(page_size).offset(offset)
    
    favorites = await database.fetch_all(query)
    
    # Calculate pagination metadata
    total_pages = (total_count + page_size - 1) // page_size
    has_next = page < total_pages
    has_prev = page > 1
    
    meta = PaginationMeta(
        page=page,
        page_size=page_size,
        total_count=total_count,
        total_pages=total_pages,
        has_next=has_next,
        has_prev=has_prev
    )
    
    # Transform results
    favorite_objects = []
    for fav in favorites:
        # Create hadith object
        hadith_data = {
            "id": fav.hadith_id,
            "collection_id": fav.collection_id,
            "chapter_id": fav.chapter_id,
            "hadith_number": fav.hadith_number,
            "arabic_text": fav.arabic_text,
            "english_text": fav.english_text,
            "narrator": fav.narrator,
            "grade": fav.grade,
            "grade_details": fav.grade_details,
            "refs": fav.refs,
            "tags": fav.tags,
            "source_url": fav.source_url,
            "created_at": fav.hadith_created_at,
            "updated_at": fav.hadith_updated_at,
            "collection_name_en": fav.collection_name_en,
            "collection_name_ar": fav.collection_name_ar,
            "chapter_title_en": fav.chapter_title_en,
            "chapter_title_ar": fav.chapter_title_ar,
            "chapter_number": fav.chapter_number,
            "is_favorite": True
        }
        hadith_obj = HadithWithDetails.model_validate(hadith_data)
        
        # Create favorite object
        favorite_data = {
            "id": fav.id,
            "user_id": fav.user_id,
            "hadith_id": fav.hadith_id,
            "notes": fav.notes,
            "added_at": fav.added_at,
            "hadith": hadith_obj
        }
        favorite_obj = FavoriteWithHadith.model_validate(favorite_data)
        favorite_objects.append(favorite_obj)
    
    return FavoritesResponse(
        data=favorite_objects,
        meta=meta
    )

@router.post("/", response_model=FavoriteResponse)
async def add_favorite(
    favorite_data: FavoriteCreate,
    current_user: dict = Depends(get_current_active_user)
):
    """Add a hadith to user's favorites"""
    
    # Check if hadith exists
    hadith_query = select(hadiths_table).where(hadiths_table.c.id == favorite_data.hadith_id)
    hadith = await database.fetch_one(hadith_query)
    
    if not hadith:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hadith not found"
        )
    
    # Check if already favorited
    existing_query = select(favorites_table).where(
        and_(
            favorites_table.c.user_id == current_user.id,
            favorites_table.c.hadith_id == favorite_data.hadith_id
        )
    )
    existing = await database.fetch_one(existing_query)
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Hadith already in favorites"
        )
    
    # Add to favorites
    try:
        query = insert(favorites_table).values(
            user_id=current_user.id,
            hadith_id=favorite_data.hadith_id,
            notes=favorite_data.notes
        )
        favorite_id = await database.execute(query)
        
        # Fetch the created favorite with hadith details
        favorite = await get_favorite_with_hadith(favorite_id, current_user.id)
        
        return FavoriteResponse(
            message="Hadith added to favorites successfully",
            data=favorite
        )
        
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Hadith already in favorites"
        )

@router.get("/{favorite_id}", response_model=FavoriteResponse)
async def get_favorite(
    favorite_id: int,
    current_user: dict = Depends(get_current_active_user)
):
    """Get a specific favorite by ID"""
    
    favorite = await get_favorite_with_hadith(favorite_id, current_user.id)
    
    if not favorite:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Favorite not found"
        )
    
    return FavoriteResponse(data=favorite)

@router.put("/{favorite_id}", response_model=FavoriteResponse)
async def update_favorite(
    favorite_id: int,
    favorite_update: FavoriteUpdate,
    current_user: dict = Depends(get_current_active_user)
):
    """Update favorite notes"""
    
    # Check if favorite exists and belongs to user
    existing_query = select(favorites_table).where(
        and_(
            favorites_table.c.id == favorite_id,
            favorites_table.c.user_id == current_user.id
        )
    )
    existing = await database.fetch_one(existing_query)
    
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Favorite not found"
        )
    
    # Update favorite
    query = (
        update(favorites_table)
        .where(favorites_table.c.id == favorite_id)
        .values(notes=favorite_update.notes)
    )
    await database.execute(query)
    
    # Fetch updated favorite
    favorite = await get_favorite_with_hadith(favorite_id, current_user.id)
    
    return FavoriteResponse(
        message="Favorite updated successfully",
        data=favorite
    )

@router.delete("/{favorite_id}")
async def remove_favorite(
    favorite_id: int,
    current_user: dict = Depends(get_current_active_user)
):
    """Remove a hadith from user's favorites"""
    
    # Check if favorite exists and belongs to user
    existing_query = select(favorites_table).where(
        and_(
            favorites_table.c.id == favorite_id,
            favorites_table.c.user_id == current_user.id
        )
    )
    existing = await database.fetch_one(existing_query)
    
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Favorite not found"
        )
    
    # Delete favorite
    query = delete(favorites_table).where(favorites_table.c.id == favorite_id)
    await database.execute(query)
    
    return {"success": True, "message": "Favorite removed successfully"}

@router.delete("/hadith/{hadith_id}")
async def remove_favorite_by_hadith(
    hadith_id: str,
    current_user: dict = Depends(get_current_active_user)
):
    """Remove a hadith from user's favorites by hadith ID"""
    
    # Check if favorite exists
    existing_query = select(favorites_table).where(
        and_(
            favorites_table.c.user_id == current_user.id,
            favorites_table.c.hadith_id == hadith_id
        )
    )
    existing = await database.fetch_one(existing_query)
    
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hadith not in favorites"
        )
    
    # Delete favorite
    query = delete(favorites_table).where(
        and_(
            favorites_table.c.user_id == current_user.id,
            favorites_table.c.hadith_id == hadith_id
        )
    )
    await database.execute(query)
    
    return {"success": True, "message": "Favorite removed successfully"}

@router.post("/hadith/{hadith_id}", response_model=FavoriteResponse)
async def toggle_favorite(
    hadith_id: str,
    current_user: dict = Depends(get_current_active_user)
):
    """Toggle favorite status of a hadith"""
    
    # Check if hadith exists
    hadith_query = select(hadiths_table).where(hadiths_table.c.id == hadith_id)
    hadith = await database.fetch_one(hadith_query)
    
    if not hadith:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hadith not found"
        )
    
    # Check if already favorited
    existing_query = select(favorites_table).where(
        and_(
            favorites_table.c.user_id == current_user.id,
            favorites_table.c.hadith_id == hadith_id
        )
    )
    existing = await database.fetch_one(existing_query)
    
    if existing:
        # Remove from favorites
        query = delete(favorites_table).where(favorites_table.c.id == existing.id)
        await database.execute(query)
        
        return {"success": True, "message": "Hadith removed from favorites"}
    else:
        # Add to favorites
        query = insert(favorites_table).values(
            user_id=current_user.id,
            hadith_id=hadith_id,
            notes=None
        )
        favorite_id = await database.execute(query)
        
        # Fetch the created favorite with hadith details
        favorite = await get_favorite_with_hadith(favorite_id, current_user.id)
        
        return FavoriteResponse(
            message="Hadith added to favorites successfully",
            data=favorite
        )

async def get_favorite_with_hadith(favorite_id: int, user_id: int) -> Optional[FavoriteWithHadith]:
    """Helper function to get favorite with hadith details"""
    
    query = select(
        favorites_table.c.id,
        favorites_table.c.user_id,
        favorites_table.c.hadith_id,
        favorites_table.c.notes,
        favorites_table.c.added_at,
        hadiths_table.c.hadith_number,
        hadiths_table.c.arabic_text,
        hadiths_table.c.english_text,
        hadiths_table.c.narrator,
        hadiths_table.c.grade,
        hadiths_table.c.grade_details,
        hadiths_table.c.refs,
        hadiths_table.c.tags,
        hadiths_table.c.source_url,
        hadiths_table.c.created_at.label("hadith_created_at"),
        hadiths_table.c.updated_at.label("hadith_updated_at"),
        hadiths_table.c.collection_id,
        hadiths_table.c.chapter_id,
        collections_table.c.name_en.label("collection_name_en"),
        collections_table.c.name_ar.label("collection_name_ar"),
        chapters_table.c.title_en.label("chapter_title_en"),
        chapters_table.c.title_ar.label("chapter_title_ar"),
        chapters_table.c.chapter_number,
        func.literal(True).label("is_favorite")
    ).select_from(
        favorites_table
        .join(hadiths_table, favorites_table.c.hadith_id == hadiths_table.c.id)
        .join(collections_table, hadiths_table.c.collection_id == collections_table.c.id)
        .join(chapters_table, hadiths_table.c.chapter_id == chapters_table.c.id)
    ).where(
        and_(
            favorites_table.c.id == favorite_id,
            favorites_table.c.user_id == user_id
        )
    )
    
    fav = await database.fetch_one(query)
    
    if not fav:
        return None
    
    # Create hadith object
    hadith_data = {
        "id": fav.hadith_id,
        "collection_id": fav.collection_id,
        "chapter_id": fav.chapter_id,
        "hadith_number": fav.hadith_number,
        "arabic_text": fav.arabic_text,
        "english_text": fav.english_text,
        "narrator": fav.narrator,
        "grade": fav.grade,
        "grade_details": fav.grade_details,
        "refs": fav.refs,
        "tags": fav.tags,
        "source_url": fav.source_url,
        "created_at": fav.hadith_created_at,
        "updated_at": fav.hadith_updated_at,
        "collection_name_en": fav.collection_name_en,
        "collection_name_ar": fav.collection_name_ar,
        "chapter_title_en": fav.chapter_title_en,
        "chapter_title_ar": fav.chapter_title_ar,
        "chapter_number": fav.chapter_number,
        "is_favorite": True
    }
    hadith_obj = HadithWithDetails.model_validate(hadith_data)
    
    # Create favorite object
    favorite_data = {
        "id": fav.id,
        "user_id": fav.user_id,
        "hadith_id": fav.hadith_id,
        "notes": fav.notes,
        "added_at": fav.added_at,
        "hadith": hadith_obj
    }
    
    return FavoriteWithHadith.model_validate(favorite_data)
