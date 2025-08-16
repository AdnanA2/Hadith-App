#!/usr/bin/env python3
"""
Simple Hadith API Server
A minimal FastAPI server that works with the existing SQLite database
"""

import sqlite3
import json
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Pydantic models
class Hadith(BaseModel):
    id: str
    hadith_number: int
    narrator: str
    grade: str
    arabic_text: str
    english_text: str
    collection: str
    chapter: str

class Collection(BaseModel):
    id: str
    name_en: str
    name_ar: str
    description_en: str

class Chapter(BaseModel):
    id: str
    chapter_number: int
    title_en: str
    title_ar: str
    hadith_count: int

class DailyHadith(BaseModel):
    hadith: Hadith
    date: str

# Create FastAPI app
app = FastAPI(
    title="Hadith of the Day API",
    description="Simple API for the Hadith of the Day mobile application",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

def get_db_connection():
    """Get SQLite database connection"""
    try:
        conn = sqlite3.connect("database/hadith.db")
        conn.row_factory = sqlite3.Row
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        raise

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Hadith of the Day API",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running",
        "database": "SQLite"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.execute("SELECT COUNT(*) as count FROM hadiths")
        count = cursor.fetchone()["count"]
        conn.close()
        return {"status": "healthy", "database": "connected", "hadith_count": count}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/api/v1/collections", response_model=List[Collection])
async def get_collections():
    """Get all collections"""
    conn = get_db_connection()
    cursor = conn.execute("SELECT * FROM collections")
    collections = []
    for row in cursor.fetchall():
        collections.append(Collection(
            id=row["id"],
            name_en=row["name_en"],
            name_ar=row["name_ar"],
            description_en=row["description_en"]
        ))
    conn.close()
    return collections

@app.get("/api/v1/collections/{collection_id}/chapters", response_model=List[Chapter])
async def get_chapters(collection_id: str):
    """Get chapters for a collection"""
    conn = get_db_connection()
    cursor = conn.execute("""
        SELECT c.id, c.chapter_number, c.title_en, c.title_ar,
               (SELECT COUNT(*) FROM hadiths WHERE chapter_id = c.id) as hadith_count
        FROM chapters c
        WHERE c.collection_id = ?
        ORDER BY c.chapter_number
    """, (collection_id,))
    chapters = []
    for row in cursor.fetchall():
        chapters.append(Chapter(
            id=row["id"],
            chapter_number=row["chapter_number"],
            title_en=row["title_en"],
            title_ar=row["title_ar"],
            hadith_count=row["hadith_count"]
        ))
    conn.close()
    return chapters

@app.get("/api/v1/hadiths", response_model=List[Hadith])
async def get_hadiths(
    collection_id: Optional[str] = None,
    chapter_id: Optional[str] = None,
    limit: int = 20,
    offset: int = 0
):
    """Get hadiths with optional filtering"""
    conn = get_db_connection()
    
    query = """
        SELECT h.id, h.hadith_number, h.narrator, h.grade,
               h.arabic_text, h.english_text,
               c.name_en as collection, ch.title_en as chapter
        FROM hadiths h
        JOIN collections c ON h.collection_id = c.id
        JOIN chapters ch ON h.chapter_id = ch.id
    """
    params = []
    
    if collection_id:
        query += " WHERE h.collection_id = ?"
        params.append(collection_id)
    
    if chapter_id:
        if collection_id:
            query += " AND h.chapter_id = ?"
        else:
            query += " WHERE h.chapter_id = ?"
        params.append(chapter_id)
    
    query += " ORDER BY h.hadith_number LIMIT ? OFFSET ?"
    params.extend([limit, offset])
    
    cursor = conn.execute(query, params)
    hadiths = []
    for row in cursor.fetchall():
        hadiths.append(Hadith(
            id=row["id"],
            hadith_number=row["hadith_number"],
            narrator=row["narrator"],
            grade=row["grade"],
            arabic_text=row["arabic_text"],
            english_text=row["english_text"],
            collection=row["collection"],
            chapter=row["chapter"]
        ))
    conn.close()
    return hadiths

@app.get("/api/v1/hadiths/{hadith_id}", response_model=Hadith)
async def get_hadith(hadith_id: str):
    """Get a specific hadith by ID"""
    conn = get_db_connection()
    cursor = conn.execute("""
        SELECT h.id, h.hadith_number, h.narrator, h.grade,
               h.arabic_text, h.english_text,
               c.name_en as collection, ch.title_en as chapter
        FROM hadiths h
        JOIN collections c ON h.collection_id = c.id
        JOIN chapters ch ON h.chapter_id = ch.id
        WHERE h.id = ?
    """, (hadith_id,))
    
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        raise HTTPException(status_code=404, detail="Hadith not found")
    
    return Hadith(
        id=row["id"],
        hadith_number=row["hadith_number"],
        narrator=row["narrator"],
        grade=row["grade"],
        arabic_text=row["arabic_text"],
        english_text=row["english_text"],
        collection=row["collection"],
        chapter=row["chapter"]
    )

@app.get("/api/v1/hadiths/daily", response_model=DailyHadith)
async def get_daily_hadith():
    """Get the daily hadith (deterministic based on date)"""
    try:
        # Use absolute path to database
        import os
        db_path = os.path.join(os.path.dirname(__file__), "database", "hadith.db")
        print(f"🔍 Using database path: {db_path}")
        
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        
        # Simple query to get first hadith
        cursor = conn.execute("""
            SELECT h.id, h.hadith_number, h.narrator, h.grade,
                   h.arabic_text, h.english_text,
                   c.name_en as collection, ch.title_en as chapter
            FROM hadiths h
            JOIN collections c ON h.collection_id = c.id
            JOIN chapters ch ON h.chapter_id = ch.id
            ORDER BY h.hadith_number
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            raise HTTPException(status_code=404, detail="No hadiths found")
        
        hadith = Hadith(
            id=row["id"],
            hadith_number=row["hadith_number"],
            narrator=row["narrator"],
            grade=row["grade"],
            arabic_text=row["arabic_text"],
            english_text=row["english_text"],
            collection=row["collection"],
            chapter=row["chapter"]
        )
        
        today = datetime.now()
        return DailyHadith(
            hadith=hadith,
            date=today.strftime("%Y-%m-%d")
        )
        
    except Exception as e:
        print(f"❌ Error in daily hadith: {e}")
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

@app.get("/test")
async def test_endpoint():
    """Test endpoint to verify server is working"""
    return {"message": "Server is working", "timestamp": datetime.now().isoformat()}

@app.get("/api/v1/hadiths/random", response_model=Hadith)
async def get_random_hadith():
    """Get a random hadith"""
    conn = get_db_connection()
    cursor = conn.execute("""
        SELECT h.id, h.hadith_number, h.narrator, h.grade,
               h.arabic_text, h.english_text,
               c.name_en as collection, ch.title_en as chapter
        FROM hadiths h
        JOIN collections c ON h.collection_id = c.id
        JOIN chapters ch ON h.chapter_id = ch.id
        ORDER BY RANDOM()
        LIMIT 1
    """)
    
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        raise HTTPException(status_code=404, detail="No hadiths found")
    
    return Hadith(
        id=row["id"],
        hadith_number=row["hadith_number"],
        narrator=row["narrator"],
        grade=row["grade"],
        arabic_text=row["arabic_text"],
        english_text=row["english_text"],
        collection=row["collection"],
        chapter=row["chapter"]
    )

if __name__ == "__main__":
    uvicorn.run("simple_server:app", host="0.0.0.0", port=8000, reload=True)
