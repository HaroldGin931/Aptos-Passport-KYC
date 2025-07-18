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
                    // 应用启动时异步检查认证状态
                    print("🚀 应用启动，开始检查认证状态...")
                    AuthenticationStateManager.shared.refreshAuthenticationState()
                }
        }
    }
}
