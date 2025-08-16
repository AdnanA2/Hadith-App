#!/usr/bin/env python3
"""
Migration script to transfer data from SQLite to PostgreSQL
"""

import asyncio
import asyncpg
import sqlite3
import json
import sys
from pathlib import Path
from datetime import datetime
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SQLiteToPostgresMigrator:
    def __init__(self, sqlite_path: str, postgres_url: str):
        self.sqlite_path = Path(sqlite_path)
        self.postgres_url = postgres_url
        self.sqlite_conn = None
        self.postgres_conn = None
    
    async def connect_postgres(self):
        """Connect to PostgreSQL database"""
        try:
            self.postgres_conn = await asyncpg.connect(self.postgres_url)
            logger.info("Connected to PostgreSQL database")
            return True
        except Exception as e:
            logger.error(f"PostgreSQL connection error: {e}")
            return False
    
    def connect_sqlite(self):
        """Connect to SQLite database"""
        try:
            if not self.sqlite_path.exists():
                logger.error(f"SQLite database not found: {self.sqlite_path}")
                return False
            
            self.sqlite_conn = sqlite3.connect(self.sqlite_path)
            self.sqlite_conn.row_factory = sqlite3.Row
            logger.info(f"Connected to SQLite database: {self.sqlite_path}")
            return True
        except Exception as e:
            logger.error(f"SQLite connection error: {e}")
            return False
    
    async def close_connections(self):
        """Close database connections"""
        if self.postgres_conn:
            await self.postgres_conn.close()
            logger.info("PostgreSQL connection closed")
        
        if self.sqlite_conn:
            self.sqlite_conn.close()
            logger.info("SQLite connection closed")
    
    async def clear_postgres_data(self):
        """Clear existing data from PostgreSQL tables"""
        try:
            tables = ['favorites', 'hadiths', 'chapters', 'collections', 'users']
            for table in tables:
                await self.postgres_conn.execute(f'TRUNCATE TABLE {table} RESTART IDENTITY CASCADE')
            
            logger.info("PostgreSQL data cleared")
            return True
        except Exception as e:
            logger.error(f"Error clearing PostgreSQL data: {e}")
            return False
    
    async def migrate_collections(self):
        """Migrate collections from SQLite to PostgreSQL"""
        try:
            # Get data from SQLite
            cursor = self.sqlite_conn.execute("SELECT * FROM collections")
            collections = cursor.fetchall()
            
            if not collections:
                logger.info("No collections found in SQLite")
                return True
            
            # Insert into PostgreSQL
            for collection in collections:
                await self.postgres_conn.execute("""
                    INSERT INTO collections 
                    (id, name_en, name_ar, description_en, description_ar, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                """, 
                collection['id'],
                collection['name_en'],
                collection['name_ar'],
                collection['description_en'],
                collection['description_ar'],
                collection['created_at'],
                collection['updated_at']
                )
            
            logger.info(f"Migrated {len(collections)} collections")
            return True
        except Exception as e:
            logger.error(f"Error migrating collections: {e}")
            return False
    
    async def migrate_chapters(self):
        """Migrate chapters from SQLite to PostgreSQL"""
        try:
            # Get data from SQLite
            cursor = self.sqlite_conn.execute("SELECT * FROM chapters")
            chapters = cursor.fetchall()
            
            if not chapters:
                logger.info("No chapters found in SQLite")
                return True
            
            # Insert into PostgreSQL
            for chapter in chapters:
                await self.postgres_conn.execute("""
                    INSERT INTO chapters 
                    (id, collection_id, chapter_number, title_en, title_ar, 
                     description_en, description_ar, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                """,
                chapter['id'],
                chapter['collection_id'],
                chapter['chapter_number'],
                chapter['title_en'],
                chapter['title_ar'],
                chapter['description_en'],
                chapter['description_ar'],
                chapter['created_at'],
                chapter['updated_at']
                )
            
            logger.info(f"Migrated {len(chapters)} chapters")
            return True
        except Exception as e:
            logger.error(f"Error migrating chapters: {e}")
            return False
    
    async def migrate_hadiths(self):
        """Migrate hadiths from SQLite to PostgreSQL"""
        try:
            # Get data from SQLite
            cursor = self.sqlite_conn.execute("SELECT * FROM hadiths")
            hadiths = cursor.fetchall()
            
            if not hadiths:
                logger.info("No hadiths found in SQLite")
                return True
            
            # Insert into PostgreSQL in batches
            batch_size = 100
            total_hadiths = len(hadiths)
            
            for i in range(0, total_hadiths, batch_size):
                batch = hadiths[i:i + batch_size]
                
                # Prepare batch data
                batch_data = []
                for hadith in batch:
                    # Parse JSON fields
                    refs = json.loads(hadith['refs']) if hadith['refs'] else {}
                    tags = json.loads(hadith['tags']) if hadith['tags'] else []
                    
                    batch_data.append((
                        hadith['id'],
                        hadith['collection_id'],
                        hadith['chapter_id'],
                        hadith['hadith_number'],
                        hadith['arabic_text'],
                        hadith['english_text'],
                        hadith['narrator'],
                        hadith['grade'],
                        hadith['grade_details'],
                        json.dumps(refs),
                        json.dumps(tags),
                        hadith['source_url'],
                        hadith['created_at'],
                        hadith['updated_at']
                    ))
                
                # Execute batch insert
                await self.postgres_conn.executemany("""
                    INSERT INTO hadiths 
                    (id, collection_id, chapter_id, hadith_number, arabic_text, english_text,
                     narrator, grade, grade_details, refs, tags, source_url, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
                """, batch_data)
                
                logger.info(f"Migrated batch {i//batch_size + 1}: {len(batch)} hadiths")
            
            logger.info(f"Migrated {total_hadiths} hadiths total")
            return True
        except Exception as e:
            logger.error(f"Error migrating hadiths: {e}")
            return False
    
    async def migrate_metadata(self):
        """Migrate database metadata"""
        try:
            # Get data from SQLite
            cursor = self.sqlite_conn.execute("SELECT * FROM db_metadata")
            metadata_rows = cursor.fetchall()
            
            if not metadata_rows:
                logger.info("No metadata found in SQLite")
                return True
            
            # Insert into PostgreSQL
            for row in metadata_rows:
                await self.postgres_conn.execute("""
                    INSERT INTO db_metadata (key, value, updated_at)
                    VALUES ($1, $2, $3)
                    ON CONFLICT (key) DO UPDATE SET
                    value = EXCLUDED.value,
                    updated_at = EXCLUDED.updated_at
                """,
                row['key'],
                row['value'],
                row['updated_at']
                )
            
            # Add migration timestamp
            await self.postgres_conn.execute("""
                INSERT INTO db_metadata (key, value, updated_at)
                VALUES ($1, $2, $3)
                ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                updated_at = EXCLUDED.updated_at
            """,
            'last_sqlite_migration',
            datetime.now().isoformat(),
            datetime.now()
            )
            
            logger.info(f"Migrated {len(metadata_rows)} metadata entries")
            return True
        except Exception as e:
            logger.error(f"Error migrating metadata: {e}")
            return False
    
    async def verify_migration(self):
        """Verify migration integrity"""
        try:
            # Count records in both databases
            sqlite_counts = {}
            postgres_counts = {}
            
            tables = ['collections', 'chapters', 'hadiths']
            
            for table in tables:
                # SQLite count
                cursor = self.sqlite_conn.execute(f"SELECT COUNT(*) FROM {table}")
                sqlite_counts[table] = cursor.fetchone()[0]
                
                # PostgreSQL count
                postgres_counts[table] = await self.postgres_conn.fetchval(f"SELECT COUNT(*) FROM {table}")
            
            # Compare counts
            all_match = True
            for table in tables:
                sqlite_count = sqlite_counts[table]
                postgres_count = postgres_counts[table]
                
                if sqlite_count == postgres_count:
                    logger.info(f"✓ {table}: {postgres_count} records (matches SQLite)")
                else:
                    logger.error(f"✗ {table}: SQLite={sqlite_count}, PostgreSQL={postgres_count}")
                    all_match = False
            
            if all_match:
                logger.info("Migration verification passed!")
            else:
                logger.error("Migration verification failed!")
            
            return all_match
        except Exception as e:
            logger.error(f"Error during verification: {e}")
            return False
    
    async def run_migration(self, clear_existing=True):
        """Run the complete migration process"""
        logger.info("Starting SQLite to PostgreSQL migration")
        
        # Connect to databases
        if not self.connect_sqlite():
            return False
        
        if not await self.connect_postgres():
            return False
        
        try:
            # Clear existing data if requested
            if clear_existing:
                if not await self.clear_postgres_data():
                    return False
            
            # Migrate data in order (respecting foreign key constraints)
            if not await self.migrate_collections():
                return False
            
            if not await self.migrate_chapters():
                return False
            
            if not await self.migrate_hadiths():
                return False
            
            if not await self.migrate_metadata():
                return False
            
            # Verify migration
            if not await self.verify_migration():
                logger.warning("Migration completed but verification failed")
                return False
            
            logger.info("Migration completed successfully!")
            return True
            
        finally:
            await self.close_connections()

async def main():
    """Main function with command line argument handling"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Migrate hadith data from SQLite to PostgreSQL')
    parser.add_argument('--sqlite', default='../database/hadith.db', help='SQLite database path')
    parser.add_argument('--postgres', required=True, help='PostgreSQL connection URL')
    parser.add_argument('--no-clear', action='store_true', help='Do not clear existing PostgreSQL data')
    
    args = parser.parse_args()
    
    # Resolve SQLite path relative to script location
    script_dir = Path(__file__).parent
    sqlite_path = script_dir / args.sqlite
    
    # Create migrator and run
    migrator = SQLiteToPostgresMigrator(sqlite_path, args.postgres)
    success = await migrator.run_migration(clear_existing=not args.no_clear)
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    asyncio.run(main())
