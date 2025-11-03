import SwiftUI
import WebKit
import SafariServices

struct WebView: UIViewRepresentable {
    let url: URL
    let onJavaScriptMessage: ((String, Any?) -> Void)?
    
    init(url: URL, onJavaScriptMessage: ((String, Any?) -> Void)? = nil) {
        self.url = url
        self.onJavaScriptMessage = onJavaScriptMessage
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Enhanced configuration for better compatibility
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = false
        
        // Disable haptic feedback to prevent hapticpatternlibrary.plist errors
        if #available(iOS 13.0, *) {
            configuration.preferences.isFraudulentWebsiteWarningEnabled = false
        }
        
        // Add script message handler for JavaScript bridge
        contentController.add(context.coordinator, name: "iosMessageHandler")
        
        // Optional: Add any JavaScript you want to inject
        let jsCode = """
            window.webkit.messageHandlers.iosMessageHandler.postMessage({
                action: 'ready',
                data: 'WebView loaded successfully'
            });
        """
        
        let userScript = WKUserScript(source: jsCode, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        
        configuration.userContentController = contentController
        
        let wkWebView = WKWebView(frame: .zero, configuration: configuration)
        wkWebView.navigationDelegate = context.coordinator
        
        // Additional WebView settings for better compatibility
        wkWebView.allowsBackForwardNavigationGestures = true
        wkWebView.allowsLinkPreview = true
        
        // Set custom user agent to help with compatibility
        wkWebView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        let request = URLRequest(url: url)
        wkWebView.load(request)
        return wkWebView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // You can add logic here to update the WKWebView if needed,
        // for example, if the URL changes.
        if uiView.url != url {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "iosMessageHandler" else { return }
            
            if let messageBody = message.body as? [String: Any],
               let action = messageBody["action"] as? String {
                let data = messageBody["data"]
                
                // Call the callback if provided
                parent.onJavaScriptMessage?(action, data)
                
                // Handle common actions
                handleJavaScriptMessage(action: action, data: data)
            }
        }
        
        private func handleJavaScriptMessage(action: String, data: Any?) {
            switch action {
            case "ready":
                print("WebView ready: \(data ?? "No data")")
            case "log":
                if let logMessage = data as? String {
                    print("JS Log: \(logMessage)")
                }
            case "launchExternalDCF":
                handleLaunchExternalDCF(data: data)
            default:
                print("Received JS message - Action: \(action), Data: \(data ?? "No data")")
            }
        }
        
        private func handleLaunchExternalDCF(data: Any?) {
            print("handleLaunchExternalDCF called with data: \(data ?? "nil")")
            
            guard let dataDict = data as? [String: Any] else {
                print("Error: data is not a dictionary. Type: \(type(of: data))")
                return
            }
            
            guard let redirectURLString = dataDict["redirectURL"] as? String else {
                print("Error: redirectURL not found or not a string. Available keys: \(dataDict.keys)")
                return
            }
            
            guard let redirectURL = URL(string: redirectURLString) else {
                print("Error: Invalid URL string: \(redirectURLString)")
                return
            }
            
            print("Valid URL found: \(redirectURL). Dispatching to main thread...")
            
            DispatchQueue.main.async {
                self.presentSafariViewController(url: redirectURL)
            }
        }
        
        private func presentSafariViewController(url: URL) {
            print("Attempting to present Safari VC for URL: \(url)")
            
            // Try multiple approaches to find the right view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                print("Could not find active window scene")
                return
            }
            
            guard let window = windowScene.windows.first(where: \.isKeyWindow) ?? windowScene.windows.first else {
                print("Could not find key window")
                return
            }
            
            guard let rootViewController = window.rootViewController else {
                print("Could not find root view controller")
                return
            }
            
            print("Found root view controller: \(type(of: rootViewController))")
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .fullScreen
            
            // Find the topmost presented view controller
            var topViewController = rootViewController
            while let presentedVC = topViewController.presentedViewController {
                topViewController = presentedVC
                print("Found presented VC: \(type(of: presentedVC))")
            }
            
            print("Will present Safari VC on: \(type(of: topViewController))")
            
            topViewController.present(safariVC, animated: true) {
                print("Safari VC presented successfully")
            }
        }
        
        // Navigation delegate methods for additional control
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("Started loading: \(webView.url?.absoluteString ?? "")")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Finished loading: \(webView.url?.absoluteString ?? "")")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ PROVISIONAL LOAD FAILED")
            print("URL: \(webView.url?.absoluteString ?? "No URL")")
            print("Error: \(error.localizedDescription)")
            print("Error Code: \((error as NSError).code)")
            print("Error Domain: \((error as NSError).domain)")
            
            // Check for specific error types
            let nsError = error as NSError
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                print("🔍 Issue: No internet connection")
            case NSURLErrorCannotConnectToHost:
                print("🔍 Issue: Cannot connect to host - check network/firewall")
            case NSURLErrorTimedOut:
                print("🔍 Issue: Request timed out")
            case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                print("🔍 Issue: ATS blocking connection - check Info.plist settings")
            case NSURLErrorServerCertificateUntrusted:
                print("🔍 Issue: SSL certificate issue")
            case NSURLErrorCancelled:
                print("🔍 Issue: Request was cancelled")
            default:
                print("🔍 Issue: Other network error (\(nsError.code))")
            }
            
            // Try to reload with a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🔄 Attempting to reload...")
                webView.reload()
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ NAVIGATION FAILED")
            print("URL: \(webView.url?.absoluteString ?? "No URL")")
            print("Error: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("🔍 Navigation policy check for: \(navigationAction.request.url?.absoluteString ?? "No URL")")
            decisionHandler(.allow)
        }
    }
}

// Extension to add JavaScript execution methods
extension WebView {
    static func executeJavaScript(in webView: WKWebView, script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
}
