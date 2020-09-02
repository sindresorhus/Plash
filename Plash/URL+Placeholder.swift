//
//  URL+Placeholder.swift
//  Plash
//
//  Created by Jonathan Cole on 8/31/20.
//  Copyright © 2020 Sindre Sorhus. All rights reserved.
//

import Foundation

enum URLPlaceholderError: Error, LocalizedError {
	case failedToEncodeToken(String)
	case invalidURLAfterSubstitution(String)

	var errorDescription: String? {
		switch self {
		case .failedToEncodeToken(let token):
			return "Failed to encode token “\(token)”"
		case .invalidURLAfterSubstitution(let urlString):
			return "New URL was not valid after substituting placeholders. URL string is “\(urlString)”"
		}
	}
}

extension URL {
	func replacingPlaceholder(_ placeholder: String, with replacement: String) throws -> URL {
		guard let token = placeholder.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
			throw URLPlaceholderError.failedToEncodeToken(placeholder)
		}
		let urlString = self.absoluteString
			.replacingOccurrences(of: token, with: replacement)
		guard let newURL = URL(string: urlString) else {
			throw URLPlaceholderError.invalidURLAfterSubstitution(urlString)
		}
		return newURL
	}
}
