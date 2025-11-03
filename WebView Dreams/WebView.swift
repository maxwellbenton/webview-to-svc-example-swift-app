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
        
        // Disable haptic feedback and related features to prevent hapticpatternlibrary.plist errors
        configuration.preferences.isFraudulentWebsiteWarningEnabled = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Disable additional features that might trigger haptics
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.allowsPictureInPictureMediaPlayback = false
        
        // Additional iOS 14+ settings
        if #available(iOS 14.0, *) {
            configuration.limitsNavigationsToAppBoundDomains = false
        }
        
        // Add script message handler for JavaScript bridge
        contentController.add(context.coordinator, name: "iosMessageHandler")
        
        // Optional: Add any JavaScript you want to inject
        let jsCode = """
            // Send ready message when WebView loads
            window.webkit.messageHandlers.iosMessageHandler.postMessage({
                action: 'ready',
                data: 'WebView loaded successfully'
            });
            
            // Disable haptic feedback and vibration APIs to reduce errors
            if ('vibrate' in navigator) {
                navigator.vibrate = function() { return false; };
            }
        """
        
        let userScript = WKUserScript(source: jsCode, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        
        configuration.userContentController = contentController
        
        let wkWebView = WKWebView(frame: .zero, configuration: configuration)
        wkWebView.navigationDelegate = context.coordinator
        
        // Additional WebView settings for better compatibility
        wkWebView.allowsBackForwardNavigationGestures = false  // Disable to prevent haptic feedback
        wkWebView.allowsLinkPreview = false  // Disable to prevent haptic feedback
        
        // Disable scroll view features that might trigger haptics
        wkWebView.scrollView.isScrollEnabled = true
        wkWebView.scrollView.bounces = false
        wkWebView.scrollView.showsVerticalScrollIndicator = false
        wkWebView.scrollView.showsHorizontalScrollIndicator = false
        
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
                // WebView is ready - minimal logging
                break
            case "log":
                if let logMessage = data as? String {
                    print("JS: \(logMessage)")
                }
            case "launchExternalDCF":
                handleLaunchExternalDCF(data: data)
            default:
                print("JS Action: \(action)")
            }
        }
        
        private func handleLaunchExternalDCF(data: Any?) {
            guard let dataDict = data as? [String: Any],
                  let redirectURLString = dataDict["redirectURL"] as? String,
                  let redirectURL = URL(string: redirectURLString) else {
                print("Invalid launchExternalDCF data")
                return
            }
            
            DispatchQueue.main.async {
                self.presentSafariViewController(url: redirectURL)
            }
        }
        
        private func presentSafariViewController(url: URL) {
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = windowScene.windows.first(where: \.isKeyWindow) ?? windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                return
            }
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .fullScreen
            
            // Find the topmost presented view controller
            var topViewController = rootViewController
            while let presentedVC = topViewController.presentedViewController {
                topViewController = presentedVC
            }
            
            topViewController.present(safariVC, animated: true)
        }
        
        // Navigation delegate methods
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                print("Load failed: \(error.localizedDescription)")
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
