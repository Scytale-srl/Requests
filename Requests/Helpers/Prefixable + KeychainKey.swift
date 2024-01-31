//
//  Prefixable + KeychainKey.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

protocol Prefixable: RawRepresentable {
    func prefixed(_ value: String) -> String
}

extension Prefixable where RawValue == String {
    
    func doPrefix(prefix: String) -> String {
        return prefix + self.rawValue
    }
    
}

public enum KeychainKey: String, Prefixable {
    
    case clientToken
    case creationDate = "creationDate"

    func prefixed(_ value: String) -> String {
        return doPrefix(prefix: value)
    }
}
