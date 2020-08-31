//
//  URLPlaceholder.swift
//  Plash
//
//  Created by Jonathan Cole on 8/31/20.
//  Copyright © 2020 Sindre Sorhus. All rights reserved.
//

import Foundation

/**
Defines a placeholder to be substituted out for a string in a URL.
*/
struct URLPlaceholder {
	/// The string that will be replaced by the output of `transform()`.
	var token: String
	/// The string this function returns will replace any occurrences of `token`.
	var transform: () -> String

	/**
	Replace any instances of `token` with the value returned by `transform()`.
	*/
	func appliedTo(url: URL) throws -> URL {
		guard let token = self.token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
			throw URLPlaceholderError.failedToEncodeToken(self.token)
		}
		let urlString = url.absoluteString
			.replacingOccurrences(of: token, with: self.transform())
		guard let newURL = URL(string: urlString) else {
			throw URLPlaceholderError.invalidURLAfterSubstitution(urlString)
		}
		return newURL
	}
}

enum URLPlaceholderError: Error, LocalizedError {
	case failedToEncodeToken(String)
	case invalidURLAfterSubstitution(String)

	var errorDescription: String? {
		switch self {
		case .failedToEncodeToken(let token):
			return "Failed to encode token \"\(token)\""
		case .invalidURLAfterSubstitution(let urlString):
			return "New URL was not valid after substituting placeholders. URL string is \"\(urlString)\""
		}
	}
}

extension URL {
	func replacingPlaceholder(_ placeholder: URLPlaceholder) throws -> URL {
		try placeholder.appliedTo(url: self)
	}
}
