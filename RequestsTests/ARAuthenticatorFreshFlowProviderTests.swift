//
//  ARAuthenticatorFreshFlowProviderTests.swift
//  RequestsTests
//

import XCTest
@testable import Requests

@available(iOS 13.0, *)
final class ARAuthenticatorFreshFlowProviderTests: XCTestCase {

    private var fastFailingSession: URLSession!

    override func setUp() {
        super.setUp()
        // Tight timeouts so the test fails fast: every token endpoint call
        // is expected to error out before reaching the (refused) host.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.5
        config.timeoutIntervalForResource = 1.0
        fastFailingSession = URLSession(configuration: config)
        AuthenticationEndpoint.inject(session: fastFailingSession)
    }

    override func tearDown() {
        AuthenticationEndpoint.inject(session: nil)
        fastFailingSession = nil
        super.tearDown()
    }

    func test_freshFlowProvider_isInvokedWhenAccessTokenIsFetched() async throws {
        let endpoint = AuthenticationEndpoint(
            // Port 1 reliably refuses connections — no real backend involved.
            baseEndpoint: URL(string: "http://127.0.0.1:1")!,
            path: "/oauth/token"
        )
        let store = ARTokenManager(keychain: InMemoryTokenStore())
        let authenticator = ARAuthenticator(tokenStore: store, baseEndpoint: endpoint)

        let initialFlow = AppAttestFlow(
            clientID: "wallet-proxy-ios",
            keyId: "key",
            assertion: Data([0x01]),
            nonce: "old"
        )
        await authenticator.configure(with: initialFlow)

        let counter = CallCounter()
        await authenticator.setFreshFlowProvider {
            await counter.increment()
            return AppAttestFlow(
                clientID: "wallet-proxy-ios",
                keyId: "key",
                assertion: Data([0x02]),
                nonce: "fresh"
            )
        }

        // The HTTP call is expected to fail (port 1 is closed); we only care
        // that the authenticator asked the provider for a fresh flow first.
        _ = try? await authenticator.validToken()

        let calls = await counter.count
        XCTAssertEqual(calls, 1, "fresh flow provider should be invoked exactly once")
    }

    func test_withoutFreshFlowProvider_authenticatorReusesConfiguredFlow() async throws {
        let endpoint = AuthenticationEndpoint(
            baseEndpoint: URL(string: "http://127.0.0.1:1")!,
            path: "/oauth/token"
        )
        let store = ARTokenManager(keychain: InMemoryTokenStore())
        let authenticator = ARAuthenticator(tokenStore: store, baseEndpoint: endpoint)

        let initialFlow = ClientCredentials(clientID: "id", clientSecret: "secret", scope: ["read"])
        await authenticator.configure(with: initialFlow)

        // No provider installed.
        _ = try? await authenticator.validToken()

        let storedFlow = await authenticator.authenticationFlow()
        XCTAssertTrue(initialFlow.isEqualTo(otherFlow: storedFlow))
    }

    func test_settingFreshFlowProviderToNilDisablesIt() async throws {
        let endpoint = AuthenticationEndpoint(
            baseEndpoint: URL(string: "http://127.0.0.1:1")!,
            path: "/oauth/token"
        )
        let store = ARTokenManager(keychain: InMemoryTokenStore())
        let authenticator = ARAuthenticator(tokenStore: store, baseEndpoint: endpoint)

        await authenticator.configure(with: ClientCredentials(clientID: "id", clientSecret: "secret", scope: ["read"]))

        let counter = CallCounter()
        await authenticator.setFreshFlowProvider {
            await counter.increment()
            return ClientCredentials(clientID: "id", clientSecret: "secret", scope: ["read"])
        }
        await authenticator.setFreshFlowProvider(nil)

        _ = try? await authenticator.validToken()

        let calls = await counter.count
        XCTAssertEqual(calls, 0, "fresh flow provider should not be invoked once cleared")
    }
}

// MARK: - Test helpers

private actor CallCounter {
    var count = 0
    func increment() { count += 1 }
}

private final class InMemoryTokenStore: TokenStore {
    private var storage: [String: Data] = [:]

    func object<T>(_ type: T.Type, with key: String, usingDecoder decoder: JSONDecoder) -> T? where T: Decodable, T: Encodable {
        guard let data = storage[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func set<T>(object: T?, forKey key: String, usingEncoder encoder: JSONEncoder) -> Bool where T: Decodable, T: Encodable {
        if let object {
            guard let data = try? encoder.encode(object) else { return false }
            storage[key] = data
        } else {
            storage.removeValue(forKey: key)
        }
        return true
    }

    @discardableResult
    func delete(_ key: String) -> Bool {
        storage.removeValue(forKey: key)
        return true
    }
}
