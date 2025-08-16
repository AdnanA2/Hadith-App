#!/usr/bin/env python3
"""
Hadith of the Day App - Data Verification Script
This script verifies the integrity and quality of imported hadith data
"""

import sqlite3
import json
import sys
import random
from pathlib import Path
from datetime import datetime
import logging
from typing import Dict, List, Tuple, Optional

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DataVerifier:
    """Verifies hadith data integrity and quality"""
    
    def __init__(self, db_path: str):
        self.db_path = Path(db_path)
        self.conn = None
        self.verification_results = {
            'passed': [],
            'warnings': [],
            'errors': [],
            'stats': {}
        }
    
    def connect_db(self):
        """Connect to SQLite database"""
        try:
            if not self.db_path.exists():
                logger.error(f"Database file not found: {self.db_path}")
                return False
            
            self.conn = sqlite3.connect(self.db_path)
            self.conn.row_factory = sqlite3.Row  # Enable column access by name
            logger.info(f"Connected to database: {self.db_path}")
            return True
        except sqlite3.Error as e:
            logger.error(f"Database connection error: {e}")
            return False
    
    def close_db(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
    
    def add_result(self, category: str, message: str):
        """Add verification result"""
        self.verification_results[category].append({
            'timestamp': datetime.now().isoformat(),
            'message': message
        })
        
        if category == 'errors':
            logger.error(message)
        elif category == 'warnings':
            logger.warning(message)
        else:
            logger.info(message)
    
    def verify_schema(self) -> bool:
        """Verify database schema exists and is correct"""
        try:
            # Check if all required tables exist
            required_tables = ['collections', 'chapters', 'hadiths', 'favorites', 'user_settings', 'db_metadata']
            
            cursor = self.conn.execute("""
                SELECT name FROM sqlite_master 
                WHERE type='table' AND name NOT LIKE 'sqlite_%'
            """)
            existing_tables = [row[0] for row in cursor.fetchall()]
            
            missing_tables = set(required_tables) - set(existing_tables)
            if missing_tables:
                self.add_result('errors', f"Missing tables: {', '.join(missing_tables)}")
                return False
            
            self.add_result('passed', f"All required tables exist: {', '.join(existing_tables)}")
            
            # Check for indexes
            cursor = self.conn.execute("""
                SELECT name FROM sqlite_master 
                WHERE type='index' AND name NOT LIKE 'sqlite_%'
            """)
            indexes = [row[0] for row in cursor.fetchall()]
            
            if indexes:
                self.add_result('passed', f"Found {len(indexes)} indexes for performance optimization")
            else:
                self.add_result('warnings', "No custom indexes found - this may affect performance")
            
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Schema verification error: {e}")
            return False
    
    def verify_data_counts(self) -> bool:
        """Verify data counts and relationships"""
        try:
            # Get counts for each table
            tables = ['collections', 'chapters', 'hadiths', 'favorites']
            counts = {}
            
            for table in tables:
                cursor = self.conn.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                counts[table] = count
                self.verification_results['stats'][f'{table}_count'] = count
            
            # Log counts
            for table, count in counts.items():
                self.add_result('passed', f"{table.title()}: {count:,} records")
            
            # Verify relationships
            if counts['collections'] == 0:
                self.add_result('errors', "No collections found")
                return False
            
            if counts['chapters'] == 0:
                self.add_result('errors', "No chapters found")
                return False
            
            if counts['hadiths'] == 0:
                self.add_result('errors', "No hadiths found")
                return False
            
            # Check for orphaned records
            cursor = self.conn.execute("""
                SELECT COUNT(*) FROM chapters c
                LEFT JOIN collections col ON c.collection_id = col.id
                WHERE col.id IS NULL
            """)
            orphaned_chapters = cursor.fetchone()[0]
            
            if orphaned_chapters > 0:
                self.add_result('errors', f"Found {orphaned_chapters} chapters with invalid collection references")
                return False
            
            cursor = self.conn.execute("""
                SELECT COUNT(*) FROM hadiths h
                LEFT JOIN collections col ON h.collection_id = col.id
                WHERE col.id IS NULL
            """)
            orphaned_hadiths_col = cursor.fetchone()[0]
            
            if orphaned_hadiths_col > 0:
                self.add_result('errors', f"Found {orphaned_hadiths_col} hadiths with invalid collection references")
                return False
            
            cursor = self.conn.execute("""
                SELECT COUNT(*) FROM hadiths h
                LEFT JOIN chapters ch ON h.chapter_id = ch.id
                WHERE ch.id IS NULL
            """)
            orphaned_hadiths_ch = cursor.fetchone()[0]
            
            if orphaned_hadiths_ch > 0:
                self.add_result('errors', f"Found {orphaned_hadiths_ch} hadiths with invalid chapter references")
                return False
            
            self.add_result('passed', "All foreign key relationships are valid")
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Data count verification error: {e}")
            return False
    
    def verify_hadith_quality(self, sample_size: int = 10) -> bool:
        """Verify quality of hadith data"""
        try:
            # Get total hadith count
            cursor = self.conn.execute("SELECT COUNT(*) FROM hadiths")
            total_hadiths = cursor.fetchone()[0]
            
            if total_hadiths == 0:
                self.add_result('errors', "No hadiths to verify")
                return False
            
            # Sample random hadiths
            actual_sample_size = min(sample_size, total_hadiths)
            cursor = self.conn.execute("""
                SELECT * FROM hadiths 
                ORDER BY RANDOM() 
                LIMIT ?
            """, (actual_sample_size,))
            
            sample_hadiths = cursor.fetchall()
            
            quality_issues = 0
            
            for hadith in sample_hadiths:
                hadith_id = hadith['id']
                issues = []
                
                # Check for empty required fields
                if not hadith['arabic_text'].strip():
                    issues.append("Missing Arabic text")
                
                if not hadith['english_text'].strip():
                    issues.append("Missing English text")
                
                if not hadith['narrator'].strip() or hadith['narrator'] == 'Unknown':
                    issues.append("Missing or unknown narrator")
                
                if not hadith['grade'] or hadith['grade'] == 'Unknown':
                    issues.append("Missing or unknown grade")
                
                # Check text quality
                arabic_text = hadith['arabic_text']
                english_text = hadith['english_text']
                
                if len(arabic_text) < 20:
                    issues.append("Arabic text seems too short")
                
                if len(english_text) < 20:
                    issues.append("English text seems too short")
                
                # Check for common encoding issues
                if '?' in arabic_text or '�' in arabic_text:
                    issues.append("Possible Arabic text encoding issues")
                
                if issues:
                    quality_issues += 1
                    self.add_result('warnings', f"Hadith {hadith_id} quality issues: {', '.join(issues)}")
            
            quality_score = ((actual_sample_size - quality_issues) / actual_sample_size) * 100
            self.verification_results['stats']['quality_score'] = quality_score
            
            if quality_score >= 90:
                self.add_result('passed', f"Data quality score: {quality_score:.1f}% (Excellent)")
            elif quality_score >= 80:
                self.add_result('passed', f"Data quality score: {quality_score:.1f}% (Good)")
            elif quality_score >= 70:
                self.add_result('warnings', f"Data quality score: {quality_score:.1f}% (Fair)")
            else:
                self.add_result('errors', f"Data quality score: {quality_score:.1f}% (Poor)")
                return False
            
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Quality verification error: {e}")
            return False
    
    def verify_grading_distribution(self) -> bool:
        """Verify hadith grading distribution"""
        try:
            cursor = self.conn.execute("""
                SELECT grade, COUNT(*) as count 
                FROM hadiths 
                GROUP BY grade 
                ORDER BY count DESC
            """)
            
            grade_distribution = cursor.fetchall()
            
            if not grade_distribution:
                self.add_result('errors', "No grading data found")
                return False
            
            total_hadiths = sum(row[1] for row in grade_distribution)
            
            self.add_result('passed', "Hadith grading distribution:")
            for grade, count in grade_distribution:
                percentage = (count / total_hadiths) * 100
                self.add_result('passed', f"  {grade}: {count:,} ({percentage:.1f}%)")
                self.verification_results['stats'][f'grade_{grade.lower()}_count'] = count
                self.verification_results['stats'][f'grade_{grade.lower()}_percentage'] = percentage
            
            # Check for reasonable distribution
            sahih_hasan_count = sum(count for grade, count in grade_distribution if grade in ['Sahih', 'Hasan'])
            sahih_hasan_percentage = (sahih_hasan_count / total_hadiths) * 100
            
            if sahih_hasan_percentage >= 70:
                self.add_result('passed', f"Good authenticity: {sahih_hasan_percentage:.1f}% Sahih/Hasan hadiths")
            elif sahih_hasan_percentage >= 50:
                self.add_result('warnings', f"Moderate authenticity: {sahih_hasan_percentage:.1f}% Sahih/Hasan hadiths")
            else:
                self.add_result('warnings', f"Low authenticity: {sahih_hasan_percentage:.1f}% Sahih/Hasan hadiths")
            
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Grading verification error: {e}")
            return False
    
    def verify_chapter_distribution(self) -> bool:
        """Verify chapter distribution and completeness"""
        try:
            cursor = self.conn.execute("""
                SELECT 
                    ch.title_en,
                    ch.chapter_number,
                    COUNT(h.id) as hadith_count
                FROM chapters ch
                LEFT JOIN hadiths h ON ch.id = h.chapter_id
                GROUP BY ch.id, ch.title_en, ch.chapter_number
                ORDER BY ch.chapter_number
            """)
            
            chapter_data = cursor.fetchall()
            
            if not chapter_data:
                self.add_result('errors', "No chapter data found")
                return False
            
            empty_chapters = 0
            total_chapters = len(chapter_data)
            
            self.add_result('passed', f"Chapter distribution ({total_chapters} chapters):")
            
            for title, chapter_num, hadith_count in chapter_data[:10]:  # Show first 10
                if hadith_count == 0:
                    empty_chapters += 1
                    self.add_result('warnings', f"  Chapter {chapter_num}: '{title}' - No hadiths")
                else:
                    self.add_result('passed', f"  Chapter {chapter_num}: '{title}' - {hadith_count} hadiths")
            
            if total_chapters > 10:
                self.add_result('passed', f"  ... and {total_chapters - 10} more chapters")
            
            if empty_chapters > 0:
                self.add_result('warnings', f"Found {empty_chapters} empty chapters")
            else:
                self.add_result('passed', "All chapters contain hadiths")
            
            # Calculate average hadiths per chapter
            total_hadiths = sum(row[2] for row in chapter_data)
            avg_hadiths = total_hadiths / total_chapters if total_chapters > 0 else 0
            
            self.verification_results['stats']['avg_hadiths_per_chapter'] = avg_hadiths
            self.add_result('passed', f"Average hadiths per chapter: {avg_hadiths:.1f}")
            
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Chapter verification error: {e}")
            return False
    
    def verify_database_metadata(self) -> bool:
        """Verify database metadata"""
        try:
            cursor = self.conn.execute("SELECT key, value FROM db_metadata")
            metadata = {row[0]: row[1] for row in cursor.fetchall()}
            
            if not metadata:
                self.add_result('warnings', "No database metadata found")
                return True
            
            self.add_result('passed', "Database metadata:")
            for key, value in metadata.items():
                self.add_result('passed', f"  {key}: {value}")
                self.verification_results['stats'][f'metadata_{key}'] = value
            
            # Check for required metadata
            required_keys = ['schema_version', 'last_import_date', 'total_hadiths']
            missing_keys = [key for key in required_keys if key not in metadata]
            
            if missing_keys:
                self.add_result('warnings', f"Missing metadata keys: {', '.join(missing_keys)}")
            
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Metadata verification error: {e}")
            return False
    
    def spot_check_translations(self, count: int = 5) -> bool:
        """Perform spot check on translations"""
        try:
            # Get random hadiths with both Arabic and English text
            cursor = self.conn.execute("""
                SELECT id, hadith_number, arabic_text, english_text, narrator, grade
                FROM hadiths 
                WHERE length(arabic_text) > 0 AND length(english_text) > 0
                ORDER BY RANDOM() 
                LIMIT ?
            """, (count,))
            
            sample_hadiths = cursor.fetchall()
            
            if not sample_hadiths:
                self.add_result('errors', "No hadiths available for spot check")
                return False
            
            self.add_result('passed', f"Spot check of {len(sample_hadiths)} random hadiths:")
            
            for hadith in sample_hadiths:
                hadith_id = hadith[0]
                hadith_number = hadith[1]
                arabic_text = hadith[2]
                english_text = hadith[3]
                narrator = hadith[4]
                grade = hadith[5]
                
                self.add_result('passed', f"\n--- Hadith {hadith_number} ({hadith_id}) ---")
                self.add_result('passed', f"Narrator: {narrator}")
                self.add_result('passed', f"Grade: {grade}")
                self.add_result('passed', f"Arabic: {arabic_text[:100]}{'...' if len(arabic_text) > 100 else ''}")
                self.add_result('passed', f"English: {english_text[:100]}{'...' if len(english_text) > 100 else ''}")
            
            return True
            
        except sqlite3.Error as e:
            self.add_result('errors', f"Spot check error: {e}")
            return False
    
    def run_full_verification(self, spot_check_count: int = 10, quality_sample: int = 20) -> bool:
        """Run complete verification process"""
        logger.info("Starting comprehensive data verification...")
        
        if not self.connect_db():
            return False
        
        try:
            all_passed = True
            
            # Run all verification checks
            checks = [
                ("Schema verification", lambda: self.verify_schema()),
                ("Data counts and relationships", lambda: self.verify_data_counts()),
                ("Hadith quality check", lambda: self.verify_hadith_quality(quality_sample)),
                ("Grading distribution", lambda: self.verify_grading_distribution()),
                ("Chapter distribution", lambda: self.verify_chapter_distribution()),
                ("Database metadata", lambda: self.verify_database_metadata()),
                ("Translation spot check", lambda: self.spot_check_translations(spot_check_count))
            ]
            
            for check_name, check_func in checks:
                logger.info(f"Running {check_name}...")
                if not check_func():
                    all_passed = False
            
            # Generate summary
            self.generate_summary()
            
            return all_passed
            
        finally:
            self.close_db()
    
    def generate_summary(self):
        """Generate verification summary"""
        results = self.verification_results
        
        logger.info("\n" + "="*60)
        logger.info("VERIFICATION SUMMARY")
        logger.info("="*60)
        
        logger.info(f"✅ Passed: {len(results['passed'])}")
        logger.info(f"⚠️  Warnings: {len(results['warnings'])}")
        logger.info(f"❌ Errors: {len(results['errors'])}")
        
        if results['stats']:
            logger.info("\nKey Statistics:")
            for key, value in results['stats'].items():
                if isinstance(value, float):
                    logger.info(f"  {key}: {value:.2f}")
                else:
                    logger.info(f"  {key}: {value:,}" if isinstance(value, int) else f"  {key}: {value}")
        
        if results['errors']:
            logger.info("\n❌ Critical Issues:")
            for error in results['errors']:
                logger.info(f"  • {error['message']}")
        
        if results['warnings']:
            logger.info("\n⚠️  Warnings:")
            for warning in results['warnings'][:5]:  # Show first 5 warnings
                logger.info(f"  • {warning['message']}")
            
            if len(results['warnings']) > 5:
                logger.info(f"  ... and {len(results['warnings']) - 5} more warnings")
        
        logger.info("="*60)
    
    def save_report(self, output_path: str):
        """Save verification report to JSON file"""
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(self.verification_results, f, ensure_ascii=False, indent=2)
            
            logger.info(f"Verification report saved to: {output_path}")
        except Exception as e:
            logger.error(f"Error saving report: {e}")

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Verify hadith database integrity and quality')
    parser.add_argument('--db', default='../database/hadith.db', help='SQLite database path')
    parser.add_argument('--spot-check', type=int, default=10, help='Number of hadiths for spot check')
    parser.add_argument('--quality-sample', type=int, default=20, help='Sample size for quality check')
    parser.add_argument('--report', help='Save detailed report to JSON file')
    
    args = parser.parse_args()
    
    # Resolve path relative to script location
    script_dir = Path(__file__).parent
    db_path = script_dir / args.db
    
    # Create verifier and run
    verifier = DataVerifier(db_path)
    success = verifier.run_full_verification(args.spot_check, args.quality_sample)
    
    # Save report if requested
    if args.report:
        report_path = script_dir / args.report
        verifier.save_report(report_path)
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
