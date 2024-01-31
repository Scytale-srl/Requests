//
//  ResourceError.swift
//  Requests
//
//  Created by Francesco Bianco on 29/01/24.
//

import Foundation

/// An error that could occurr while trying to get a resource.
public enum ResourceError: Error, LocalizedError {
    
    case badResponse(responseCode: Int, message: String?)
    case apiError(resultError: any DebuggableError)
    case notHttpResponse
    case badURL
    case badDataType
    case unexpectedError(message: String)
    
    public var localizedDescription: String {
        switch self {
        case .badResponse(let responseCode, let message):
            var base = "Received an error response from the server\n[error code: \(responseCode)"
            if let message {
                base += " " + message
            }
            base += "]"
            return base
        case .notHttpResponse:
            return "Received a non HTTP response."
        case .badURL:
            return "The url cannot be built."
        case .badDataType:
            return "Unknown data type."
        case .unexpectedError(message: let message):
            return "An unexpected error occurred: \(message)"
        case let .apiError(resultError):
            return "\(resultError.errorCode) " + (resultError.debugMessage ?? "Unknown error message.")
        }
    }
    
    public var errorDescription: String? {
        localizedDescription
    }
}
