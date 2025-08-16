import SwiftUI

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

#Preview {
    CollectionsView()
        .environmentObject(HadithAPIService())
}
