import Foundation
import Combine

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
