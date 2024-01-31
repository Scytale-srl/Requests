//
//  ARAuthenticator.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

/**
 Atomic object that manages to refresh the OAuthToken when needed.
 It must be configured with a `OAuthFlow` in order to correctly fetch and save the `OAuthToken`s.
 The closure based methods are not implemented and should not be used.
 */
@available(iOS 13.0, *)
public actor ARAuthenticator: Authenticator {
    
    public typealias ARConfiguration = OAuthFlow
    
    private var tokenStore: ARTokenManager
    private var currentToken: OAuth2Token = .init(access_token: "", refresh_token: nil,
                                                  expires_in: 0, token_type: "bearer")
    /**
     The task that is responsible for the fetch of a new access token or for a refresh.
     */
    private var fetchTask: Task<OAuth2Token, Error>?
    private var oauthFlow: ARConfiguration?
    
    /// The current authentication endpoint.
    public var authenticationEndpoint: AuthenticationEndpoint
    
    public init(tokenStore: ARTokenManager,
                baseEndpoint: AuthenticationEndpoint) {
        self.tokenStore = tokenStore
        self.authenticationEndpoint = baseEndpoint
    }
    
    /// Updates the current authentication endpoint with a new one.
    /// - Parameter authenticationEndpoint: The new authentication endpoint to be used.
    public func update(authenticationEndpoint: AuthenticationEndpoint) async {
        guard self.authenticationEndpoint != authenticationEndpoint else {
            return
        }
        self.authenticationEndpoint = authenticationEndpoint
    }
    
    /// Configures the authenticator with a new client credentials instance.
    /// This will trigger a override of the current token.
    ///
    /// If the privided `ClientCredentials` structure is the same as the current one, this method will do nothing.
    /// - Parameter parameter: The new client credentials instance that will replace the current one.
    public func configure(with parameter: ARConfiguration) async {
        
        guard !parameter.isEqualTo(otherFlow: oauthFlow) else {
            return
        }
        
        self.oauthFlow = parameter
        self.tokenStore.setPrefix(parameter.clientID)
        
        if let token = tokenStore.token(),
           let date = tokenStore.tokenDate() {
            self.currentToken = token
            self.currentToken.date = date
        } else {
            // We don't have saved any token for this client credentials, we need to fetch
            // a new token from the backend
            self.currentToken = .invalidToken
        }
    }
    
    public func tokenStore() async -> ARTokenManager {
        return self.tokenStore
    }
    
    public func authenticationFlow() async -> ARConfiguration? {
        return self.oauthFlow
    }
    
    public func validToken() async throws -> OAuth2Token {
        
        if let refreshTask = fetchTask {
            return try await refreshTask.value
        }
        
        let task = Task { () throws -> OAuth2Token in
            defer { self.fetchTask = nil }
            
            if self.currentToken.isValid {
                return currentToken
            }
            
            return try await getNewToken()
        }
        
        self.fetchTask = task
        
        return try await task.value
    }
    
    private func getNewToken() async throws -> OAuth2Token {
        
        let credentials = try await validateCredentials()
        if let refresh = currentToken.refresh_token {
            do {
                return try await refreshToken(refresh: refresh, clientId: credentials.clientID)
            } catch {
                return try await newToken(credentials: credentials)
            }
        } else {
            return try await newToken(credentials: credentials)
        }
    }
    
    public func refreshToken(refresh: String, clientId: String) async throws -> OAuth2Token {
        let flow = RefreshToken(clientID: clientId,
                                clientSecret: "",
                                refreshToken: refresh)
        let newToken = try await authenticationEndpoint.request(using: flow)
        assignNewToken(newToken)
        return newToken
    }
    
    private func newToken(credentials: ARConfiguration) async throws -> OAuth2Token {
        let newToken = try await authenticationEndpoint.request(using: credentials)
        assignNewToken(newToken)
        return newToken
    }
    
    private func assignNewToken(_ token: OAuth2Token) {
        currentToken = token
        currentToken.date = Date()
        
        if !tokenStore.saveToken(token: token) {
            print("Failed to store token.")
        }
    }
    
    
    nonisolated public func tokenStore(completion: (ARTokenManager) -> Void) {}
    
    nonisolated public func configure(with flow: ARConfiguration, completion: () -> Void) {}
    
    nonisolated public func authenticationFlow(_ completion: @escaping (ARConfiguration?) -> Void) {}
    
    nonisolated public func validToken(_ completion: @escaping (Result<OAuth2Token, Error>) -> Void) {}
}
