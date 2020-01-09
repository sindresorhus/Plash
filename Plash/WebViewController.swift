import Cocoa
import WebKit

final class WebViewController: NSViewController {
	lazy var webView: SSWebView = {
		let configuration = WKWebViewConfiguration()
		configuration.mediaTypesRequiringUserActionForPlayback = []
		configuration.allowsAirPlayForMediaPlayback = false

		let webView = SSWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.allowsBackForwardNavigationGestures = true
		webView.allowsMagnification = true
		webView.customUserAgent = SSWebView.safariUserAgent

		return webView
	}()

	override func loadView() {
		view = webView
	}

	func loadURL(_ url: URL) {
		guard !url.isFileURL else {
			// TODO: WKWebView stops loading local files after the first local file is loaded. Find a workaround.
			// TODO: Maybe use a local empty HTML file in this bundle? Or maybe recreate the web view instance each time?
			//loadURL(url: URL to local bundle here)

			delay(seconds: 1) {
				self.webView.loadFileURL(url, allowingReadAccessTo: url)
			}

			return
		}

		var request = URLRequest(url: url)
		request.cachePolicy = .reloadIgnoringLocalCacheData
		webView.load(request)
	}
}

extension WebViewController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		let nsError = error as NSError

		// Ignore `Plug-in handled load` error which can happen when you open a video directly.
		if nsError.domain == "WebKitErrorDomain", nsError.code == 204 {
			return
		}

		// Ignore the request being cancelled which can happen if the user clicks on a link while a web is loading.
		if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
			return
		}

		print("Web View - Navigation error:", error)
		NSApp.presentError(error)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		print("Web View - Content load error:", error)
		NSApp.presentError(error)
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
}
