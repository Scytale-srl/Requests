//
//  OAuthFlow.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

public protocol OAuthFlow {
    
    var clientID: String { get }
    var queryParameters: [String: String]? { get }
    var httpBody: Data? { get }
    
    var isValid: Bool { get }
    
    func isEqualTo(otherFlow: OAuthFlow?) -> Bool
}
