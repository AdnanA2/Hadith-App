import SwiftUI

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

#Preview {
    DailyHadithView()
        .environmentObject(HadithAPIService())
}
