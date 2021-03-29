import Cocoa
import WebKit
import Defaults

final class WebViewController: NSViewController {
	private var popupWindow: NSWindow?

	/// Closure to call when the web view finishes loading a page.
	var onLoaded: ((Error?) -> Void)?

	var response: HTTPURLResponse?

	private func createWebView() -> SSWebView {
		let configuration = WKWebViewConfiguration()
		configuration.mediaTypesRequiringUserActionForPlayback = .audio
		configuration.allowsAirPlayForMediaPlayback = false

		// TODO: Enable this again when https://github.com/sindresorhus/Plash/issues/9 is fixed.
//		configuration.suppressesIncrementalRendering = true

		let userContentController = WKUserContentController()
		configuration.userContentController = userContentController

		userContentController.muteAudio()

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

		if let website = WebsitesController.shared.current {
			if website.invertColors {
				userContentController.invertColors()
			}

			if #available(macOS 11, *), website.usePrintStyles {
				webView.mediaType = "print"
			}

			if !website.css.trimmed.isEmpty {
				userContentController.addCSS(website.css)
			}

			if !website.javaScript.trimmed.isEmpty {
				userContentController.addJavaScript(
					"""
					try {
						\(website.javaScript)
					} catch (error) {
						alert(`Custom JavaScript threw an error:\n\n${error}`);
						throw error;
					}
					"""
				)
			}
		}

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

	// TODO: When Swift 6 is out, make this async and throw instead of using `onLoaded` handler.
	func loadURL(_ url: URL) {
		guard !url.isFileURL else {
			_ = url.accessSandboxedURLByPromptingIfNeeded()
			webView.loadFileURL(url.appendingPathComponent("index.html", isDirectory: false), allowingReadAccessTo: url)

			return
		}

		var request = URLRequest(url: url)
		request.cachePolicy = .reloadIgnoringLocalCacheData
		webView.load(request)
	}

	private func internalOnLoaded(_ error: Error?) {
		// TODO: A minor improvement would be to inject this on `DOMContentLoaded` using `WKScriptMessageHandler`.
		webView.toggleBrowsingModeClass()

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
		webView.centerAndAspectFillImage(mimeType: response?.mimeType)

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
		guard AppDelegate.shared.isBrowsingMode else {
			// This makes it so that requests to open something in a new window just opens in the existing web view.
			if navigationAction.targetFrame == nil {
				webView.load(navigationAction.request)
			}

			return nil
		}

		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.customUserAgent = WKWebView.safariUserAgent

		var styleMask: NSWindow.StyleMask = [
			.titled,
			.closable
		]

		if windowFeatures.allowsResizing?.boolValue == true {
			styleMask.insert(.resizable)
		}

		let window = NSWindow(
			contentRect: CGRect(origin: .zero, size: windowFeatures.size),
			styleMask: styleMask,
			backing: .buffered,
			defer: false
		)
		window.isReleasedWhenClosed = false // Since we manually release it.
		window.contentView = webView
		view.window?.addChildWindow(window, ordered: .above)
		window.center()
		window.makeKeyAndOrderFront(self)
		popupWindow = window

		webView.bind(\.title, to: window, at: \.title, default: "")
			.store(forTheLifetimeOf: webView)

		return webView
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

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		// We're intentionally allowing this in non-browsing mode as loading the URL would fail otherwise.

		webView.defaultAuthChallengeHandler(challenge: challenge, completion: completionHandler)
	}

	func webViewDidClose(_ webView: WKWebView) {
		if webView.window == popupWindow {
			popupWindow?.close()
			popupWindow = nil
		}
	}
}
