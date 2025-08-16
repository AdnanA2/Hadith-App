"""
Collections router - handles hadith collections and chapters
"""

from fastapi import APIRouter, HTTPException, status, Query
from sqlalchemy import select, func
from typing import Optional

from ..database import database, collections_table, chapters_table
from ..models import CollectionsResponse, ChaptersResponse, Collection, Chapter, PaginationMeta
from ..config import get_settings

router = APIRouter()
settings = get_settings()

@router.get("/", response_model=CollectionsResponse)
async def get_collections(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page")
):
    """Get all hadith collections with pagination"""
    
    # Calculate offset
    offset = (page - 1) * page_size
    
    # Get total count
    count_query = select(func.count()).select_from(collections_table)
    total_count = await database.fetch_val(count_query)
    
    # Get collections
    query = (
        select(collections_table)
        .order_by(collections_table.c.name_en)
        .limit(page_size)
        .offset(offset)
    )
    
    collections = await database.fetch_all(query)
    
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
    
    collection_objects = [Collection.model_validate(col) for col in collections]
    
    return CollectionsResponse(
        data=collection_objects,
        meta=meta
    )

@router.get("/{collection_id}", response_model=CollectionsResponse)
async def get_collection(collection_id: str):
    """Get a specific collection by ID"""
    
    query = select(collections_table).where(collections_table.c.id == collection_id)
    collection = await database.fetch_one(query)
    
    if not collection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Collection not found"
        )
    
    collection_obj = Collection.model_validate(collection)
    return CollectionsResponse(data=[collection_obj])

@router.get("/{collection_id}/chapters", response_model=ChaptersResponse)
async def get_collection_chapters(
    collection_id: str,
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(50, ge=1, le=100, description="Items per page")
):
    """Get chapters for a specific collection"""
    
    # Verify collection exists
    collection_query = select(collections_table).where(collections_table.c.id == collection_id)
    collection = await database.fetch_one(collection_query)
    
    if not collection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Collection not found"
        )
    
    # Calculate offset
    offset = (page - 1) * page_size
    
    # Get total count
    count_query = select(func.count()).select_from(chapters_table).where(
        chapters_table.c.collection_id == collection_id
    )
    total_count = await database.fetch_val(count_query)
    
    # Get chapters
    query = (
        select(chapters_table)
        .where(chapters_table.c.collection_id == collection_id)
        .order_by(chapters_table.c.chapter_number)
        .limit(page_size)
        .offset(offset)
    )
    
    chapters = await database.fetch_all(query)
    
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
    
    chapter_objects = [Chapter.model_validate(ch) for ch in chapters]
    
    return ChaptersResponse(
        data=chapter_objects,
        meta=meta
    )

@router.get("/{collection_id}/chapters/{chapter_id}", response_model=ChaptersResponse)
async def get_chapter(collection_id: str, chapter_id: str):
    """Get a specific chapter by ID"""
    
    query = select(chapters_table).where(
        (chapters_table.c.collection_id == collection_id) &
        (chapters_table.c.id == chapter_id)
    )
    chapter = await database.fetch_one(query)
    
    if not chapter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chapter not found"
        )
    
    chapter_obj = Chapter.model_validate(chapter)
    return ChaptersResponse(data=[chapter_obj])
