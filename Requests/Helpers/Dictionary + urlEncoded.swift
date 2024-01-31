//
//  Dictionary + urlEncoded.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

public extension Dictionary where Value == String, Key == String {
    
    var urlEncoded: Data? {
        return self.compactMap { touple in
            
            guard !touple.value.isEmpty else { return nil }
            
            return "\(touple.key)=\(touple.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? touple.value)"
        }.joined(separator: "&").data(using: .utf8)
    }
    
}
