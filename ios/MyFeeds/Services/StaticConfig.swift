import Foundation

/// Hardcoded public environment values for the iOS app.
///
/// The Rork build system regenerates `Config.swift` as a read-only "virtual
/// view" that ships with empty string literals, so it cannot be relied on at
/// runtime. These are `EXPO_PUBLIC_*` values (safe to ship in the app bundle,
/// identical to what the Expo app inlines into its JS bundle) and are the
/// authoritative source for the iOS Supabase client.
enum StaticConfig {
    static let supabaseURL = "https://wavkxbkirkyjwtnszmya.supabase.co"
    static let supabaseAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indhdmt4Ymtpcmt5and0bnN6bXlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjQxNjcsImV4cCI6MjA4NDgwMDE2N30.kBXxvf6bPTx7DuFD_PRMTmcOzKCv9rJmVonl_rTAPiE"
    static let rorkAuthURL = "https://api.rork.com"
    static let functionsURL = "https://daily-agent-digest-backend.rork.app"
    static let toolkitURL = "https://toolkit.rork.com"
    static let rorkAppKey = "rork_sk_wvt459xtxwt9u18xuzu3vazwneg43oha"
    static let projectId = "je0yu8oeyjzcpim4k10q0"
    static let teamId = "2e874b8b-59d9-4d5e-a3b8-fea2621d27f8"
}
