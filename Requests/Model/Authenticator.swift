//
//  Authenticator.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

// MARK: -Authenticator

/**
 An object that is capable to authenticate a request based on a ARConfiguration.
 */
public protocol Authenticator {
    
    typealias TokenRequest = (Result<OAuth2Token, Error>) -> Void
    
    associatedtype AuthFlow
    
    /**
     Returns the current `ARTokenStore` that is used to manage the stored auth tokens.
     */
    @available(iOS 13.0, *)
    func tokenStore() async -> ARTokenManager
    
    /**
     Returns the current `ARTokenStore` that is used to manage the stored auth tokens.
     */
    func tokenStore(completion: @escaping (ARTokenManager) -> Void)
    
    /**
     Configures the authenticator with a new auhentication flow.
     */
    @available(iOS 13.0, *)
    func configure(with parameter: AuthFlow) async
    
    /**
     Configures the authenticator with a new authentication flow.
     */
    func configure(with flow: AuthFlow, completion: @escaping () -> Void)
    
    /**
     The current authentication flow that is held by the authenticator.
     - Returns The current authentication flow.
     */
    @available(iOS 13.0, *)
    func authenticationFlow() async -> AuthFlow?
    
    /// The current authentication flow that is held by the authenticator.
    /// - Parameter completion: asynchronous closure that returns the current authentication flow or an error if it doesn't exist.
    func authenticationFlow(_ completion: @escaping (AuthFlow?) -> Void)
    
    /**
     Asynchronously returns a valid token if exists, otherwise it will fetch a new one using the provided auth flow.
     */
    @available(iOS 13.0, *)
    func validToken() async throws -> OAuth2Token
    
    /**
     Asynchronously returns a valid token if exists, otherwise it will fetch a new one using the provided auth flow.
     */
    func validToken(_ completion: @escaping TokenRequest)
}

public extension Authenticator where AuthFlow == OAuthFlow {
    
    /**
     Given the current credentials (returned by the `configuration()`), this method does a validation, to ensure that they satisfy some minimum requirements.
     For example, not being nil or having all the fields non empty.
     */
    @available(iOS 13.0, *)
    func validateCredentials() async throws -> AuthFlow {
        
        async let configuration = authenticationFlow()
        guard let clientCredentials = await configuration else {
            throw AuthenticatorError.missingConfiguration
        }
        
        guard clientCredentials.isValid else {
            throw AuthenticatorError.invalidClientCredentials
        }
        
        return clientCredentials
    }
    
    /**
     Given the current credentials (returned by the `configuration()`), this method does a validation, to ensure that they satisfy some minimum requirements.
     For example, not being nil or having all the fields non empty.
     */
    func validateCredentials(_ completion: @escaping (Result<AuthFlow, Error>) -> Void) {
        self.authenticationFlow { flow in
            if let flow {
                guard flow.isValid else {
                    completion(.failure(AuthenticatorError.invalidClientCredentials))
                    return
                }
                completion(.success(flow))
            } else {
                completion(.failure(AuthenticatorError.missingConfiguration))
            }
        }
    }
    
}
