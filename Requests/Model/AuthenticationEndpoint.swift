//
//  AuthenticationEndpoint.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

/**
 This enum encapsulates all the requests that must be sent to retrieve or refresh an access token.
 */
public struct AuthenticationEndpoint: Resource, Equatable {
    
    public typealias Input = OAuthFlow
    
    public typealias Output = OAuth2Token
    
    public typealias OutputError = DefaultError
    
    let baseEndpoint: URL
    
    private let newTokenPath: String
    
    private let userAgent: String?
    
    public init(baseEndpoint: URL,
                path: String,
                userAgent: String? = nil) {
        self.baseEndpoint = baseEndpoint
        self.newTokenPath = path
        self.userAgent = userAgent
    }
    
    public var httpMethod: HttpMethod {
        return .post
    }
    
    public func urlRequest(using parameter: Input) throws -> URLRequest {
        
        let completeEndpoint = self.baseEndpoint.appendingPathComponent(self.newTokenPath)
        
        var urlRequest = URLRequest(url: completeEndpoint)
        urlRequest.httpMethod = self.httpMethod.rawValue
        urlRequest.setContentType(.formEncoded)
        urlRequest.httpBody = parameter.httpBody
        
        if let userAgent {
            urlRequest.setValue(userAgent, forHttpHeaderField: .userAgent)
        }
        
        return urlRequest
    }
    
}
