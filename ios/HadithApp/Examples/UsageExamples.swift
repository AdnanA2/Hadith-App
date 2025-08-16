import Foundation
import Combine
import SwiftUI

/// Examples demonstrating how to use the Auth + API layer in your iOS app
class UsageExamples {
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Authentication Examples
    
    /// Example: User signup flow
    func signupExample() {
        let authManager = AuthenticationManager.shared
        
        authManager.signup(
            email: "user@example.com",
            password: "SecurePassword123",
            fullName: "John Doe"
        )
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("✅ Signup successful")
                case .failure(let error):
                    print("❌ Signup failed: \(error.localizedDescription)")
                }
            },
            receiveValue: { response in
                print("🎉 Welcome \(response.user.full_name ?? "User")!")
                print("🔑 Token expires in: \(response.data.expires_in) seconds")
            }
        )
        .store(in: &cancellables)
    }
    
    /// Example: User login flow
    func loginExample() {
        let authManager = AuthenticationManager.shared
        
        authManager.login(email: "user@example.com", password: "SecurePassword123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Login failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Login successful!")
                    print("👤 User: \(response.user.email)")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Check authentication status on app launch
    func checkAuthStatusExample() {
        let authManager = AuthenticationManager.shared
        
        // AuthenticationManager automatically checks status on init
        // You can observe the published properties
        authManager.$isAuthenticated
            .sink { isAuthenticated in
                if isAuthenticated {
                    print("✅ User is authenticated")
                } else {
                    print("❌ User is not authenticated")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Hadith Service Examples
    
    /// Example: Get daily hadith
    func getDailyHadithExample() {
        let hadithService = HadithService.shared
        
        hadithService.getDailyHadith()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to get daily hadith: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    let hadith = response.data
                    print("📖 Daily Hadith (\(response.date)):")
                    print("🏛️ Collection: \(hadith.collectionDisplayName)")
                    print("📝 English: \(hadith.shortText)")
                    print("⭐ Grade: \(hadith.grade.displayName)")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Search hadiths
    func searchHadithsExample() {
        let hadithService = HadithService.shared
        
        hadithService.searchHadiths(query: "prayer", page: 1, pageSize: 10)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Search failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("🔍 Found \(response.data.count) hadiths about prayer")
                    
                    for hadith in response.data {
                        print("• \(hadith.formattedNumber): \(hadith.shortText)")
                    }
                    
                    if let meta = response.meta {
                        print("📄 Page \(meta.page) of \(meta.total_pages)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Browse collections
    func browseCollectionsExample() {
        let hadithService = HadithService.shared
        
        hadithService.getCollections()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to get collections: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("📚 Available Collections:")
                    
                    for collection in response.data {
                        print("• \(collection.displayName)")
                        print("  \(collection.displayDescription)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Get hadiths by grade
    func getHadithsByGradeExample() {
        let hadithService = HadithService.shared
        
        hadithService.getHadithsByGrade(grade: .sahih, page: 1, pageSize: 5)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to get Sahih hadiths: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("⭐ Sahih Hadiths:")
                    
                    for hadith in response.data {
                        print("• \(hadith.narrator): \(hadith.shortText)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Favorites Examples
    
    /// Example: Add hadith to favorites
    func addToFavoritesExample() {
        let hadithService = HadithService.shared
        
        // First get a hadith, then favorite it
        hadithService.getRandomHadith()
            .flatMap { response in
                let hadith = response.data
                print("📖 Adding to favorites: \(hadith.shortText)")
                
                return hadithService.addFavorite(
                    hadithId: hadith.id,
                    notes: "This hadith resonated with me"
                )
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to add favorite: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("⭐ Added to favorites!")
                    print("📝 Notes: \(response.data.notes ?? "None")")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Get user's favorites
    func getFavoritesExample() {
        let hadithService = HadithService.shared
        
        hadithService.getFavorites()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed to get favorites: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("⭐ Your Favorites (\(response.data.count) items):")
                    
                    for favorite in response.data {
                        print("• \(favorite.hadith.shortText)")
                        print("  Added: \(favorite.formattedDate)")
                        if let notes = favorite.notes {
                            print("  Notes: \(notes)")
                        }
                        print("")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling Examples
    
    /// Example: Handling authentication errors
    func authErrorHandlingExample() {
        let authManager = AuthenticationManager.shared
        
        authManager.login(email: "invalid@example.com", password: "wrongpassword")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        switch error {
                        case .invalidCredentials:
                            print("❌ Invalid email or password")
                        case .networkError(let message):
                            print("❌ Network error: \(message)")
                        case .serverError(let message):
                            print("❌ Server error: \(message)")
                        default:
                            print("❌ Unknown error: \(error.localizedDescription)")
                        }
                    }
                },
                receiveValue: { _ in
                    print("✅ Login successful")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Using global error handler
    func globalErrorHandlingExample() {
        let hadithService = HadithService.shared
        let errorHandler = ErrorHandler.shared
        
        hadithService.getHadiths()
            .handleErrors(context: "Loading hadiths", shouldDisplay: true)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { response in
                    print("✅ Loaded \(response.data.count) hadiths")
                }
            )
            .store(in: &cancellables)
        
        // Observe errors
        errorHandler.$currentError
            .compactMap { $0 }
            .sink { error in
                print("🚨 Global error: \(error.title) - \(error.message)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Advanced Examples
    
    /// Example: Chaining API calls
    func chainedAPICallsExample() {
        let hadithService = HadithService.shared
        
        // Get collections -> Get hadiths from first collection -> Add first hadith to favorites
        hadithService.getCollections()
            .compactMap { response in
                response.data.first?.id
            }
            .flatMap { collectionId in
                hadithService.getHadithsByCollection(collectionId: collectionId, pageSize: 1)
            }
            .compactMap { response in
                response.data.first?.id
            }
            .flatMap { hadithId in
                hadithService.addFavorite(hadithId: hadithId, notes: "Auto-favorited from first collection")
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Chained operation failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Successfully favorited hadith from first collection")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Example: Pagination handling
    func paginationExample() {
        let hadithService = HadithService.shared
        var allHadiths: [Hadith] = []
        
        func loadPage(_ page: Int) {
            hadithService.getHadiths(page: page, pageSize: 20)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Failed to load page \(page): \(error.localizedDescription)")
                        }
                    },
                    receiveValue: { response in
                        allHadiths.append(contentsOf: response.data)
                        print("📄 Loaded page \(page), total hadiths: \(allHadiths.count)")
                        
                        // Load next page if available
                        if let meta = response.meta, meta.has_next {
                            loadPage(page + 1)
                        } else {
                            print("✅ Finished loading all hadiths: \(allHadiths.count) total")
                        }
                    }
                )
                .store(in: &cancellables)
        }
        
        loadPage(1)
    }
    
    /// Example: Retry with exponential backoff
    func retryExample() {
        let hadithService = HadithService.shared
        
        hadithService.getDailyHadith()
            .retryOnNetworkError(maxRetries: 3, baseDelay: 1.0)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Failed after retries: \(error.localizedDescription)")
                    }
                },
                receiveValue: { response in
                    print("✅ Got daily hadith (possibly after retries)")
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI Integration Examples

/// Example SwiftUI Views using the Auth + API layer
struct SwiftUIExamples {
    
    /// Example: Authentication status view
    struct AuthStatusView: View {
        @ObservedObject var authManager = AuthenticationManager.shared
        
        var body: some View {
            VStack {
                if authManager.isLoading {
                    ProgressView("Checking authentication...")
                } else if authManager.isAuthenticated {
                    Text("Welcome, \(authManager.currentUser?.full_name ?? "User")!")
                        .foregroundColor(.green)
                    
                    Button("Logout") {
                        authManager.logout()
                    }
                } else {
                    Text("Not authenticated")
                        .foregroundColor(.red)
                    
                    NavigationLink("Login", destination: LoginView())
                }
            }
        }
    }
    
    /// Example: Login form
    struct LoginView: View {
        @ObservedObject var authManager = AuthenticationManager.shared
        @State private var email = ""
        @State private var password = ""
        @State private var cancellables = Set<AnyCancellable>()
        
        var body: some View {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Login") {
                    login()
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                
                if let error = authManager.authError {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Login")
        }
        
        private func login() {
            authManager.login(email: email, password: password)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in
                        // Navigation handled by AuthStatusView
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// Example: Daily hadith view
    struct DailyHadithView: View {
        @State private var dailyHadith: Hadith?
        @State private var isLoading = false
        @State private var error: HadithServiceError?
        @State private var cancellables = Set<AnyCancellable>()
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading daily hadith...")
                        .frame(maxWidth: .infinity)
                } else if let hadith = dailyHadith {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Hadith")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(hadith.collectionDisplayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(hadith.english_text)
                            .font(.body)
                        
                        Text(hadith.narrator)
                            .font(.caption)
                            .fontStyle(.italic)
                        
                        HStack {
                            Text(hadith.grade.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            Button("♡ Favorite") {
                                // Add to favorites
                            }
                        }
                    }
                } else if let error = error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .onAppear {
                loadDailyHadith()
            }
        }
        
        private func loadDailyHadith() {
            isLoading = true
            error = nil
            
            HadithService.shared.getDailyHadith()
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
                        if case .failure(let err) = completion {
                            error = err
                        }
                    },
                    receiveValue: { response in
                        dailyHadith = response.data
                    }
                )
                .store(in: &cancellables)
        }
    }
}
