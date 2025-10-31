//
//  ContentView.swift
//  WebView Dreams
//
//  Created by Maxwell Benton on 9/6/25.
//

import SwiftUI
import WebKit

struct ContentView: View {
    let websiteURL = URL(string: "http://127.0.0.1:8080")!

    var body: some View {
        VStack {
            WebView(url: websiteURL) { action, data in
                // Handle JavaScript messages here
                print("Received JS message - Action: \(action), Data: \(data ?? "No data")")
                
                switch action {
                case "ready":
                    print("WebView loaded and ready!")
                case "launchExternalDCF":
                    print("LaunchExternalDCF triggered with data: \(data ?? "No data")")
                default:
                    print("Unknown action: \(action)")
                }
            }
            .edgesIgnoringSafeArea(.all) // Extend the WebView to the screen edges
        }
    }
    
    
}

#Preview {
    ContentView()
}
