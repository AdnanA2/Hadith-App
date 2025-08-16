# Hadith of the Day - Data Setup Guide

## Overview

This guide covers the complete data acquisition and backend setup process for the Hadith of the Day app. The setup includes collecting the Riyad us-Saliheen dataset, normalizing it into a clean JSON format, creating the SQLite database schema, and implementing import/verification scripts.

## 📁 Project Structure

```
Hadith-App/
├── data/
│   ├── schema.json              # JSON schema definition
│   ├── sample_riyad.json        # Sample normalized data
│   └── riyad.json              # Full dataset (generated)
├── database/
│   ├── schema.sql              # SQLite database schema
│   └── hadith.db              # SQLite database (generated)
├── scripts/
│   ├── fetch_sunnah_data.py    # Fetch data from Sunnah.com API
│   ├── import_data.py          # Import JSON to SQLite
│   └── verify_data.py          # Verify data integrity
├── docs/
│   └── data_setup_guide.md     # This guide
└── prd.md                      # Product Requirements Document
```

## 🎯 Dataset Requirements

### Primary Source: Riyad us-Saliheen
- **Collection**: ~1,896 authentic hadiths
- **Languages**: Arabic + English translations
- **Metadata**: Narrator, grading (Sahih/Hasan/etc.), chapter information
- **Source**: Sunnah.com API (primary), HadeethEnc (fallback)

### Data Quality Standards
- ✅ Arabic text with proper encoding
- ✅ Accurate English translations
- ✅ Narrator chain information
- ✅ Authenticity grading (Sahih, Hasan, Da'if, etc.)
- ✅ Chapter/topic categorization
- ✅ Cross-references to other collections (Bukhari, Muslim, etc.)

## 🔧 Setup Process

### Step 1: Environment Setup

1. **Install Python dependencies**:
   ```bash
   pip install requests sqlite3 pathlib
   ```

2. **Create directory structure**:
   ```bash
   mkdir -p data database scripts docs
   ```

### Step 2: Data Acquisition

#### Option A: Sunnah.com API (Recommended)

1. **Request API access**:
   - Create an issue at [sunnah-com/api](https://github.com/sunnah-com/api/issues)
   - Request access for "Hadith of the Day" app development

2. **Fetch data with API key**:
   ```bash
   cd scripts
   python fetch_sunnah_data.py --api-key YOUR_API_KEY --collection riyadussaliheen
   ```

3. **Test mode** (first 10 hadiths):
   ```bash
   python fetch_sunnah_data.py --test-mode
   ```

#### Option B: Use Sample Data (For Testing)

```bash
cd scripts
python import_data.py --sample
```

### Step 3: Data Import

1. **Import JSON to SQLite**:
   ```bash
   python import_data.py --json ../data/riyad.json --db ../database/hadith.db
   ```

2. **Force reimport** (if needed):
   ```bash
   python import_data.py --force
   ```

### Step 4: Data Verification

1. **Run comprehensive verification**:
   ```bash
   python verify_data.py --db ../database/hadith.db
   ```

2. **Generate detailed report**:
   ```bash
   python verify_data.py --report verification_report.json
   ```

## 📊 Database Schema

### Core Tables

#### Collections
```sql
CREATE TABLE collections (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_ar TEXT NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### Chapters
```sql
CREATE TABLE chapters (
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    chapter_number INTEGER NOT NULL,
    title_en TEXT NOT NULL,
    title_ar TEXT NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    FOREIGN KEY (collection_id) REFERENCES collections(id)
);
```

#### Hadiths
```sql
CREATE TABLE hadiths (
    id TEXT PRIMARY KEY,
    collection_id TEXT NOT NULL,
    chapter_id TEXT NOT NULL,
    hadith_number INTEGER NOT NULL,
    arabic_text TEXT NOT NULL,
    english_text TEXT NOT NULL,
    narrator TEXT NOT NULL,
    grade TEXT NOT NULL,
    grade_details TEXT,
    references TEXT, -- JSON
    tags TEXT, -- JSON
    source_url TEXT,
    FOREIGN KEY (collection_id) REFERENCES collections(id),
    FOREIGN KEY (chapter_id) REFERENCES chapters(id)
);
```

#### Favorites
```sql
CREATE TABLE favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hadith_id TEXT NOT NULL,
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (hadith_id) REFERENCES hadiths(id)
);
```

### Performance Indexes

```sql
-- Optimized for daily hadith selection
CREATE INDEX idx_hadiths_collection_number ON hadiths(collection_id, hadith_number);

-- Chapter-based filtering
CREATE INDEX idx_hadiths_chapter_id ON hadiths(chapter_id);

-- Grade-based filtering (Sahih/Hasan for daily selection)
CREATE INDEX idx_hadiths_grade ON hadiths(grade);

-- Full-text search (future feature)
CREATE VIRTUAL TABLE hadiths_fts USING fts5(
    hadith_id UNINDEXED,
    arabic_text,
    english_text,
    narrator,
    tags
);
```

## 🔍 Data Validation

### Automated Checks

1. **Schema Validation**:
   - All required tables exist
   - Foreign key constraints are properly set
   - Indexes are created for performance

2. **Data Integrity**:
   - No orphaned records
   - All hadiths have valid collection/chapter references
   - Required fields are not empty

3. **Quality Metrics**:
   - Arabic/English text completeness
   - Narrator information availability
   - Grading distribution analysis
   - Translation length reasonableness

4. **Content Verification**:
   - Random sampling for manual review
   - Character encoding validation
   - Grade distribution analysis

### Manual Verification Checklist

- [ ] **Sample 10 random hadiths**:
  - [ ] Arabic text displays correctly
  - [ ] English translation is accurate
  - [ ] Narrator is properly attributed
  - [ ] Grading is appropriate (Sahih/Hasan preferred)
  - [ ] Chapter assignment makes sense

- [ ] **Check grade distribution**:
  - [ ] Majority should be Sahih or Hasan
  - [ ] Da'if hadiths should be minimal
  - [ ] No Mawdu' (fabricated) hadiths

- [ ] **Verify chapter completeness**:
  - [ ] All chapters have hadiths
  - [ ] Chapter titles are meaningful
  - [ ] Proper Arabic/English chapter names

## 📋 Troubleshooting

### Common Issues

#### 1. API Access Denied
```
Error: 401 Unauthorized
```
**Solution**: Ensure you have a valid API key from Sunnah.com

#### 2. Missing Arabic Text
```
Warning: Arabic text seems too short
```
**Solution**: Check source data quality or try alternative data source

#### 3. Database Schema Errors
```
Error: no such table: hadiths
```
**Solution**: Run the import script which automatically creates the schema

#### 4. Foreign Key Violations
```
Error: FOREIGN KEY constraint failed
```
**Solution**: Ensure collections and chapters are imported before hadiths

### Data Quality Issues

#### Low Quality Score
- Review source data for completeness
- Check for encoding issues in Arabic text
- Verify narrator and grading information

#### Missing Grades
- Cross-reference with multiple hadith sources
- Default to 'Unknown' if grading unavailable
- Prioritize Sahih/Hasan hadiths for daily selection

## 📜 Licensing and Attribution

### Sunnah.com Data
- **License**: Open for non-commercial use with attribution
- **Attribution**: "Hadith data from Sunnah.com"
- **Terms**: No bulk downloading or scraping; use API only

### HadeethEnc Data
- **License**: Check their terms of use
- **Attribution**: Required as per their guidelines

### App Usage
- Always display source attribution
- Include grading information for authenticity
- Respect licensing terms in app distribution

## 🚀 Next Steps

After completing the data setup:

1. **Mobile App Integration**:
   - Bundle SQLite database with app
   - Implement daily hadith selection algorithm
   - Create offline-first data access layer

2. **Quality Improvements**:
   - Add more collections (Bukhari, Muslim)
   - Implement user feedback system
   - Regular data updates and verification

3. **Feature Enhancements**:
   - Full-text search implementation
   - Advanced filtering by narrator/grade
   - Cross-reference linking between collections

## 📞 Support

For issues with data setup:
1. Check the verification report for specific errors
2. Review the troubleshooting section
3. Ensure all dependencies are installed
4. Verify file paths and permissions

For API access issues:
1. Contact Sunnah.com through their GitHub repository
2. Consider alternative data sources
3. Use sample data for development/testing

---

*Last updated: January 2024*
*Version: 1.0.0*
