//
//  AuthenticatorError.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

public enum AuthenticatorError: Error, LocalizedError {
    
    case missingEnvironment
    case missingConfiguration
    case invalidClientCredentials
    case invalidScope
    case invalidAuthorizeUrl
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .missingEnvironment:
            return "The network environment has not been configured or is not valid."
        case .missingConfiguration:
            return "The authenticator has not been configured with the authentication endpoint."
        case .invalidClientCredentials:
            return "The provided credentials are not valid."
        case .invalidScope:
            return "The provided scope, is not valid."
        case .invalidAuthorizeUrl:
            return "Invalid authorization URL"
        case .unknown:
            return "Unknown error"
        }
    }
}
