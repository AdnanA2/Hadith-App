#!/usr/bin/env python3
"""
Hadith of the Day App - Sunnah.com Data Fetcher
This script fetches hadith data from Sunnah.com API and normalizes it to our JSON schema
"""

import requests
import json
import time
import sys
from datetime import datetime
from pathlib import Path
import logging
from typing import Dict, List, Optional

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SunnahAPIFetcher:
    """Fetches hadith data from Sunnah.com API"""
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key
        self.base_url = "https://api.sunnah.com/v1"
        self.session = requests.Session()
        
        # Set headers if API key is provided
        if api_key:
            self.session.headers.update({
                'Authorization': f'Bearer {api_key}',
                'User-Agent': 'HadithOfTheDay/1.0'
            })
    
    def get_collections(self) -> List[Dict]:
        """Fetch all available collections"""
        try:
            response = self.session.get(f"{self.base_url}/collections")
            response.raise_for_status()
            
            collections = response.json()
            logger.info(f"Found {len(collections)} collections")
            return collections
        except requests.RequestException as e:
            logger.error(f"Error fetching collections: {e}")
            return []
    
    def get_collection_info(self, collection_name: str) -> Optional[Dict]:
        """Get detailed information about a specific collection"""
        try:
            response = self.session.get(f"{self.base_url}/collections/{collection_name}")
            response.raise_for_status()
            
            collection_info = response.json()
            logger.info(f"Retrieved info for collection: {collection_name}")
            return collection_info
        except requests.RequestException as e:
            logger.error(f"Error fetching collection info for {collection_name}: {e}")
            return None
    
    def get_books(self, collection_name: str) -> List[Dict]:
        """Fetch books/chapters for a collection"""
        try:
            response = self.session.get(f"{self.base_url}/collections/{collection_name}/books")
            response.raise_for_status()
            
            books = response.json()
            logger.info(f"Found {len(books)} books in {collection_name}")
            return books
        except requests.RequestException as e:
            logger.error(f"Error fetching books for {collection_name}: {e}")
            return []
    
    def get_hadiths(self, collection_name: str, book_number: int, limit: int = 50, offset: int = 0) -> List[Dict]:
        """Fetch hadiths from a specific book"""
        try:
            params = {
                'limit': limit,
                'offset': offset
            }
            
            response = self.session.get(
                f"{self.base_url}/collections/{collection_name}/books/{book_number}/hadiths",
                params=params
            )
            response.raise_for_status()
            
            data = response.json()
            hadiths = data.get('hadiths', [])
            logger.info(f"Retrieved {len(hadiths)} hadiths from book {book_number}")
            return hadiths
        except requests.RequestException as e:
            logger.error(f"Error fetching hadiths from book {book_number}: {e}")
            return []
    
    def get_all_hadiths_for_collection(self, collection_name: str, max_hadiths: Optional[int] = None) -> List[Dict]:
        """Fetch all hadiths for a collection"""
        all_hadiths = []
        
        # Get books first
        books = self.get_books(collection_name)
        if not books:
            return []
        
        for book in books:
            book_number = book.get('bookNumber', book.get('book_number'))
            if not book_number:
                continue
            
            logger.info(f"Fetching hadiths from book {book_number}: {book.get('book', {}).get('name', 'Unknown')}")
            
            offset = 0
            limit = 50
            
            while True:
                hadiths = self.get_hadiths(collection_name, book_number, limit, offset)
                if not hadiths:
                    break
                
                all_hadiths.extend(hadiths)
                
                # Check if we've reached the max limit
                if max_hadiths and len(all_hadiths) >= max_hadiths:
                    all_hadiths = all_hadiths[:max_hadiths]
                    break
                
                # If we got fewer hadiths than the limit, we've reached the end
                if len(hadiths) < limit:
                    break
                
                offset += limit
                
                # Be respectful to the API
                time.sleep(0.5)
        
        logger.info(f"Total hadiths fetched: {len(all_hadiths)}")
        return all_hadiths

class DataNormalizer:
    """Normalizes Sunnah.com API data to our JSON schema"""
    
    def __init__(self):
        self.grade_mapping = {
            'sahih': 'Sahih',
            'hasan': 'Hasan',
            'da\'if': 'Da\'if',
            'daif': 'Da\'if',
            'mawdu': 'Mawdu\'',
            'unknown': 'Unknown'
        }
    
    def normalize_grade(self, grade_text: str) -> str:
        """Normalize hadith grade"""
        if not grade_text:
            return 'Unknown'
        
        grade_lower = grade_text.lower().strip()
        
        # Check for exact matches first
        if grade_lower in self.grade_mapping:
            return self.grade_mapping[grade_lower]
        
        # Check for partial matches
        for key, value in self.grade_mapping.items():
            if key in grade_lower:
                return value
        
        # Default fallback
        return 'Unknown'
    
    def extract_narrator(self, hadith_data: Dict) -> str:
        """Extract narrator from hadith data"""
        # Try different possible fields for narrator
        narrator_fields = ['narrator', 'rawi', 'chain', 'isnad']
        
        for field in narrator_fields:
            if field in hadith_data and hadith_data[field]:
                narrator = hadith_data[field]
                if isinstance(narrator, str):
                    return narrator.strip()
                elif isinstance(narrator, dict) and 'name' in narrator:
                    return narrator['name'].strip()
        
        return 'Unknown'
    
    def normalize_collection(self, collection_data: Dict) -> Dict:
        """Normalize collection data"""
        return {
            'id': collection_data.get('name', '').lower().replace(' ', '-'),
            'name_en': collection_data.get('title', collection_data.get('name', 'Unknown')),
            'name_ar': collection_data.get('arabicTitle', collection_data.get('arabic_name', '')),
            'description_en': collection_data.get('summary', ''),
            'description_ar': collection_data.get('arabicSummary', '')
        }
    
    def normalize_chapter(self, book_data: Dict, collection_id: str) -> Dict:
        """Normalize chapter/book data"""
        book_info = book_data.get('book', {})
        
        return {
            'id': f"{collection_id}-ch-{book_data.get('bookNumber', '000'):03d}",
            'collection_id': collection_id,
            'chapter_number': book_data.get('bookNumber', 0),
            'title_en': book_info.get('name', 'Unknown Chapter'),
            'title_ar': book_info.get('arabicName', ''),
            'description_en': book_info.get('intro', ''),
            'description_ar': book_info.get('arabicIntro', '')
        }
    
    def normalize_hadith(self, hadith_data: Dict, collection_id: str, chapter_id: str) -> Dict:
        """Normalize hadith data"""
        hadith_number = hadith_data.get('hadithNumber', hadith_data.get('number', 0))
        
        # Extract texts
        arabic_text = ''
        english_text = ''
        
        if 'hadith' in hadith_data:
            hadith_content = hadith_data['hadith']
            if isinstance(hadith_content, list) and hadith_content:
                # Sometimes hadith content is in an array
                hadith_content = hadith_content[0]
            
            if isinstance(hadith_content, dict):
                arabic_text = hadith_content.get('arab', hadith_content.get('arabic', ''))
                english_text = hadith_content.get('text', hadith_content.get('english', ''))
        
        # Fallback to direct fields
        if not arabic_text:
            arabic_text = hadith_data.get('arabicText', hadith_data.get('arab', ''))
        if not english_text:
            english_text = hadith_data.get('text', hadith_data.get('english', ''))
        
        # Extract references
        references = {}
        if 'references' in hadith_data:
            refs = hadith_data['references']
            if isinstance(refs, list):
                for ref in refs:
                    if isinstance(ref, dict):
                        book_name = ref.get('book', '').lower()
                        hadith_num = ref.get('hadith', '')
                        
                        # Map common book names
                        if 'bukhari' in book_name:
                            references['bukhari'] = str(hadith_num)
                        elif 'muslim' in book_name:
                            references['muslim'] = str(hadith_num)
                        elif 'abu dawud' in book_name or 'abu-dawud' in book_name:
                            references['abu_dawud'] = str(hadith_num)
                        elif 'tirmidhi' in book_name:
                            references['tirmidhi'] = str(hadith_num)
                        elif 'nasai' in book_name or 'nasa\'i' in book_name:
                            references['nasai'] = str(hadith_num)
                        elif 'ibn majah' in book_name:
                            references['ibn_majah'] = str(hadith_num)
        
        return {
            'id': f"{collection_id.split('-')[0]}-{hadith_number:03d}",
            'collection_id': collection_id,
            'chapter_id': chapter_id,
            'hadith_number': hadith_number,
            'arabic_text': arabic_text.strip(),
            'english_text': english_text.strip(),
            'narrator': self.extract_narrator(hadith_data),
            'grade': self.normalize_grade(hadith_data.get('grade', '')),
            'grade_details': hadith_data.get('gradeDetails', ''),
            'references': references,
            'tags': [],  # Tags would need to be added manually or from additional sources
            'source_url': f"https://sunnah.com/{collection_id.replace('-', '')}:{hadith_number}"
        }

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Fetch hadith data from Sunnah.com API')
    parser.add_argument('--api-key', help='Sunnah.com API key (optional)')
    parser.add_argument('--collection', default='riyadussaliheen', help='Collection name to fetch')
    parser.add_argument('--output', default='../data/riyad.json', help='Output JSON file path')
    parser.add_argument('--max-hadiths', type=int, help='Maximum number of hadiths to fetch')
    parser.add_argument('--test-mode', action='store_true', help='Fetch only first 10 hadiths for testing')
    
    args = parser.parse_args()
    
    # Initialize fetcher
    fetcher = SunnahAPIFetcher(args.api_key)
    normalizer = DataNormalizer()
    
    # Test mode - limit hadiths
    if args.test_mode:
        args.max_hadiths = 10
    
    try:
        # Get collection info
        logger.info(f"Fetching collection info for: {args.collection}")
        collection_info = fetcher.get_collection_info(args.collection)
        
        if not collection_info:
            logger.error(f"Could not find collection: {args.collection}")
            sys.exit(1)
        
        # Normalize collection
        normalized_collection = normalizer.normalize_collection(collection_info)
        collection_id = normalized_collection['id']
        
        # Get books/chapters
        logger.info("Fetching books/chapters...")
        books = fetcher.get_books(args.collection)
        
        if not books:
            logger.error("No books found for collection")
            sys.exit(1)
        
        # Normalize chapters
        normalized_chapters = []
        for book in books:
            chapter = normalizer.normalize_chapter(book, collection_id)
            normalized_chapters.append(chapter)
        
        # Get all hadiths
        logger.info("Fetching hadiths...")
        all_hadiths = fetcher.get_all_hadiths_for_collection(args.collection, args.max_hadiths)
        
        if not all_hadiths:
            logger.error("No hadiths found")
            sys.exit(1)
        
        # Normalize hadiths
        normalized_hadiths = []
        for hadith_data in all_hadiths:
            # Find the appropriate chapter
            book_number = hadith_data.get('bookNumber', 1)
            chapter_id = f"{collection_id}-ch-{book_number:03d}"
            
            hadith = normalizer.normalize_hadith(hadith_data, collection_id, chapter_id)
            normalized_hadiths.append(hadith)
        
        # Create final JSON structure
        output_data = {
            'metadata': {
                'version': '1.0.0',
                'source': 'Sunnah.com API',
                'collection_name': normalized_collection['name_en'],
                'total_hadiths': len(normalized_hadiths),
                'last_updated': datetime.now().isoformat(),
                'license': 'Open for non-commercial use with attribution'
            },
            'collections': [normalized_collection],
            'chapters': normalized_chapters,
            'hadiths': normalized_hadiths
        }
        
        # Write to file
        script_dir = Path(__file__).parent
        output_path = script_dir / args.output
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"Data successfully written to: {output_path}")
        logger.info(f"Collections: {len(output_data['collections'])}")
        logger.info(f"Chapters: {len(output_data['chapters'])}")
        logger.info(f"Hadiths: {len(output_data['hadiths'])}")
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
