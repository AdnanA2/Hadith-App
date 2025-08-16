import Foundation

// MARK: - Data Models

struct Hadith: Codable, Identifiable {
    let id: String
    let hadith_number: Int
    let narrator: String
    let grade: String
    let arabic_text: String
    let english_text: String
    let collection: String
    let chapter: String
}

struct DailyHadith: Codable {
    let hadith: Hadith
    let date: String
}

struct Collection: Codable, Identifiable {
    let id: String
    let name_en: String
    let name_ar: String
    let description_en: String
}
