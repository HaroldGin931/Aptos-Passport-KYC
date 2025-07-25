//
//  Aptos_Passport_KYCApp.swift
//  Aptos Passport KYC
//
//  Created by Harold on 2025/7/16.
//

import SwiftUI

@main
struct Aptos_Passport_KYCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Asynchronously check authentication status when app starts
                    print("🚀 App startup, starting authentication status check...")
                    AuthenticationStateManager.shared.refreshAuthenticationState()
                }
        }
    }
}
