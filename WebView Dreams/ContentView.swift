//
//  ContentView.swift
//  WebView Dreams
//
//  Created by Maxwell Benton on 9/6/25.
//

import SwiftUI
import WebKit

struct ContentView: View {
    let websiteURL = URL(string: "https://maxwellbenton.github.io/test-merchant/")!

    var body: some View {
        VStack {
            WebView(url: websiteURL)
                .edgesIgnoringSafeArea(.all) // Extend the WebView to the screen edges
        }
    }
    
    
}

#Preview {
    ContentView()
}
