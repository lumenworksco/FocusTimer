import Foundation

enum SupabaseConfig {
    static let projectURL = "https://bbxfhpsdjlqdudiunxuc.supabase.co"
    static let anonKey    = "sb_publishable_M76gk2_hFNF7ClQtNfS6tA_DnWXACSn"

    static var isConfigured: Bool {
        !projectURL.contains("YOUR_PROJECT_REF")
    }
}
