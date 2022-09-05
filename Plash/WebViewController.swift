import Cocoa
import Combine
import WebKit
import Defaults

@MainActor
final class WebViewController: NSViewController {
	private var popupWindow: NSWindow?
	private let didLoadSubject = PassthroughSubject<Void, Error>()
	private var currentDownloadFile: URL?

	/**
	Publishes when the web view finishes loading a page.
	*/
	lazy var didLoadPublisher = didLoadSubject.eraseToAnyPublisher()

	var response: HTTPURLResponse?

	private func createWebView() -> SSWebView {
		let configuration = WKWebViewConfiguration()
		configuration.mediaTypesRequiringUserActionForPlayback = .audio
		configuration.allowsAirPlayForMediaPlayback = false
		configuration.applicationNameForUserAgent = "\(SSApp.name)/\(SSApp.version)"

		// TODO: Enable this again when https://github.com/sindresorhus/Plash/issues/9 is fixed.
//		configuration.suppressesIncrementalRendering = true

		let userContentController = WKUserContentController()
		configuration.userContentController = userContentController

		if Defaults[.muteAudio] {
			userContentController.muteAudio()
		}

		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.isDeveloperExtrasEnabled = true
		preferences.isFullscreenEnabled = true
		configuration.preferences = preferences

		let webView = SSWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.allowsBackForwardNavigationGestures = true
		webView.allowsMagnification = true
		webView.customUserAgent = SSWebView.safariUserAgent
		webView.drawsBackground = false

		userContentController.addJavaScript("document.documentElement.classList.add('is-plash-app')")

		if let website = WebsitesController.shared.current {
			if website.invertColors2 != .never {
				userContentController.invertColors(
					onlyWhenInDarkMode: website.invertColors2 == .darkMode
				)
			}

			if website.usePrintStyles {
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

			// Google Sheets shows an error message when we use the Safari or Chrome user agent.
			if website.url.hasDomain("google.com") {
				webView.customUserAgent = ""
			}
		}

		return webView
	}

	func recreateWebView() {
		webView = createWebView()
		view = webView
	}

	private(set) lazy var webView = createWebView()

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

		if let error = error {
			guard !WKWebView.canIgnoreError(error) else {
				didLoadSubject.send()
				return
			}

			didLoadSubject.send(completion: .failure(error))
			return
		}

		didLoadSubject.send()
	}
}

extension WebViewController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
		if
			Defaults[.openExternalLinksInBrowser],
			navigationAction.navigationType == .linkActivated,
			let originalURL = webView.url,
			let newURL = navigationAction.request.url,
			originalURL.host != newURL.host
		{
			// Hide Plash if it's in front of everything.
			if Defaults[.isBrowsingMode], Defaults[.bringBrowsingModeToFront] {
				Defaults[.isBrowsingMode] = false
			}

			newURL.open()

			return .cancel
		}

		if navigationAction.shouldPerformDownload {
			return .download
		}

		// Fix signing into Google Account. Google has some stupid protection against fake user agents.
		webView.customUserAgent = navigationAction.request.url?.host == "accounts.google.com" ? "" : SSWebView.safariUserAgent

		return .allow
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
		if
			navigationResponse.isForMainFrame,
			let response = navigationResponse.response as? HTTPURLResponse
		{
			self.response = response
		}

		return navigationResponse.canShowMIMEType ? .allow : .download
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		webView.centerAndAspectFillImage(mimeType: response?.mimeType)

		internalOnLoaded(nil)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		internalOnLoaded(error)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		internalOnLoaded(error)
	}

	func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
		// We're intentionally allowing this in non-browsing mode as loading the URL would fail otherwise.
		await webView.defaultAuthChallengeHandler(challenge: challenge)
	}

	func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
		download.delegate = self
	}

	func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
		download.delegate = self
	}
}

extension WebViewController: WKUIDelegate {
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		guard
			AppState.shared.isBrowsingMode,
			NSEvent.modifiers != .option
		else {
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


	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
		guard AppState.shared.isBrowsingMode else {
			return false
		}

		return await webView.defaultConfirmHandler(message: message)
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
		guard AppState.shared.isBrowsingMode else {
			return nil
		}

		return await webView.defaultPromptHandler(prompt: prompt, defaultText: defaultText)
	}

	// swiftlint:disable:next discouraged_optional_collection
	func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
		guard AppState.shared.isBrowsingMode else {
			return nil
		}

		return await webView.defaultUploadPanelHandler(parameters: parameters)
	}

	func webViewDidClose(_ webView: WKWebView) {
		if webView.window == popupWindow {
			popupWindow?.close()
			popupWindow = nil
		}
	}
}

extension WebViewController: WKDownloadDelegate {
	func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
		let url = URL.downloadsDirectory.appendingPathComponent(suggestedFilename).incrementalFilename()
		currentDownloadFile = url
		return url
	}

	func downloadDidFinish(_ download: WKDownload) {
		guard let currentDownloadFile = currentDownloadFile else {
			return
		}

		NSWorkspace.shared.bounceDownloadsFolderInDock(for: currentDownloadFile)
	}

	func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
		error.presentAsModal()
	}
}
