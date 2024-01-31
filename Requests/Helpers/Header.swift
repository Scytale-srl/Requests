//
//  Header.swift
//  Requests
//
//  Created by Francesco Bianco on 29/01/24.
//

import Foundation

public enum Header: String {
    case contentType = "Content-Type"
    case userAgent = "User-Agent"
    case authorization = "Authorization"
}

public extension URLRequest {
    
    mutating func setValue(_ value: String?, forHttpHeaderField field: Header) {
        setValue(value, forHTTPHeaderField: field.rawValue)
    }
    
    mutating func setContentType(_ type: ContentType) {
        setValue(type.rawValue, forHttpHeaderField: .contentType)
    }
}

public enum ContentType: String {
    case applicationJson = "application/json"
    case formEncoded = "application/x-www-form-urlencoded"
}
