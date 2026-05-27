import Foundation

enum SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_REF.supabase.co"
    static let anonKey    = "YOUR_ANON_KEY_HERE"

    static var isConfigured: Bool {
        !projectURL.contains("YOUR_PROJECT_REF")
    }
}
