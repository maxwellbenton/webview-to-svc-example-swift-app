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
    }
}

// Extension to add JavaScript execution methods
extension WebView {
    static func executeJavaScript(in webView: WKWebView, script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
}
