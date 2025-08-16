-- Hadith of the Day App - PostgreSQL Database Schema
-- Version: 1.0.0
-- Created: 2024-01-15

-- Create database (run this separately as superuser)
-- CREATE DATABASE hadith_db;
-- CREATE USER hadith_user WITH PASSWORD 'your_password';
-- GRANT ALL PRIVILEGES ON DATABASE hadith_db TO hadith_user;

-- Connect to hadith_db database
\c hadith_db;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Collections table
CREATE TABLE IF NOT EXISTS collections (
    id VARCHAR(255) PRIMARY KEY,
    name_en VARCHAR(500) NOT NULL,
    name_ar VARCHAR(500) NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Chapters table
CREATE TABLE IF NOT EXISTS chapters (
    id VARCHAR(255) PRIMARY KEY,
    collection_id VARCHAR(255) NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    title_en VARCHAR(500) NOT NULL,
    title_ar VARCHAR(500) NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(collection_id, chapter_number)
);

-- Hadiths table
CREATE TABLE IF NOT EXISTS hadiths (
    id VARCHAR(255) PRIMARY KEY,
    collection_id VARCHAR(255) NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    chapter_id VARCHAR(255) NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    hadith_number INTEGER NOT NULL,
    arabic_text TEXT NOT NULL,
    english_text TEXT NOT NULL,
    narrator VARCHAR(500) NOT NULL,
    grade VARCHAR(50) NOT NULL CHECK (grade IN ('Sahih', 'Hasan', 'Da''if', 'Mawdu''', 'Unknown')),
    grade_details TEXT,
    refs JSONB, -- JSON field for references
    tags JSONB, -- JSON field for tags array
    source_url VARCHAR(1000),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(collection_id, hadith_number)
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Favorites table
CREATE TABLE IF NOT EXISTS favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hadith_id VARCHAR(255) NOT NULL REFERENCES hadiths(id) ON DELETE CASCADE,
    notes TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, hadith_id)
);

-- Database metadata table
CREATE TABLE IF NOT EXISTS db_metadata (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_chapters_collection_id ON chapters(collection_id);
CREATE INDEX IF NOT EXISTS idx_chapters_number ON chapters(collection_id, chapter_number);

CREATE INDEX IF NOT EXISTS idx_hadiths_collection_id ON hadiths(collection_id);
CREATE INDEX IF NOT EXISTS idx_hadiths_chapter_id ON hadiths(chapter_id);
CREATE INDEX IF NOT EXISTS idx_hadiths_number ON hadiths(collection_id, hadith_number);
CREATE INDEX IF NOT EXISTS idx_hadiths_grade ON hadiths(grade);
CREATE INDEX IF NOT EXISTS idx_hadiths_narrator ON hadiths(narrator);

CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_hadith_id ON favorites(hadith_id);
CREATE INDEX IF NOT EXISTS idx_favorites_added_at ON favorites(added_at);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = TRUE;

-- Full-text search indexes
CREATE INDEX IF NOT EXISTS idx_hadiths_english_text_gin ON hadiths USING gin(to_tsvector('english', english_text));
CREATE INDEX IF NOT EXISTS idx_hadiths_arabic_text_gin ON hadiths USING gin(to_tsvector('arabic', arabic_text));
CREATE INDEX IF NOT EXISTS idx_hadiths_narrator_gin ON hadiths USING gin(to_tsvector('english', narrator));

-- JSON indexes for tags and references
CREATE INDEX IF NOT EXISTS idx_hadiths_tags_gin ON hadiths USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_hadiths_refs_gin ON hadiths USING gin(refs);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers to automatically update updated_at
CREATE TRIGGER update_collections_updated_at BEFORE UPDATE ON collections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_hadiths_updated_at BEFORE UPDATE ON hadiths
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert initial database metadata
INSERT INTO db_metadata (key, value) VALUES 
    ('schema_version', '1.0.0'),
    ('created_date', CURRENT_TIMESTAMP::text),
    ('last_migration', CURRENT_TIMESTAMP::text)
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = CURRENT_TIMESTAMP;

-- Views for common queries
CREATE OR REPLACE VIEW hadith_with_details AS
SELECT 
    h.id,
    h.hadith_number,
    h.arabic_text,
    h.english_text,
    h.narrator,
    h.grade,
    h.grade_details,
    h.refs,
    h.tags,
    h.source_url,
    h.created_at,
    h.updated_at,
    h.collection_id,
    h.chapter_id,
    c.name_en as collection_name_en,
    c.name_ar as collection_name_ar,
    ch.title_en as chapter_title_en,
    ch.title_ar as chapter_title_ar,
    ch.chapter_number
FROM hadiths h
JOIN collections c ON h.collection_id = c.id
JOIN chapters ch ON h.chapter_id = ch.id;

CREATE OR REPLACE VIEW daily_hadith_candidates AS
SELECT 
    h.*,
    c.name_en as collection_name,
    ch.title_en as chapter_title
FROM hadiths h
JOIN collections c ON h.collection_id = c.id
JOIN chapters ch ON h.chapter_id = ch.id
WHERE h.grade IN ('Sahih', 'Hasan')
ORDER BY h.hadith_number;

-- Grant permissions to hadith_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO hadith_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO hadith_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO hadith_user;
