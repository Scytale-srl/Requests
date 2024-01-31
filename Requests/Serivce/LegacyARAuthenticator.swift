//
//  LegacyARAuthenticator.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

/**
 Object that manages to refresh the OAuthToken when needed.
 It must be configured with a `OAuthFlow` in order to correctly fetch and save the `OAuthToken`s.
 The closure based methods are not implemented and should not be used.
 */
public class LegacyARAuthenticator: Authenticator {
    
    public typealias ARConfiguration = OAuthFlow
    
    private var tokenStore: ARTokenManager
    private var currentToken: OAuth2Token = .init(access_token: "", refresh_token: nil,
                                                  expires_in: 0, token_type: "bearer")
    /**
     The task that is responsible for the fetch of a new access token or for a refresh.
     */
    private var fetchTask: ((Result<OAuth2Token, Error>) -> Void)?
    private var oauthFlow: ARConfiguration?
    
    private var isTokenRequestInProgress: Bool = false
    private var pendingTokenRequests: [(Result<OAuth2Token, Error>) -> Void] = []
    
    /// The current authentication endpoint.
    public var authenticationEndpoint: AuthenticationEndpoint
    
    public init(tokenStore: ARTokenManager,
                baseEndpoint: AuthenticationEndpoint) {
        self.tokenStore = tokenStore
        self.authenticationEndpoint = baseEndpoint
    }
    
    public func tokenStore(completion: (ARTokenManager) -> Void) {
        completion(tokenStore)
    }
    
    public func configure(with flow: ARConfiguration,
                          completion: @escaping () -> Void) {
        guard !flow.isEqualTo(otherFlow: oauthFlow) else {
            completion()
            return
        }
        
        self.oauthFlow = flow
        self.tokenStore.setPrefix(flow.clientID)
        
        if let token = tokenStore.token(),
           let date = tokenStore.tokenDate() {
            self.currentToken = token
            self.currentToken.date = date
        } else {
            // We don't have saved any token for this client credentials, we need to fetch
            // a new token from the backend
            self.currentToken = .invalidToken
        }
        completion()
    }
    
    public func authenticationFlow(_ completion: (ARConfiguration?) -> Void) {
        completion(oauthFlow)
    }
    
    public func validToken(_ completion: @escaping TokenRequest) {
        if currentToken.isValid {
            completion(.success(currentToken))
            return
        }
        
        pendingTokenRequests.append(completion)
        
        if !isTokenRequestInProgress {
            isTokenRequestInProgress = true
            
            getNewToken { [weak self] result in
                self?.isTokenRequestInProgress = false
                
                // Completa tutte le richieste in attesa
                self?.pendingTokenRequests.forEach { $0(result) }
                self?.pendingTokenRequests.removeAll()
            }
        }
    }
    
    private func getNewToken(completion: @escaping TokenRequest) {
        self.validateCredentials { [weak self] result in
            guard let self = self else {
                completion(.failure(ResourceError.unexpectedError(message: "Missing instance.")))
                return
            }

            do {
                let credentials = try result.get()
                if let refreshToken = self.currentToken.refresh_token {
                    self.refreshToken(refresh: refreshToken, clientId: credentials.clientID) { [weak self] refreshResult in
                        guard let self = self else {
                            completion(.failure(ResourceError.unexpectedError(message: "Self is nil.")))
                            return
                        }

                        do {
                            let refreshedToken = try refreshResult.get()
                            completion(.success(refreshedToken))
                        } catch {
                            self.newToken(credentials: credentials) { newTokenResult in
                                do {
                                    let newToken = try newTokenResult.get()
                                    completion(.success(newToken))
                                } catch {
                                    completion(.failure(error))
                                }
                            }
                        }
                    }
                } else {
                    self.newToken(credentials: credentials) { [weak self] newTokenResult in
                        guard let self = self else {
                            completion(.failure(ResourceError.unexpectedError(message: "Self is nil.")))
                            return
                        }

                        do {
                            let newToken = try newTokenResult.get()
                            completion(.success(newToken))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public func refreshToken(refresh: String,
                             clientId: String,
                             completion: @escaping TokenRequest) {
        let flow = RefreshToken(clientID: clientId,
                                clientSecret: "",
                                refreshToken: refresh)
        authenticationEndpoint.request(using: flow) { [weak self] result in
            do {
                let newToken = try result.get()
                self?.assignNewToken(newToken)
                completion(.success(newToken))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func newToken(credentials: ARConfiguration,
                          completion: @escaping TokenRequest) {
        authenticationEndpoint.request(using: credentials) { [weak self] result in
            do {
                let token = try result.get()
                self?.assignNewToken(token)
                completion(.success(token))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func assignNewToken(_ token: OAuth2Token) {
        currentToken = token
        currentToken.date = Date()
        
        if !tokenStore.saveToken(token: token) {
            print("Failed to store token.")
        }
    }
    
    // MARK: - Not implemented for this one.
    
    /// Updates the current authentication endpoint with a new one.
    /// - Parameter authenticationEndpoint: The new authentication endpoint to be used.
    @available(iOS 13.0, *)
    public func update(authenticationEndpoint: AuthenticationEndpoint) async {}
    
    /// Configures the authenticator with a new client credentials instance.
    /// This will trigger a override of the current token.
    ///
    /// If the privided `ClientCredentials` structure is the same as the current one, this method will do nothing.
    /// - Parameter parameter: The new client credentials instance that will replace the current one.
    @available(iOS 13.0, *)
    public func configure(with parameter: ARConfiguration) async {}
    
    @available(iOS 13.0, *)
    public func tokenStore() async -> ARTokenManager {
        return self.tokenStore
    }
    
    @available(iOS 13.0, *)
    public func authenticationFlow() async -> ARConfiguration? {
        return self.oauthFlow
    }
    
    @available(iOS 13.0, *)
    public func validToken() async throws -> OAuth2Token {
        throw ResourceError.unexpectedError(message: "This method is not implemented, switch to ARAuthenticator to use structured concurrency.")
    }
}
