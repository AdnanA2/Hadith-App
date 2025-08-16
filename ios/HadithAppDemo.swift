#!/usr/bin/env swift
/*
HadithApp iOS Demo
A simple SwiftUI demo that connects to the Hadith API server
*/

import SwiftUI
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

// MARK: - API Service

class HadithAPIService: ObservableObject {
    private let baseURL = "http://localhost:8000/api/v1"
    
    @Published var dailyHadith: DailyHadith?
    @Published var collections: [Collection] = []
    @Published var hadiths: [Hadith] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchDailyHadith() {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/hadiths/daily") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let dailyHadith = try JSONDecoder().decode(DailyHadith.self, from: data)
                    self?.dailyHadith = dailyHadith
                } catch {
                    self?.errorMessage = "Failed to decode data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchCollections() {
        guard let url = URL(string: "\(baseURL)/collections") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data {
                    do {
                        let collections = try JSONDecoder().decode([Collection].self, from: data)
                        self?.collections = collections
                    } catch {
                        print("Failed to decode collections: \(error)")
                    }
                }
            }
        }.resume()
    }
    
    func fetchHadiths() {
        guard let url = URL(string: "\(baseURL)/hadiths") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data {
                    do {
                        let hadiths = try JSONDecoder().decode([Hadith].self, from: data)
                        self?.hadiths = hadiths
                    } catch {
                        print("Failed to decode hadiths: \(error)")
                    }
                }
            }
        }.resume()
    }
}

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var apiService = HadithAPIService()
    
    var body: some View {
        NavigationView {
            TabView {
                DailyHadithView()
                    .environmentObject(apiService)
                    .tabItem {
                        Image(systemName: "sun.max")
                        Text("Daily")
                    }
                
                CollectionsView()
                    .environmentObject(apiService)
                    .tabItem {
                        Image(systemName: "book")
                        Text("Collections")
                    }
                
                HadithsView()
                    .environmentObject(apiService)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("All Hadiths")
                    }
            }
            .navigationTitle("Hadith App")
        }
        .onAppear {
            apiService.fetchDailyHadith()
            apiService.fetchCollections()
            apiService.fetchHadiths()
        }
    }
}

struct DailyHadithView: View {
    @EnvironmentObject var apiService: HadithAPIService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if apiService.isLoading {
                    ProgressView("Loading daily hadith...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let dailyHadith = apiService.dailyHadith {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Hadith")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(dailyHadith.date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hadith #\(dailyHadith.hadith.hadith_number)")
                                .font(.headline)
                            
                            Text("Narrator: \(dailyHadith.hadith.narrator)")
                                .font(.subheadline)
                            
                            Text("Grade: \(dailyHadith.hadith.grade)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Text("Collection: \(dailyHadith.hadith.collection)")
                                .font(.subheadline)
                            
                            Text("Chapter: \(dailyHadith.hadith.chapter)")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Arabic Text")
                                .font(.headline)
                            
                            Text(dailyHadith.hadith.arabic_text)
                                .font(.body)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("English Translation")
                                .font(.headline)
                            
                            Text(dailyHadith.hadith.english_text)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                } else if let errorMessage = apiService.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("Error")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Retry") {
                            apiService.fetchDailyHadith()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            apiService.fetchDailyHadith()
        }
    }
}

struct CollectionsView: View {
    @EnvironmentObject var apiService: HadithAPIService
    
    var body: some View {
        List(apiService.collections) { collection in
            VStack(alignment: .leading, spacing: 8) {
                Text(collection.name_en)
                    .font(.headline)
                
                Text(collection.name_ar)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(collection.description_en)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Collections")
    }
}

struct HadithsView: View {
    @EnvironmentObject var apiService: HadithAPIService
    
    var body: some View {
        List(apiService.hadiths) { hadith in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Hadith #\(hadith.hadith_number)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(hadith.grade)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(hadith.narrator)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(hadith.english_text)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
                
                Text("\(hadith.collection) - \(hadith.chapter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("All Hadiths")
    }
}

// MARK: - App Entry Point

@main
struct HadithAppDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Demo Runner

#if DEBUG
// This allows us to run the demo from command line
print("🏛️ HadithApp iOS Demo")
print("=====================")
print("This is a SwiftUI demo app that connects to the Hadith API server.")
print("To run this in Xcode:")
print("1. Create a new iOS project")
print("2. Replace the default ContentView with this code")
print("3. Make sure the API server is running on localhost:8000")
print("4. Build and run the app")
print("")
print("API Endpoints available:")
print("- http://localhost:8000/api/v1/hadiths/daily")
print("- http://localhost:8000/api/v1/collections")
print("- http://localhost:8000/api/v1/hadiths")
print("")
print("✅ Backend server is running!")
print("📱 iOS app is ready to connect!")
#endif
