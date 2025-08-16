# 📖 PRD: Hadith of the Day (iOS-first Mobile App)

---

## 1. Overview
**Product:** Hadith of the Day  
**Platform:** iOS (MVP)
**Target Users:** English-speaking American Muslims seeking daily authentic hadith reminders with clarity and simplicity.  
**Core Value:** Provide one authentic hadith per day (Arabic + English) with option to explore and share more hadiths.  

The app balances **authenticity, readability, and engagement**: every hadith shows its source and grade, users can easily save/share, and the design is minimal but modern.

---

## 2. Goals & Objectives
- Deliver one hadith daily with notification and date badge.  
- Allow endless scrolling through Riyad us-Saliheen (~1900 hadiths).  
- Enable favorites/bookmarks for personal collections.  
- Support sharing both as text and styled image cards.  
- Ensure offline-first experience (bundled SQLite DB).  
- Provide Arabic + English side-by-side.  
- Filter hadiths by chapter/topic.  
- Prioritize authenticity (chain, source, grading always shown).  
- Offer a clean, minimal UI with dark mode and streaks for habit-building.  

---

## 3. Competitive Analysis
**Existing Apps & Insights:**  
- **Hadith of the Day (official):** daily reminder + community brand. Users like push reminders but app design is dated.  
- **My Daily Hadith:** supports 6 languages, daily push, text/image sharing. Users value offline use and customization.  
- **Hadith Collection (IRD/Greentech):** 41k+ hadiths, all major books, bookmarks, search, grades. Users praise comprehensiveness and authenticity.  
- **Hadithi (AI-powered):** focuses on chain of narration and references with sleek UI.  

**What users like:**  
- Easy daily reminders.  
- Offline access.  
- Clean Arabic + English text.  
- Shareable as image.  

**What users dislike:**  
- Broken sharing features.  
- Poor readability.  
- Lack of dark mode.  
- Missing authenticity info.  

**Opportunity:** Build a modern, reliable, offline-first daily hadith app with a strong focus on authenticity and UI quality.  

---

## 4. Dataset & Content
**Primary Collection (MVP):** Riyad us-Saliheen (~1900 hadiths).  

**Sources:**  
- [Sunnah.com API & offline dumps](https://api.sunnah.com/).  
- Open-source Hadith JSON DB (includes Riyad us-Saliheen in Arabic + English).  
- [HadeethEnc API](https://hadeethenc.com/) (multi-language, authentic translations).  

**Requirements:**  
- Arabic + English for each hadith.  
- Narrator, source collection, book number.  
- Authenticity grading (Sahih, Hasan, etc.).  
- Chapter/topic titles.  

---

## 5. Tech Stack
**Mobile Framework:**  
- **Flutter (recommended):** smooth UI, offline DB integration, cross-platform scalability.  
- **React Native (optional):** if JS/React expertise is stronger.  

**Database:**  
- Local SQLite with pre-populated dataset.  
- Indexed for fast scrolling & chapter filters.  
- Favorites table for bookmarks.  
- FTS (Full-text Search) in future.  

**Backend:**  
- None required for MVP (offline-first).  
- Future: backend sync for new collections, streak storage, and user accounts.  

---

## 6. Core Features
- Daily Hadith Card with date badge.  
- Endless Scroll Mode for full collection.  
- Save/Favorite hadiths.  
- Share options:  
  - Text (copy/paste Arabic + English).  
  - Styled image card with watermark.  
- Notifications: daily hadith at user-set time.  
- Offline access: all hadiths pre-bundled.  
- Filters: by chapter/topic.  
- Authenticity display: narrator, source, grading.  
- Dark mode & font controls.  
- Streak tracking for daily habit.  

---

## 7. Database Schema (SQLite)

**Collections Table**  
- id  
- name_en  
- name_ar  

**Chapters Table**  
- id  
- collection_id  
- title_en  
- title_ar  

**Hadiths Table**  
- id  
- collection_id  
- chapter_id  
- number  
- arabic_text  
- english_text  
- narrator  
- grade  
- refs  

**Favorites Table**  
- id  
- hadith_id  
- added_at  

Indexes: `(collection_id, number)` for scrolling, `(chapter_id)` for topic filters.  

---

## 8. UI/UX Principles
- Minimal card-based design with focus on text.  
- Dark mode for night reading.  
- Clean typography:  
  - Arabic → Scheherazade, KFGQPC Uthmanic.  
  - English → serif or clean sans-serif.  
- Streak counter for habit-building.  
- Shareable image cards styled for Instagram/Twitter.  
- Optional subtle Islamic art (geometric backgrounds, motifs).  
- Accessibility: adjustable font size, uncluttered layout, large touch targets.  

---

## 9. Roadmap
**MVP (3–4 months):**  
- Riyad us-Saliheen.  
- Daily card + notifications.  
- Endless scroll.  
- Favorites.  
- Text/image share.  
- Offline DB.  
- Dark mode.  
- Streaks.  

**Phase 2 (next 6 months):**  
- Add Bulugh al-Maram, Nawawi’s 40.  
- Search function (SQLite FTS).  
- iOS/Android widgets.  
- Additional languages (Urdu, French).  

**Phase 3 (Year 1):**  
- Add Sahih Bukhari, Sahih Muslim.  
- User accounts + cloud sync (favorites, streaks).  
- Quizzes/educational mode.  
- Advanced streaks & badges.  

---

## 10. Risks & Mitigations
- **Translation licensing:** use open datasets (sunnah.com, hadith JSON), attribute sources.  
- **Authenticity:** always display source + grading; exclude weak/fabricated hadith.  
- **Performance:** pre-indexed SQLite, lazy loading.  
- **User misinterpretation:** include chapter titles, optional disclaimer.  
- **Scalability:** modular DB schema for adding collections.  
- **Monetization:** avoid intrusive ads; donation/supporter model.  

---

## 11. Success Metrics
- Daily active users (DAU).  
- Retention (7-day & 30-day).  
- Average streak length.  
- Number of favorites saved.  
- Share events (image vs text).  
- App store ratings and reviews.  

---

## 12. Task Breakdown
**Phase 1 — Data & Backend Foundations**  
- Collect Riyad us-Saliheen dataset (Arabic + English).  
- Normalize into JSON → import into SQLite.  
- Verify grading metadata.  

**Phase 2 — Core Features**  
- Daily hadith algorithm.  
- Endless scroll feed.  
- Favorites system.  
- Sharing system (text + image).  
- Notifications.  

**Phase 3 — UI/UX**  
- Card layout.  
- Dark mode & font controls.  
- Favorites screen.  
- Filters by topic.  
- Streaks.  

**Phase 4 — Testing & Launch**  
- Unit tests + offline stress tests.  
- User testing on readability.  
- App Store prep: privacy policy, screenshots, listing.  

---

## 13. Research Prompt
To guide deeper validation, run this master prompt:  

> *“I am building an iOS-first app called Hadith of the Day. It shows a daily hadith from Riyad us-Saliheen, supports endless scrolling, favorites, sharing, offline mode, notifications, and dark mode. Users are English-speaking American Muslims. Provide a detailed analysis of: competitor apps (strengths/weaknesses), best open datasets for hadith (Arabic + English), optimal offline-first mobile stack, database schema, best UX practices for spiritual reminder apps, risks (translation licensing, performance, authenticity), and roadmap for scaling to multiple collections. Include references where possible.”*  
