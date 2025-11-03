//
//  WebView_DreamsApp.swift
//  WebView Dreams
//
//  Created by Maxwell Benton on 9/6/25.
//

import SwiftUI

@main
struct WebView_DreamsApp: App {
    
    init() {
        // Suppress haptic pattern library warnings
        UserDefaults.standard.set(false, forKey: "WebKitSuppressesIncrementalRendering")
        UserDefaults.standard.set(false, forKey: "WebKitHapticFeedbackEnabled")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
