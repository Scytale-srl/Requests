//
//  AuthenticationEndpointContentTypeTests.swift
//  RequestsTests
//

import XCTest
@testable import Requests

final class AuthenticationEndpointContentTypeTests: XCTestCase {

    private let endpoint = AuthenticationEndpoint(
        baseEndpoint: URL(string: "https://example.com")!,
        path: "/oauth/token"
    )

    // MARK: - Default flow uses form-urlencoded (regression guard)

    func test_clientCredentialsFlow_producesFormUrlencodedRequest() throws {
        let flow = ClientCredentials(clientID: "id", clientSecret: "secret", scope: ["read"])
        let request = try endpoint.urlRequest(using: flow)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )
    }

    func test_codeFlow_producesFormUrlencodedRequest() throws {
        let flow = CodeFlow(
            clientID: "id",
            code: "auth-code",
            redirectUrl: "app://redirect",
            codeVerifier: nil
        )
        let request = try endpoint.urlRequest(using: flow)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )
    }

    // MARK: - Attestation flow opts into JSON

    func test_appAttestFlow_producesJsonRequest() throws {
        let flow = AppAttestFlow(
            clientID: "id",
            keyId: "key",
            assertion: Data([0x01, 0x02]),
            nonce: "nonce"
        )
        let request = try endpoint.urlRequest(using: flow)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
    }

    // MARK: - Body content matches the flow

    func test_appAttestFlow_bodyOnRequestMatchesFlowHttpBody() throws {
        let flow = AppAttestFlow(
            clientID: "id",
            keyId: "key",
            assertion: Data([0x01, 0x02]),
            nonce: "nonce"
        )
        let request = try endpoint.urlRequest(using: flow)
        XCTAssertEqual(request.httpBody, flow.httpBody)
    }
}
