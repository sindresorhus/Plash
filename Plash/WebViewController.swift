import Cocoa
import WebKit
import Defaults

final class WebViewController: NSViewController {
	/// Closure to call when the web view finishes loading a page.
	var onLoaded: ((Error?) -> Void)?

	var response: HTTPURLResponse?

	private func createWebView() -> SSWebView {
		let configuration = WKWebViewConfiguration()
		configuration.mediaTypesRequiringUserActionForPlayback = .audio
		configuration.allowsAirPlayForMediaPlayback = false
		configuration.suppressesIncrementalRendering = true

		let userContentController = WKUserContentController()
		configuration.userContentController = userContentController

		userContentController.muteAudio()

		if Defaults[.invertColors] {
			userContentController.invertColors()
		}

		if !Defaults[.customCSS].trimmed.isEmpty {
			userContentController.addCSS(Defaults[.customCSS])
		}

		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.isDeveloperExtrasEnabled = true
		configuration.preferences = preferences

		let webView = SSWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.allowsBackForwardNavigationGestures = true
		webView.allowsMagnification = true
		webView.customUserAgent = SSWebView.safariUserAgent
		webView.drawsBackground = false

		return webView
	}

	func recreateWebView() {
		webView = createWebView()
		view = webView
	}

	lazy var webView = createWebView()

	override func loadView() {
		view = webView
	}

	func loadURL(_ url: URL) {
		guard !url.isFileURL else {
			_ = url.accessSandboxedURLByPromptingIfNeeded()
			self.webView.loadFileURL(url.appendingPathComponent("index.html"), allowingReadAccessTo: url)

			return
		}

		var request = URLRequest(url: url)
		request.cachePolicy = .reloadIgnoringLocalCacheData
		webView.load(request)
	}

	private func internalOnLoaded(_ error: Error?) {
		onLoaded?(error)
	}
}

extension WebViewController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if
			navigationResponse.isForMainFrame,
			let response = navigationResponse.response as? HTTPURLResponse
		{
			self.response = response
		}

		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		webView.centerImage(mimeType: response?.mimeType)

		internalOnLoaded(nil)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		let nsError = error as NSError

		// Ignore `Plug-in handled load` error which can happen when you open a video directly.
		if nsError.domain == "WebKitErrorDomain", nsError.code == 204 {
			internalOnLoaded(nil)
			return
		}

		// Ignore the request being cancelled which can happen if the user clicks on a link while a website is loading.
		if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
			internalOnLoaded(nil)
			return
		}

		print("Web View - Navigation error:", error)
		internalOnLoaded(error)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		print("Web View - Content load error:", error)
		internalOnLoaded(error)
	}
}

extension WebViewController: WKUIDelegate {
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		// This makes it so that requests to open something in a new window just opens in the existing web view.
		if navigationAction.targetFrame == nil {
			webView.load(navigationAction.request)
		}

		return nil
	}

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
		guard AppDelegate.shared.isBrowsingMode else {
			completionHandler()
			return
		}

		webView.defaultAlertHandler(message: message, completion: completionHandler)
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
		guard AppDelegate.shared.isBrowsingMode else {
			completionHandler(false)
			return
		}

		webView.defaultConfirmHandler(message: message, completion: completionHandler)
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
		guard AppDelegate.shared.isBrowsingMode else {
			completionHandler(nil)
			return
		}

		webView.defaultPromptHandler(prompt: prompt, defaultText: defaultText, completion: completionHandler)
	}

	// swiftlint:disable:next discouraged_optional_collection
	func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
		guard AppDelegate.shared.isBrowsingMode else {
			completionHandler(nil)
			return
		}

		webView.defaultUploadPanelHandler(parameters: parameters, completion: completionHandler)
	}
}
