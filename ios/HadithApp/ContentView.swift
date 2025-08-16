import SwiftUI

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

#Preview {
    ContentView()
}
