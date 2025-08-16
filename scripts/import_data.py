#!/usr/bin/env python3
"""
Hadith of the Day App - Data Import Script
This script imports normalized JSON hadith data into SQLite database
"""

import json
import sqlite3
import sys
import os
from datetime import datetime
from pathlib import Path
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HadithDataImporter:
    def __init__(self, db_path: str, json_path: str):
        self.db_path = Path(db_path)
        self.json_path = Path(json_path)
        self.conn = None
        
    def connect_db(self):
        """Connect to SQLite database and enable foreign keys"""
        try:
            self.conn = sqlite3.connect(self.db_path)
            self.conn.execute("PRAGMA foreign_keys = ON")
            logger.info(f"Connected to database: {self.db_path}")
            return True
        except sqlite3.Error as e:
            logger.error(f"Database connection error: {e}")
            return False
    
    def close_db(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")
    
    def create_schema(self):
        """Create database schema from SQL file"""
        schema_path = Path(__file__).parent.parent / "database" / "schema.sql"
        
        if not schema_path.exists():
            logger.error(f"Schema file not found: {schema_path}")
            return False
            
        try:
            with open(schema_path, 'r', encoding='utf-8') as f:
                schema_sql = f.read()
            
            self.conn.executescript(schema_sql)
            self.conn.commit()
            logger.info("Database schema created successfully")
            return True
        except Exception as e:
            logger.error(f"Error creating schema: {e}")
            return False
    
    def load_json_data(self):
        """Load and validate JSON data"""
        if not self.json_path.exists():
            logger.error(f"JSON file not found: {self.json_path}")
            return None
            
        try:
            with open(self.json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Validate required keys
            required_keys = ['metadata', 'collections', 'chapters', 'hadiths']
            for key in required_keys:
                if key not in data:
                    logger.error(f"Missing required key in JSON: {key}")
                    return None
            
            logger.info(f"JSON data loaded successfully. Found {len(data['hadiths'])} hadiths")
            return data
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON format: {e}")
            return None
        except Exception as e:
            logger.error(f"Error loading JSON data: {e}")
            return None
    
    def clear_existing_data(self):
        """Clear existing data from tables"""
        try:
            tables = ['favorites', 'hadiths', 'chapters', 'collections']
            for table in tables:
                self.conn.execute(f"DELETE FROM {table}")
            
            self.conn.commit()
            logger.info("Existing data cleared")
            return True
        except sqlite3.Error as e:
            logger.error(f"Error clearing data: {e}")
            return False
    
    def import_collections(self, collections):
        """Import collections data"""
        try:
            for collection in collections:
                self.conn.execute("""
                    INSERT OR REPLACE INTO collections 
                    (id, name_en, name_ar, description_en, description_ar)
                    VALUES (?, ?, ?, ?, ?)
                """, (
                    collection['id'],
                    collection['name_en'],
                    collection['name_ar'],
                    collection.get('description_en'),
                    collection.get('description_ar')
                ))
            
            self.conn.commit()
            logger.info(f"Imported {len(collections)} collections")
            return True
        except sqlite3.Error as e:
            logger.error(f"Error importing collections: {e}")
            return False
    
    def import_chapters(self, chapters):
        """Import chapters data"""
        try:
            for chapter in chapters:
                self.conn.execute("""
                    INSERT OR REPLACE INTO chapters 
                    (id, collection_id, chapter_number, title_en, title_ar, description_en, description_ar)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    chapter['id'],
                    chapter['collection_id'],
                    chapter['chapter_number'],
                    chapter['title_en'],
                    chapter['title_ar'],
                    chapter.get('description_en'),
                    chapter.get('description_ar')
                ))
            
            self.conn.commit()
            logger.info(f"Imported {len(chapters)} chapters")
            return True
        except sqlite3.Error as e:
            logger.error(f"Error importing chapters: {e}")
            return False
    
    def import_hadiths(self, hadiths):
        """Import hadiths data"""
        try:
            for hadith in hadiths:
                # Convert references and tags to JSON strings
                references_json = json.dumps(hadith.get('references', {}))
                tags_json = json.dumps(hadith.get('tags', []))
                
                self.conn.execute("""
                    INSERT OR REPLACE INTO hadiths 
                    (id, collection_id, chapter_id, hadith_number, arabic_text, english_text, 
                     narrator, grade, grade_details, refs, tags, source_url)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    hadith['id'],
                    hadith['collection_id'],
                    hadith['chapter_id'],
                    hadith['hadith_number'],
                    hadith['arabic_text'],
                    hadith['english_text'],
                    hadith['narrator'],
                    hadith['grade'],
                    hadith.get('grade_details'),
                    references_json,
                    tags_json,
                    hadith.get('source_url')
                ))
            
            self.conn.commit()
            logger.info(f"Imported {len(hadiths)} hadiths")
            return True
        except sqlite3.Error as e:
            logger.error(f"Error importing hadiths: {e}")
            return False
    
    def update_metadata(self, metadata):
        """Update database metadata"""
        try:
            metadata_entries = [
                ('dataset_version', metadata.get('version', '1.0.0')),
                ('dataset_source', metadata.get('source', 'Unknown')),
                ('collection_name', metadata.get('collection_name', 'Unknown')),
                ('total_hadiths', str(metadata.get('total_hadiths', 0))),
                ('last_import_date', datetime.now().isoformat()),
                ('dataset_last_updated', metadata.get('last_updated', '')),
                ('dataset_license', metadata.get('license', ''))
            ]
            
            for key, value in metadata_entries:
                self.conn.execute("""
                    INSERT OR REPLACE INTO db_metadata (key, value, updated_at)
                    VALUES (?, ?, datetime('now'))
                """, (key, value))
            
            self.conn.commit()
            logger.info("Database metadata updated")
            return True
        except sqlite3.Error as e:
            logger.error(f"Error updating metadata: {e}")
            return False
    
    def verify_import(self, expected_counts):
        """Verify imported data integrity"""
        try:
            # Check counts
            tables = ['collections', 'chapters', 'hadiths']
            for table in tables:
                cursor = self.conn.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                expected = expected_counts.get(table, 0)
                
                if count != expected:
                    logger.warning(f"Count mismatch in {table}: expected {expected}, got {count}")
                else:
                    logger.info(f"Verified {table}: {count} records")
            
            # Check foreign key integrity
            cursor = self.conn.execute("""
                SELECT COUNT(*) FROM hadiths h 
                LEFT JOIN collections c ON h.collection_id = c.id 
                WHERE c.id IS NULL
            """)
            orphaned_hadiths = cursor.fetchone()[0]
            
            if orphaned_hadiths > 0:
                logger.error(f"Found {orphaned_hadiths} hadiths with invalid collection references")
                return False
            
            cursor = self.conn.execute("""
                SELECT COUNT(*) FROM hadiths h 
                LEFT JOIN chapters ch ON h.chapter_id = ch.id 
                WHERE ch.id IS NULL
            """)
            orphaned_chapter_refs = cursor.fetchone()[0]
            
            if orphaned_chapter_refs > 0:
                logger.error(f"Found {orphaned_chapter_refs} hadiths with invalid chapter references")
                return False
            
            logger.info("Data integrity verification passed")
            return True
            
        except sqlite3.Error as e:
            logger.error(f"Error during verification: {e}")
            return False
    
    def run_import(self, force_reimport=False):
        """Main import process"""
        logger.info("Starting hadith data import process")
        
        # Check if data already exists
        if not force_reimport and self.db_path.exists():
            try:
                conn = sqlite3.connect(self.db_path)
                cursor = conn.execute("SELECT COUNT(*) FROM hadiths")
                existing_count = cursor.fetchone()[0]
                conn.close()
                
                if existing_count > 0:
                    logger.info(f"Database already contains {existing_count} hadiths. Use --force to reimport.")
                    return True
            except sqlite3.Error:
                pass  # Database might not have proper schema yet
        
        # Connect to database
        if not self.connect_db():
            return False
        
        try:
            # Create schema
            if not self.create_schema():
                return False
            
            # Load JSON data
            data = self.load_json_data()
            if not data:
                return False
            
            # Clear existing data if force reimport
            if force_reimport:
                if not self.clear_existing_data():
                    return False
            
            # Import data in order
            if not self.import_collections(data['collections']):
                return False
            
            if not self.import_chapters(data['chapters']):
                return False
            
            if not self.import_hadiths(data['hadiths']):
                return False
            
            # Update metadata
            if not self.update_metadata(data['metadata']):
                return False
            
            # Verify import
            expected_counts = {
                'collections': len(data['collections']),
                'chapters': len(data['chapters']),
                'hadiths': len(data['hadiths'])
            }
            
            if not self.verify_import(expected_counts):
                return False
            
            logger.info("Data import completed successfully!")
            return True
            
        finally:
            self.close_db()

def main():
    """Main function with command line argument handling"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Import hadith data from JSON to SQLite')
    parser.add_argument('--db', default='../database/hadith.db', help='SQLite database path')
    parser.add_argument('--json', default='../data/riyad.json', help='JSON data file path')
    parser.add_argument('--force', action='store_true', help='Force reimport even if data exists')
    parser.add_argument('--sample', action='store_true', help='Use sample data file')
    
    args = parser.parse_args()
    
    # Use sample data if requested
    if args.sample:
        args.json = '../data/sample_riyad.json'
    
    # Resolve paths relative to script location
    script_dir = Path(__file__).parent
    db_path = script_dir / args.db
    json_path = script_dir / args.json
    
    # Create database directory if it doesn't exist
    db_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Create importer and run
    importer = HadithDataImporter(db_path, json_path)
    success = importer.run_import(force_reimport=args.force)
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
