import SwiftUI

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

#Preview {
    HadithsView()
        .environmentObject(HadithAPIService())
}
