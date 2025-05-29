//
//  Resource.swift
//  Requests
//
//  Created by Francesco Bianco on 29/01/24.
//

import Foundation

/**
 Represents a resource that requires to be downloaded from a remote service (REST for example).
 */
public protocol Resource {
    
    /**
     The object that is used to build the request for the needed resource.
     */
    associatedtype Input
    
    /**
     The output that is expected to be returned when requesting the resource.
     */
    associatedtype Output
    
    /**
     The type that is expected to be returned by the API in case of an error.
     */
    associatedtype OutputError: DebuggableError, Codable
     
    /**
     The HTTP method that is required to retreive/consume the resource.
     */
    var httpMethod: HttpMethod { get }
    
    /// Builds the URLRequest that's necessary to obtain the desired `Output`.
    /// - Parameter parameter: The parameter that is going to be used to build the request.
    /// - Returns: The built resource request.
    func urlRequest(using parameter: Input) throws -> URLRequest
}

@available(iOS 13.0, *)
public extension Resource where Output: Codable {
    
    /// Requests the desired resource asynchronously.
    /// - Parameter parameter: The input parameter that is necessary to build the URLRequest.
    /// - Returns: Returns the received data decoded into the expected output type, or throws an error.
    func request(using parameter: Input,
                 userAgent: String = "AuthenticatedRequests iOS",
                 urlConfiguration: URLSessionConfiguration? = nil) async throws -> Output {
        
        let request = try await urlRequest(with: parameter, userAgent: userAgent)
        let session = Self.session(urlConfiguration: urlConfiguration)
        
        let (data, response): (Data, URLResponse)
        if #available(iOS 15.0, macOS 12.0, *) {
            (data, response) = try await session.data(for: request)
        } else {
            (data, response) = try await session.data(using: request)
        }
        
        // We check if the Task got cancelled to avoid decoding data for nothing.
        try Task.checkCancellation()
        
        // We first validate the URLResponse that we received in order to check if everything went ok.
        try Self.validateResponse(response, data: data)
        
        return try Self.decodeData(data: data)
    }
    
}

public extension Resource where Output: Codable {
    
    func request(using parameter: Input,
                 userAgent: String = "Requests for iOS",
                 urlSessionConfiguration: URLSessionConfiguration? = nil,
                 completion: @escaping (Result<Output, ResourceError>) -> ()) {
        self.urlRequest(with: parameter, userAgent: userAgent) { result in
            do {
                let request = try result.get()
                let session = Self.session(urlConfiguration: urlSessionConfiguration)
                let dataTask = session.dataTask(with: request) { data, response, error in
                    guard let data,
                          let response else {
                        completion(.failure(.unexpectedError(message: error?.localizedDescription ?? "Unexpected error while fetching \(String(describing: request.url))")))
                        return
                    }
                    
                    do {
                        try Self.validateResponse(response, data: data)
                        let output = try Self.decodeData(data: data)
                        completion(.success(output))
                    } catch {
                        if let resourceError = error as? ResourceError {
                            completion(.failure(resourceError))
                        } else {
                            completion(.failure(.unexpectedError(message: error.localizedDescription)))
                        }
                    }
                }
                dataTask.resume()
            } catch {
                completion(.failure(.unexpectedError(message: error.localizedDescription)))
            }
        }
    }
    
}

@available(iOS 13.0, *)
public extension Resource where Output == URL {
    
    /// Requests the desired resource asynchronously.
    /// - Parameter parameter: The input parameter that is necessary to build the URLRequest.
    /// - Returns: Returns the received data decoded into the expected output type, or throws an error.
    func download(using parameter: Input,
                  userAgent: String = "Requests for iOS",
                  urlConfiguration: URLSessionConfiguration? = nil) async throws -> Output {
        
        let request = try await urlRequest(with: parameter, userAgent: userAgent)
        let session = Self.session(urlConfiguration: urlConfiguration)
        
        let (filesystemURL, response): (URL, URLResponse)
        if #available(iOS 15.0, macOS 12.0, *) {
            (filesystemURL, response) = try await session.download(for: request)
        } else {
            (filesystemURL, response) = try await session.download(using: request)
        }
        
        // We check if the Task got cancelled to avoid decoding data for nothing.
        try Task.checkCancellation()
        
        // We first validate the URLResponse that we received in order to check if everything went ok.
        try Self.validateResponse(response, data: nil)
        
        return filesystemURL
    }
}

public extension Resource where Output == URL {
    
    func download(using parameter: Input,
                  userAgent: String = "Requests for iOS",
                  urlSessionConfiguration: URLSessionConfiguration? = nil,
                  completion: @escaping (Result<Output, ResourceError>) -> Void) {
        
        self.urlRequest(with: parameter, userAgent: userAgent) { result in
            do {
                let request = try result.get()
                let session = Self.session(urlConfiguration: urlSessionConfiguration)
                let downloadTask = session.downloadTask(with: request) { filesystemURL, response, error in
                    guard let filesystemURL,
                          let response else {
                        completion(.failure(.unexpectedError(message: error?.localizedDescription ?? "Unexpected error while fetching \(String(describing: request.url))")))
                        return
                    }
                    
                    do {
                        try Self.validateResponse(response, data: nil)
                        completion(.success(filesystemURL))
                    } catch {
                        if let resourceError = error as? ResourceError {
                            completion(.failure(resourceError))
                        } else {
                            completion(.failure(.unexpectedError(message: error.localizedDescription)))
                        }
                    }
                }
            } catch {
                completion(.failure(.unexpectedError(message: error.localizedDescription)))
            }
        }
    }
    
}


fileprivate extension Resource where Output: Codable {
    
    static func decodeData(data: Data) throws -> Output {
        if Output.self == String.self {
            if let dataStr = (String(data: data, encoding: .utf8) ?? "") as? Self.Output {
                return dataStr
            }
        } else if Output.self == Data.self {
            if let data = data as? Self.Output { return data }
        } else {
            return try JSONDecoder().decode(Output.self, from: data)
        }
        
        throw ResourceError.badDataType
    }
    
    static func decodeErrorOutput(data: Data) throws -> OutputError {
        if Output.self == String.self {
            if let dataStr = (String(data: data, encoding: .utf8) ?? "") as? Self.OutputError {
                return dataStr
            }
        } else if Output.self == Data.self {
            if let data = data as? Self.OutputError { return data }
        } else {
            return try JSONDecoder().decode(OutputError.self, from: data)
        }
        
        throw ResourceError.badDataType
    }
    
}

private enum ResourceInternalState {
    static var injectedSession: URLSession?
}

public extension Resource {
    
    static func inject(session: URLSession?) {
        ResourceInternalState.injectedSession = session
    }
    
}

private extension Resource {
    
    static func session(urlConfiguration: URLSessionConfiguration? = nil) -> URLSession {
        if let injected = ResourceInternalState.injectedSession {
            return injected
        }

        if let urlConfiguration {
            return URLSession(configuration: urlConfiguration)
        }
        
        return URLSession.shared
    }
    
    @available(iOS 13.0, *)
    private func urlRequest(with parameter: Input,
                            userAgent: String,
                            urlSessionConfiguration: URLSessionConfiguration? = nil) async throws -> URLRequest {
        
        var request = try urlRequest(using: parameter)
        request.setValue(userAgent, forHttpHeaderField: .userAgent)
        // If the resource is also authenticated, wee need to embedd an authentication token.
         if let authenticated = self as? AuthenticatedResource {
            let token = try await authenticated.authenticator.validToken()
            request.authenticated(with: token, headerField: authenticated.authHeader)
         }
        
        request.httpMethod = self.httpMethod.rawValue
        request.debug()
        
        return request
    }
    
    private func urlRequest(with parameter: Input,
                            userAgent: String = "Authenticated-Requests-SDK",
                            urlSessionConfiguration: URLSessionConfiguration? = nil,
                            completion: @escaping (Result<URLRequest, Error>) -> Void) {
        do {
            var request = try urlRequest(using: parameter)
            request.setValue(userAgent, forHttpHeaderField: .userAgent)
            request.httpMethod = self.httpMethod.rawValue
            
            // If the resource is also authenticated, wee need to embedd an authentication token.
             if let authenticated = self as? AuthenticatedResource {
                 authenticated.authenticator.validToken { tokenResult in
                     do {
                         let token = try tokenResult.get()
                         request.authenticated(with: token, headerField: authenticated.authHeader)
                         request.debug()
                         completion(.success(request))
                     } catch {
                         completion(.failure(error))
                     }
                 }
             } else {
                 request.debug()
                 completion(.success(request))
             }
        } catch {
            completion(.failure(error))
        }
    }
    
    /**
     Given a URLResponse, this method trows an error if the response doesn't
     match the expected requirements.
     
     
     Specifically if the URLResponse could not be casted as a HTTPURLResponse or if the status code is not in the 2xx range.
     - Parameter response: The URLResponse that needs to be inspected.
     - Parameter data: The data associated to the URLRequest. It's used to print the optional error message associated with the response code.
     */
    static func validateResponse(_ response: URLResponse, data: Data?) throws {
        
        debug(response, data: data)
        
        guard let response = response as? HTTPURLResponse else {
            throw ResourceError.notHttpResponse
        }
        
        print("Status code:", response.statusCode)
        
        guard (200 ... 299) ~= response.statusCode else { // check for http errors
            if let data,
               let debugged = try? JSONDecoder().decode(OutputError.self, from: data) {
                throw ResourceError.apiError(resultError: debugged)
            } else {
                throw ResourceError.badResponse(responseCode: response.statusCode, message: "The error has an unexpexted format.")
            }
        }
    }
    
    static func debug(_ response: URLResponse, data: Data?) {
        
        guard RequestConfiguration.debugsHTTPResponses else {
            return
        }
        
        defer { print(String(repeating: "=", count: debugHeaderLength)) }
        
        var trail = debugHeaderLength - 15
        if trail < 2 { trail = 2 }
        
        print("== URLResponse " + String(repeating: "=", count: trail))
        
        if debugVerbosity > 0 {
            print("\(response)")
            print("Raw Data:")
            if let data {
                print(String(decoding: data, as: UTF8.self))
            } else {
                print("-- Null --")
            }
        } else {
            print("⬅️", response.url?.absoluteString ?? "URL??")
        }
    }
    
}
