-- Hadith of the Day App - SQLite Database Schema
-- Version: 1.0.0
-- Created: 2024-01-15

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Collections table
CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Chapters table
CREATE TABLE IF NOT EXISTS chapters (
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    chapter_number INTEGER NOT NULL,
    title_en TEXT NOT NULL,
    title_ar TEXT NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
    UNIQUE(collection_id, chapter_number)
);

-- Hadiths table
CREATE TABLE IF NOT EXISTS hadiths (
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    chapter_id TEXT NOT NULL,
    hadith_number INTEGER NOT NULL,
    arabic_text TEXT NOT NULL,
    english_text TEXT NOT NULL,
    narrator TEXT NOT NULL,
    grade TEXT NOT NULL CHECK (grade IN ('Sahih', 'Hasan', 'Da''if', 'Mawdu''', 'Unknown')),
    grade_details TEXT,
    refs TEXT, -- JSON string for references
    tags TEXT, -- JSON string for tags array
    source_url TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
    FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE,
    UNIQUE(collection_id, hadith_number)
);

-- Favorites table
CREATE TABLE IF NOT EXISTS favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hadith_id TEXT NOT NULL,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes TEXT, -- Optional user notes
    FOREIGN KEY (hadith_id) REFERENCES hadiths(id) ON DELETE CASCADE,
    UNIQUE(hadith_id) -- Prevent duplicate favorites
);

-- User settings table (for app preferences)
CREATE TABLE IF NOT EXISTS user_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1), -- Single row table
    daily_notification_time TEXT DEFAULT '08:00', -- HH:MM format
    notification_enabled BOOLEAN DEFAULT TRUE,
    dark_mode BOOLEAN DEFAULT FALSE,
    arabic_font_size INTEGER DEFAULT 18,
    english_font_size INTEGER DEFAULT 16,
    last_daily_hadith_id TEXT,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_read_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (last_daily_hadith_id) REFERENCES hadiths(id)
);

-- Database metadata table
CREATE TABLE IF NOT EXISTS db_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_chapters_collection_id ON chapters(collection_id);
CREATE INDEX IF NOT EXISTS idx_chapters_number ON chapters(collection_id, chapter_number);

CREATE INDEX IF NOT EXISTS idx_hadiths_collection_id ON hadiths(collection_id);
CREATE INDEX IF NOT EXISTS idx_hadiths_chapter_id ON hadiths(chapter_id);
CREATE INDEX IF NOT EXISTS idx_hadiths_number ON hadiths(collection_id, hadith_number);
CREATE INDEX IF NOT EXISTS idx_hadiths_grade ON hadiths(grade);

CREATE INDEX IF NOT EXISTS idx_favorites_hadith_id ON favorites(hadith_id);
CREATE INDEX IF NOT EXISTS idx_favorites_added_at ON favorites(added_at);

-- Full-text search index for hadiths (for future search functionality)
CREATE VIRTUAL TABLE IF NOT EXISTS hadiths_fts USING fts5(
    hadith_id UNINDEXED,
    arabic_text,
    english_text,
    narrator,
    tags,
    content='hadiths',
    content_rowid='rowid'
);

-- Triggers to keep FTS table in sync
CREATE TRIGGER IF NOT EXISTS hadiths_fts_insert AFTER INSERT ON hadiths BEGIN
    INSERT INTO hadiths_fts(hadith_id, arabic_text, english_text, narrator, tags)
    VALUES (NEW.id, NEW.arabic_text, NEW.english_text, NEW.narrator, NEW.tags);
END;

CREATE TRIGGER IF NOT EXISTS hadiths_fts_delete AFTER DELETE ON hadiths BEGIN
    DELETE FROM hadiths_fts WHERE hadith_id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS hadiths_fts_update AFTER UPDATE ON hadiths BEGIN
    DELETE FROM hadiths_fts WHERE hadith_id = OLD.id;
    INSERT INTO hadiths_fts(hadith_id, arabic_text, english_text, narrator, tags)
    VALUES (NEW.id, NEW.arabic_text, NEW.english_text, NEW.narrator, NEW.tags);
END;

-- Initialize default user settings
INSERT OR IGNORE INTO user_settings (id) VALUES (1);

-- Insert initial database metadata
INSERT OR REPLACE INTO db_metadata (key, value) VALUES 
    ('schema_version', '1.0.0'),
    ('created_date', datetime('now')),
    ('last_migration', datetime('now'));

-- Views for common queries
CREATE VIEW IF NOT EXISTS hadith_with_details AS
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
    c.name_en as collection_name_en,
    c.name_ar as collection_name_ar,
    ch.title_en as chapter_title_en,
    ch.title_ar as chapter_title_ar,
    ch.chapter_number,
    CASE WHEN f.hadith_id IS NOT NULL THEN 1 ELSE 0 END as is_favorite
FROM hadiths h
JOIN collections c ON h.collection_id = c.id
JOIN chapters ch ON h.chapter_id = ch.id
LEFT JOIN favorites f ON h.id = f.hadith_id;

CREATE VIEW IF NOT EXISTS daily_hadith_candidates AS
SELECT 
    h.*,
    c.name_en as collection_name,
    ch.title_en as chapter_title
FROM hadiths h
JOIN collections c ON h.collection_id = c.id
JOIN chapters ch ON h.chapter_id = ch.id
WHERE h.grade IN ('Sahih', 'Hasan')
ORDER BY h.hadith_number;
