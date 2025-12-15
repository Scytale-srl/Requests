# Requests

A lightweight Swift framework for handling HTTP requests with built-in OAuth 2.0 authentication and token management.

## Overview

Requests simplifies network operations in iOS and macOS applications by providing a protocol-based approach to HTTP resource management. It includes robust OAuth 2.0 support with automatic token refresh, secure keychain storage, and comprehensive error handling.

## Features

- **Protocol-Based Architecture**: Define resources using the `Resource` protocol for type-safe networking
- **OAuth 2.0 Support**: Built-in support for multiple OAuth flows:
  - Authorization Code Flow
  - Client Credentials Flow
  - Refresh Token Flow
- **Automatic Token Management**: Handles token refresh automatically with secure keychain storage
- **Async/Await Support**: Modern Swift concurrency alongside traditional completion handlers
- **Type-Safe**: Strong typing for requests, responses, and errors
- **Debug Utilities**: Comprehensive logging for HTTP requests and responses
- **Flexible Output**: Support for `Codable` types, `Data`, `String`, and file downloads

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

Add Requests to your project using Swift Package Manager by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Requests.git", from: "1.0.0")
]
```

Or through Xcode:
1. File > Add Packages...
2. Enter the repository URL
3. Select the version you want to use

### XCFramework

Download the latest `.xcframework` from the releases page and add it to your project.

## Usage

### Basic Resource

Define a resource by conforming to the `Resource` protocol:

```swift
struct UserResource: Resource {
    typealias Input = Int
    typealias Output = User
    typealias OutputError = APIError

    let httpMethod: HttpMethod = .get

    func urlRequest(using userId: Int) throws -> URLRequest {
        let url = URL(string: "https://api.example.com/users/\(userId)")!
        return URLRequest(url: url)
    }
}
```

Then request the resource:

```swift
let resource = UserResource()
let user = try await resource.request(using: 123)
```

### Authenticated Resource

For resources requiring OAuth authentication, conform to both `Resource` and `AuthenticatedResource`:

```swift
struct ProtectedResource: Resource, AuthenticatedResource {
    typealias Input = Void
    typealias Output = ProtectedData
    typealias OutputError = APIError

    let httpMethod: HttpMethod = .get
    let authenticator: any Authenticator
    let authHeader: String? = nil // Uses "Authorization" by default

    func urlRequest(using parameter: Void) throws -> URLRequest {
        let url = URL(string: "https://api.example.com/protected")!
        return URLRequest(url: url)
    }
}
```

### OAuth Configuration

Set up an authenticator with your OAuth credentials:

```swift
let tokenManager = ARTokenManager(keychain: KeychainTokenStore(), prefix: "myapp")

let authenticator = ARAuthenticator(
    tokenManager: tokenManager,
    authEndpoint: AuthenticationEndpoint(
        tokenURL: URL(string: "https://oauth.example.com/token")!,
        clientId: "your-client-id",
        clientSecret: "your-client-secret",
        oauthFlow: .clientCredentials
    )
)

let resource = ProtectedResource(authenticator: authenticator)
let data = try await resource.request(using: ())
```

### Download Files

Resources can also download files directly:

```swift
struct FileDownload: Resource {
    typealias Input = String
    typealias Output = URL
    typealias OutputError = APIError

    let httpMethod: HttpMethod = .get

    func urlRequest(using fileId: String) throws -> URLRequest {
        let url = URL(string: "https://api.example.com/files/\(fileId)")!
        return URLRequest(url: url)
    }
}

let resource = FileDownload()
let localURL = try await resource.download(using: "file123")
```

### Debug Mode

Enable debug logging to inspect HTTP traffic:

```swift
RequestConfiguration.debugsHTTPRequests = true
RequestConfiguration.debugsHTTPResponses = true
RequestConfiguration.debugVerbosity = 1 // 0: minimal, 1: verbose
```

### Error Handling

All errors conform to `DebuggableError` for detailed debugging information:

```swift
do {
    let user = try await resource.request(using: 123)
} catch let error as ResourceError {
    switch error {
    case .badResponse(let code, let message):
        print("HTTP \(code): \(message)")
    case .apiError(let resultError):
        print("API Error: \(resultError.debugDescription)")
    case .unexpectedError(let message):
        print("Unexpected: \(message)")
    default:
        print("Error: \(error)")
    }
}
```

## Testing

Inject a custom URLSession for testing:

```swift
Resource.inject(session: mockURLSession)
```

## License

This project is available under the MIT license. See the LICENSE file for more info.

## Author

Francesco Bianco

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
