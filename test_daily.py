#!/usr/bin/env python3
"""
Test script to debug the daily hadith endpoint
"""

import sqlite3
from datetime import datetime

def test_daily_hadith():
    """Test the daily hadith query directly"""
    
    print("🔍 Testing Daily Hadith Query")
    print("=" * 40)
    
    # Connect to database
    conn = sqlite3.connect("database/hadith.db")
    conn.row_factory = sqlite3.Row
    
    # Test the exact query from the API
    query = """
        SELECT h.id, h.hadith_number, h.narrator, h.grade,
               h.arabic_text, h.english_text,
               c.name_en as collection, ch.title_en as chapter
        FROM hadiths h
        JOIN collections c ON h.collection_id = c.id
        JOIN chapters ch ON h.chapter_id = ch.id
        ORDER BY h.hadith_number
        LIMIT 1
    """
    
    print(f"📝 Executing query: {query}")
    print()
    
    try:
        cursor = conn.execute(query)
        row = cursor.fetchone()
        
        if row:
            print("✅ Query successful!")
            print(f"📊 Found hadith: {row['id']}")
            print(f"🔢 Number: {row['hadith_number']}")
            print(f"👤 Narrator: {row['narrator']}")
            print(f"⭐ Grade: {row['grade']}")
            print(f"📚 Collection: {row['collection']}")
            print(f"📖 Chapter: {row['chapter']}")
            print(f"📝 Arabic text length: {len(row['arabic_text'])} chars")
            print(f"🔤 English text length: {len(row['english_text'])} chars")
        else:
            print("❌ Query returned no results")
            
    except Exception as e:
        print(f"❌ Query failed: {e}")
    
    conn.close()
    
    print()
    print("🎯 Testing API endpoint...")
    
    import requests
    try:
        response = requests.get("http://localhost:8000/api/v1/hadiths/daily")
        print(f"📡 Status: {response.status_code}")
        print(f"📄 Response: {response.text}")
    except Exception as e:
        print(f"❌ API request failed: {e}")

if __name__ == "__main__":
    test_daily_hadith()
