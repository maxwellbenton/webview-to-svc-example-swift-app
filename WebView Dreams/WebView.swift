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
            guard let dataDict = data as? [String: Any],
                  let redirectURLString = dataDict["redirectURL"] as? String,
                  let redirectURL = URL(string: redirectURLString) else {
                print("Invalid data for launchExternalDCF action")
                return
            }
            
            DispatchQueue.main.async {
                self.presentSafariViewController(url: redirectURL)
            }
        }
        
        private func presentSafariViewController(url: URL) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("Could not find root view controller")
                return
            }
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .fullScreen
            
            // Find the topmost presented view controller
            var topViewController = rootViewController
            while let presentedVC = topViewController.presentedViewController {
                topViewController = presentedVC
            }
            
            topViewController.present(safariVC, animated: true, completion: nil)
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
