#!/usr/bin/env python3
"""
Hadith of the Day App - Demo Script
This script demonstrates the complete data pipeline and database functionality
"""

import sqlite3
import json
from pathlib import Path
from datetime import datetime

def demo_database():
    """Demonstrate database functionality with sample queries"""
    
    print("🔗 Connecting to SQLite database...")
    db_path = Path("database/hadith.db")
    
    if not db_path.exists():
        print("❌ Database not found. Please run: python3 scripts/import_data.py --sample")
        return
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    
    print("✅ Connected successfully!\n")
    
    # Demo 1: Show collections
    print("📚 COLLECTIONS")
    print("-" * 50)
    cursor = conn.execute("SELECT * FROM collections")
    for row in cursor.fetchall():
        print(f"ID: {row['id']}")
        print(f"English: {row['name_en']}")
        print(f"Arabic: {row['name_ar']}")
        print(f"Description: {row['description_en'][:100]}...")
        print()
    
    # Demo 2: Show chapters
    print("📖 CHAPTERS")
    print("-" * 50)
    cursor = conn.execute("""
        SELECT chapter_number, title_en, title_ar, 
               (SELECT COUNT(*) FROM hadiths WHERE chapter_id = chapters.id) as hadith_count
        FROM chapters 
        ORDER BY chapter_number
    """)
    for row in cursor.fetchall():
        print(f"Chapter {row['chapter_number']}: {row['title_en']}")
        print(f"Arabic: {row['title_ar']}")
        print(f"Hadiths: {row['hadith_count']}")
        print()
    
    # Demo 3: Show sample hadiths
    print("📜 SAMPLE HADITHS")
    print("-" * 50)
    cursor = conn.execute("""
        SELECT h.id, h.hadith_number, h.narrator, h.grade,
               h.arabic_text, h.english_text,
               c.name_en as collection, ch.title_en as chapter
        FROM hadiths h
        JOIN collections c ON h.collection_id = c.id
        JOIN chapters ch ON h.chapter_id = ch.id
        ORDER BY h.hadith_number
        LIMIT 2
    """)
    
    for row in cursor.fetchall():
        print(f"🔸 Hadith #{row['hadith_number']} ({row['id']})")
        print(f"Collection: {row['collection']}")
        print(f"Chapter: {row['chapter']}")
        print(f"Narrator: {row['narrator']}")
        print(f"Grade: {row['grade']}")
        print()
        print("📝 Arabic:")
        print(f"   {row['arabic_text'][:150]}...")
        print()
        print("🔤 English:")
        print(f"   {row['english_text'][:150]}...")
        print()
        print("-" * 30)
        print()
    
    # Demo 4: Statistics
    print("📊 DATABASE STATISTICS")
    print("-" * 50)
    
    # Count statistics
    stats_queries = [
        ("Total Collections", "SELECT COUNT(*) FROM collections"),
        ("Total Chapters", "SELECT COUNT(*) FROM chapters"),
        ("Total Hadiths", "SELECT COUNT(*) FROM hadiths"),
        ("Total Favorites", "SELECT COUNT(*) FROM favorites")
    ]
    
    for label, query in stats_queries:
        cursor = conn.execute(query)
        count = cursor.fetchone()[0]
        print(f"{label}: {count:,}")
    
    # Grade distribution
    print("\n🏆 Grade Distribution:")
    cursor = conn.execute("""
        SELECT grade, COUNT(*) as count,
               ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM hadiths), 1) as percentage
        FROM hadiths 
        GROUP BY grade 
        ORDER BY count DESC
    """)
    
    for row in cursor.fetchall():
        print(f"   {row['grade']}: {row['count']} ({row['percentage']}%)")
    
    # Demo 5: Demonstrate daily hadith selection
    print("\n🌅 DAILY HADITH SELECTION DEMO")
    print("-" * 50)
    
    # Simulate daily hadith algorithm (simple random from Sahih/Hasan)
    cursor = conn.execute("""
        SELECT h.*, c.name_en as collection, ch.title_en as chapter
        FROM hadiths h
        JOIN collections c ON h.collection_id = c.id
        JOIN chapters ch ON h.chapter_id = ch.id
        WHERE h.grade IN ('Sahih', 'Hasan')
        ORDER BY RANDOM()
        LIMIT 1
    """)
    
    daily_hadith = cursor.fetchone()
    if daily_hadith:
        print(f"📅 Today's Hadith: #{daily_hadith['hadith_number']}")
        print(f"📚 From: {daily_hadith['collection']} - {daily_hadith['chapter']}")
        print(f"🎙️  Narrator: {daily_hadith['narrator']}")
        print(f"⭐ Grade: {daily_hadith['grade']}")
        print()
        print("📝 Arabic Text:")
        print(f"   {daily_hadith['arabic_text']}")
        print()
        print("🔤 English Translation:")
        print(f"   {daily_hadith['english_text']}")
        print()
    
    # Demo 6: Show metadata
    print("ℹ️  DATABASE METADATA")
    print("-" * 50)
    cursor = conn.execute("SELECT key, value FROM db_metadata ORDER BY key")
    for row in cursor.fetchall():
        if 'date' in row['key']:
            # Format datetime strings nicely
            try:
                dt = datetime.fromisoformat(row['value'].replace('Z', '+00:00'))
                value = dt.strftime('%Y-%m-%d %H:%M:%S UTC')
            except:
                value = row['value']
        else:
            value = row['value']
        print(f"{row['key']}: {value}")
    
    conn.close()
    print("\n✅ Demo completed successfully!")

def demo_json_schema():
    """Demonstrate JSON schema validation"""
    
    print("\n📋 JSON SCHEMA DEMO")
    print("-" * 50)
    
    schema_path = Path("data/schema.json")
    sample_path = Path("data/sample_riyad.json")
    
    if schema_path.exists():
        with open(schema_path, 'r') as f:
            schema = json.load(f)
        
        print(f"📄 Schema file: {schema_path}")
        print(f"🎯 Title: {schema.get('title', 'N/A')}")
        print(f"📝 Description: {schema.get('description', 'N/A')}")
        print(f"🔧 Required properties: {', '.join(schema.get('required', []))}")
        print()
    
    if sample_path.exists():
        with open(sample_path, 'r') as f:
            sample = json.load(f)
        
        print(f"📊 Sample data: {sample_path}")
        print(f"📚 Collection: {sample['metadata']['collection_name']}")
        print(f"🔢 Total hadiths: {sample['metadata']['total_hadiths']:,}")
        print(f"📅 Last updated: {sample['metadata']['last_updated']}")
        print(f"⚖️  License: {sample['metadata']['license']}")
        print()

def main():
    """Main demo function"""
    
    print("🕌 HADITH OF THE DAY - COMPLETE SYSTEM DEMO")
    print("=" * 60)
    print()
    
    # Show project structure
    print("📁 PROJECT STRUCTURE")
    print("-" * 50)
    
    important_files = [
        ("📄 prd.md", "Product Requirements Document"),
        ("📊 data/schema.json", "JSON Schema Definition"),
        ("📋 data/sample_riyad.json", "Sample Normalized Data"),
        ("🗄️  database/schema.sql", "SQLite Database Schema"),
        ("💾 database/hadith.db", "SQLite Database File"),
        ("🔄 scripts/import_data.py", "Data Import Script"),
        ("✅ scripts/verify_data.py", "Data Verification Script"),
        ("📖 docs/data_setup_guide.md", "Complete Setup Guide")
    ]
    
    for file_desc, description in important_files:
        file_path = file_desc.split(" ", 1)[1] if " " in file_desc else file_desc
        exists = "✅" if Path(file_path).exists() else "❌"
        print(f"{exists} {file_desc} - {description}")
    
    print()
    
    # Demo JSON schema
    demo_json_schema()
    
    # Demo database functionality
    demo_database()
    
    print("\n🎉 WEEK 1 DELIVERABLES COMPLETE!")
    print("=" * 60)
    print("✅ Dataset research and source identification")
    print("✅ JSON schema definition and sample data normalization") 
    print("✅ Complete SQLite database schema with indexes")
    print("✅ Automated import and verification pipeline")
    print("✅ Comprehensive documentation and setup guide")
    print()
    print("🚀 Ready for Week 2: Mobile app development!")
    print("📱 Next steps: Implement Flutter/React Native frontend")
    print("🔗 Database integration: Use SQLite database with app")
    print("⏰ Daily hadith algorithm: Random selection from Sahih/Hasan hadiths")

if __name__ == "__main__":
    main()
