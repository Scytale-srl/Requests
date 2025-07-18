//
//  Dictionary + urlEncoded.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

public extension Dictionary where Key == String, Value == String {
    var urlEncoded: Data? {
        let encodedString = self.compactMap { (key, value) -> String? in
            guard !value.isEmpty else { return nil }

            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlFormEncodedValueAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlFormEncodedValueAllowed) ?? value

            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        return encodedString.data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlFormEncodedValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return allowed
    }()
}
