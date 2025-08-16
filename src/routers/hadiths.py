"""
Hadiths router - handles hadith retrieval, search, and daily hadith
"""

from fastapi import APIRouter, HTTPException, status, Query, Depends
from sqlalchemy import select, func, text, and_, or_
from typing import Optional, List
from datetime import date, datetime
import random

from ..database import (
    database, hadiths_table, collections_table, chapters_table, favorites_table
)
from ..models import (
    HadithsResponse, HadithResponse, DailyHadithResponse,
    HadithWithDetails, HadithSearchParams, RandomHadithParams,
    PaginationMeta, HadithGrade
)
from ..auth import get_current_user_optional
from ..config import get_settings

router = APIRouter()
settings = get_settings()

async def build_hadith_query(
    search_params: Optional[HadithSearchParams] = None,
    user_id: Optional[int] = None,
    base_filters: Optional[dict] = None
):
    """Build a complex hadith query with joins and filters"""
    
    # Base query with joins
    query = select(
        hadiths_table.c.id,
        hadiths_table.c.hadith_number,
        hadiths_table.c.arabic_text,
        hadiths_table.c.english_text,
        hadiths_table.c.narrator,
        hadiths_table.c.grade,
        hadiths_table.c.grade_details,
        hadiths_table.c.refs,
        hadiths_table.c.tags,
        hadiths_table.c.source_url,
        hadiths_table.c.created_at,
        hadiths_table.c.updated_at,
        hadiths_table.c.collection_id,
        hadiths_table.c.chapter_id,
        collections_table.c.name_en.label("collection_name_en"),
        collections_table.c.name_ar.label("collection_name_ar"),
        chapters_table.c.title_en.label("chapter_title_en"),
        chapters_table.c.title_ar.label("chapter_title_ar"),
        chapters_table.c.chapter_number,
        func.coalesce(
            func.bool_or(favorites_table.c.id.isnot(None)), False
        ).label("is_favorite")
    ).select_from(
        hadiths_table
        .join(collections_table, hadiths_table.c.collection_id == collections_table.c.id)
        .join(chapters_table, hadiths_table.c.chapter_id == chapters_table.c.id)
        .outerjoin(
            favorites_table,
            and_(
                favorites_table.c.hadith_id == hadiths_table.c.id,
                favorites_table.c.user_id == user_id
            ) if user_id else False
        )
    )
    
    # Apply base filters
    conditions = []
    if base_filters:
        for key, value in base_filters.items():
            if hasattr(hadiths_table.c, key):
                conditions.append(getattr(hadiths_table.c, key) == value)
    
    # Apply search parameters
    if search_params:
        if search_params.collection_id:
            conditions.append(hadiths_table.c.collection_id == search_params.collection_id)
        
        if search_params.chapter_id:
            conditions.append(hadiths_table.c.chapter_id == search_params.chapter_id)
        
        if search_params.grade:
            conditions.append(hadiths_table.c.grade == search_params.grade.value)
        
        if search_params.narrator:
            conditions.append(
                hadiths_table.c.narrator.ilike(f"%{search_params.narrator}%")
            )
        
        if search_params.q:
            # Full-text search across multiple fields
            search_condition = or_(
                hadiths_table.c.english_text.ilike(f"%{search_params.q}%"),
                hadiths_table.c.arabic_text.ilike(f"%{search_params.q}%"),
                hadiths_table.c.narrator.ilike(f"%{search_params.q}%"),
                collections_table.c.name_en.ilike(f"%{search_params.q}%"),
                chapters_table.c.title_en.ilike(f"%{search_params.q}%")
            )
            conditions.append(search_condition)
        
        if search_params.tags:
            # Search in JSON tags array
            for tag in search_params.tags:
                conditions.append(
                    func.json_extract_path_text(hadiths_table.c.tags, tag).isnot(None)
                )
    
    # Apply all conditions
    if conditions:
        query = query.where(and_(*conditions))
    
    return query

@router.get("/", response_model=HadithsResponse)
async def get_hadiths(
    q: Optional[str] = Query(None, description="Search query"),
    collection_id: Optional[str] = Query(None, description="Filter by collection"),
    chapter_id: Optional[str] = Query(None, description="Filter by chapter"),
    grade: Optional[HadithGrade] = Query(None, description="Filter by grade"),
    narrator: Optional[str] = Query(None, description="Filter by narrator"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: Optional[dict] = Depends(get_current_user_optional)
):
    """Get hadiths with search and filtering"""
    
    search_params = HadithSearchParams(
        q=q,
        collection_id=collection_id,
        chapter_id=chapter_id,
        grade=grade,
        narrator=narrator,
        page=page,
        page_size=page_size
    )
    
    user_id = current_user.id if current_user else None
    
    # Build query
    base_query = await build_hadith_query(search_params, user_id)
    
    # Get total count
    count_query = select(func.count()).select_from(base_query.alias())
    total_count = await database.fetch_val(count_query)
    
    # Apply pagination
    offset = (page - 1) * page_size
    query = base_query.order_by(hadiths_table.c.hadith_number).limit(page_size).offset(offset)
    
    hadiths = await database.fetch_all(query)
    
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
    
    hadith_objects = [HadithWithDetails.model_validate(h) for h in hadiths]
    
    return HadithsResponse(
        data=hadith_objects,
        meta=meta
    )

@router.get("/daily", response_model=DailyHadithResponse)
async def get_daily_hadith(
    date_param: Optional[str] = Query(None, description="Date in YYYY-MM-DD format"),
    current_user: Optional[dict] = Depends(get_current_user_optional)
):
    """Get hadith of the day"""
    
    # Parse date or use today
    if date_param:
        try:
            target_date = datetime.strptime(date_param, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD"
            )
    else:
        target_date = date.today()
    
    # Use date as seed for consistent daily hadith
    random.seed(target_date.toordinal())
    
    user_id = current_user.id if current_user else None
    
    # Get only high-quality hadiths (Sahih and Hasan)
    base_filters = {"grade": "Sahih"}  # Could also include Hasan
    
    base_query = await build_hadith_query(base_filters=base_filters, user_id=user_id)
    
    # Get total count of eligible hadiths
    count_query = select(func.count()).select_from(base_query.alias())
    total_count = await database.fetch_val(count_query)
    
    if total_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No hadiths available for daily selection"
        )
    
    # Select a random hadith based on the date seed
    random_offset = random.randint(0, total_count - 1)
    query = base_query.order_by(hadiths_table.c.hadith_number).limit(1).offset(random_offset)
    
    hadith = await database.fetch_one(query)
    
    if not hadith:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Daily hadith not found"
        )
    
    hadith_obj = HadithWithDetails.model_validate(hadith)
    
    return DailyHadithResponse(
        message="Daily hadith retrieved successfully",
        data=hadith_obj,
        date=target_date.isoformat()
    )

@router.get("/random", response_model=HadithResponse)
async def get_random_hadith(
    collection_id: Optional[str] = Query(None, description="Filter by collection"),
    grade: Optional[HadithGrade] = Query(None, description="Filter by grade"),
    exclude_favorites: bool = Query(False, description="Exclude user's favorites"),
    current_user: Optional[dict] = Depends(get_current_user_optional)
):
    """Get a random hadith"""
    
    user_id = current_user.id if current_user else None
    
    # Build base filters
    base_filters = {}
    if collection_id:
        base_filters["collection_id"] = collection_id
    if grade:
        base_filters["grade"] = grade.value
    
    base_query = await build_hadith_query(base_filters=base_filters, user_id=user_id)
    
    # Exclude favorites if requested and user is authenticated
    if exclude_favorites and user_id:
        base_query = base_query.where(favorites_table.c.id.is_(None))
    
    # Get total count
    count_query = select(func.count()).select_from(base_query.alias())
    total_count = await database.fetch_val(count_query)
    
    if total_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No hadiths found matching criteria"
        )
    
    # Get random hadith
    random_offset = random.randint(0, total_count - 1)
    query = base_query.order_by(hadiths_table.c.hadith_number).limit(1).offset(random_offset)
    
    hadith = await database.fetch_one(query)
    
    if not hadith:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Random hadith not found"
        )
    
    hadith_obj = HadithWithDetails.model_validate(hadith)
    
    return HadithResponse(
        message="Random hadith retrieved successfully",
        data=hadith_obj
    )

@router.get("/{hadith_id}", response_model=HadithResponse)
async def get_hadith(
    hadith_id: str,
    current_user: Optional[dict] = Depends(get_current_user_optional)
):
    """Get a specific hadith by ID"""
    
    user_id = current_user.id if current_user else None
    
    base_query = await build_hadith_query(user_id=user_id)
    query = base_query.where(hadiths_table.c.id == hadith_id)
    
    hadith = await database.fetch_one(query)
    
    if not hadith:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hadith not found"
        )
    
    hadith_obj = HadithWithDetails.model_validate(hadith)
    
    return HadithResponse(
        data=hadith_obj
    )

@router.get("/collection/{collection_id}", response_model=HadithsResponse)
async def get_hadiths_by_collection(
    collection_id: str,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    grade: Optional[HadithGrade] = Query(None, description="Filter by grade"),
    current_user: Optional[dict] = Depends(get_current_user_optional)
):
    """Get hadiths from a specific collection"""
    
    # Verify collection exists
    collection_query = select(collections_table).where(collections_table.c.id == collection_id)
    collection = await database.fetch_one(collection_query)
    
    if not collection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Collection not found"
        )
    
    search_params = HadithSearchParams(
        collection_id=collection_id,
        grade=grade,
        page=page,
        page_size=page_size
    )
    
    user_id = current_user.id if current_user else None
    
    # Build query
    base_query = await build_hadith_query(search_params, user_id)
    
    # Get total count
    count_query = select(func.count()).select_from(base_query.alias())
    total_count = await database.fetch_val(count_query)
    
    # Apply pagination
    offset = (page - 1) * page_size
    query = base_query.order_by(hadiths_table.c.hadith_number).limit(page_size).offset(offset)
    
    hadiths = await database.fetch_all(query)
    
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
    
    hadith_objects = [HadithWithDetails.model_validate(h) for h in hadiths]
    
    return HadithsResponse(
        data=hadith_objects,
        meta=meta
    )

@router.get("/chapter/{chapter_id}", response_model=HadithsResponse)
async def get_hadiths_by_chapter(
    chapter_id: str,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: Optional[dict] = Depends(get_current_user_optional)
):
    """Get hadiths from a specific chapter"""
    
    # Verify chapter exists
    chapter_query = select(chapters_table).where(chapters_table.c.id == chapter_id)
    chapter = await database.fetch_one(chapter_query)
    
    if not chapter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chapter not found"
        )
    
    search_params = HadithSearchParams(
        chapter_id=chapter_id,
        page=page,
        page_size=page_size
    )
    
    user_id = current_user.id if current_user else None
    
    # Build query
    base_query = await build_hadith_query(search_params, user_id)
    
    # Get total count
    count_query = select(func.count()).select_from(base_query.alias())
    total_count = await database.fetch_val(count_query)
    
    # Apply pagination
    offset = (page - 1) * page_size
    query = base_query.order_by(hadiths_table.c.hadith_number).limit(page_size).offset(offset)
    
    hadiths = await database.fetch_all(query)
    
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
    
    hadith_objects = [HadithWithDetails.model_validate(h) for h in hadiths]
    
    return HadithsResponse(
        data=hadith_objects,
        meta=meta
    )
