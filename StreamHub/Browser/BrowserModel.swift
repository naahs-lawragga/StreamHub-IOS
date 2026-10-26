import Foundation
import WebKit
import Combine

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var address: String
    @Published var title = "Browser"
    @Published var progress = 0.0
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var error: String?
    @Published var externalURL: URL?
    private var observations: [NSKeyValueObservation] = []

    init(url: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        webView = WKWebView(frame: .zero, configuration: configuration)
        address = url.absoluteString
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor [weak self] in self?.progress = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor [weak self] in self?.loading = view.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor [weak self] in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                Task { @MainActor [weak self] in self?.canGoForward = view.canGoForward }
            }
        ]
        load(url)
    }

    func load(_ url: URL) {
        guard WebAddress.isWebURL(url) else {
            error = "Enter a valid HTTP or HTTPS website address."
            return
        }
        error = nil
        address = url.absoluteString
        webView.load(URLRequest(url: url, timeoutInterval: 30))
    }

    func submitAddress() {
        guard let url = WebAddress.parse(address) else {
            error = "Enter a website address, such as https://example.com."
            return
        }
        load(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        address = url.absoluteString
        title = webView.title ?? url.host ?? "Browser"
        error = nil
        BrowserData.shared.record(title: title, url: url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        self.error = error.localizedDescription
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = "This page was stopped to recover memory. Tap Reload to restore it."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if WebAddress.isWebURL(url) {
            decisionHandler(.allow)
        } else if url.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else {
            // A site cannot silently launch an external app. Only user activated links prompt.
            if navigationAction.navigationType == .linkActivated,
               ["mailto", "tel"].contains(url.scheme?.lowercased() ?? "") {
                externalURL = url
            } else if navigationAction.targetFrame?.isMainFrame != false {
                error = "This link requires an external application. Open this page in Safari if needed."
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url,
           WebAddress.isWebURL(url) { load(url) }
        return nil
    }
}
