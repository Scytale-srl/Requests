//
//  AppAttestFlowTests.swift
//  RequestsTests
//

import XCTest
@testable import Requests

final class AppAttestFlowTests: XCTestCase {

    private let validFlow = AppAttestFlow(
        clientID: "wallet-proxy-ios",
        keyId: "AAAA-BBBB-CCCC",
        assertion: Data([0x01, 0x02, 0x03, 0xff]),
        nonce: "07e8b8e0-1234-4f8b-92cc-aabbccddeeff"
    )

    // MARK: - isValid

    func test_isValid_isTrueWhenAllFieldsArePresent() {
        XCTAssertTrue(validFlow.isValid)
    }

    func test_isValid_isFalseWhenAnyFieldIsEmpty() {
        let cases: [AppAttestFlow] = [
            AppAttestFlow(clientID: "", keyId: "k", assertion: Data([0x1]), nonce: "n"),
            AppAttestFlow(clientID: "c", keyId: "", assertion: Data([0x1]), nonce: "n"),
            AppAttestFlow(clientID: "c", keyId: "k", assertion: Data(), nonce: "n"),
            AppAttestFlow(clientID: "c", keyId: "k", assertion: Data([0x1]), nonce: "")
        ]
        for flow in cases {
            XCTAssertFalse(flow.isValid, "expected \(flow) to be invalid")
        }
    }

    // MARK: - httpBody

    func test_httpBody_isJSONAndCarriesAllExpectedFields() throws {
        let body = try XCTUnwrap(validFlow.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["platform"] as? String, "ios")
        XCTAssertEqual(json["client_id"] as? String, validFlow.clientID)
        XCTAssertEqual(json["key_id"] as? String, validFlow.keyId)
        XCTAssertEqual(json["nonce"] as? String, validFlow.nonce)

        let assertionBase64 = try XCTUnwrap(json["assertion"] as? String)
        XCTAssertEqual(Data(base64Encoded: assertionBase64), validFlow.assertion)
    }

    // MARK: - contentType

    func test_contentType_isApplicationJson() {
        XCTAssertEqual(validFlow.contentType, .applicationJson)
    }

    // MARK: - queryParameters

    func test_queryParameters_isNil() {
        XCTAssertNil(validFlow.queryParameters)
    }

    // MARK: - isEqualTo

    func test_isEqualTo_returnsTrueForIdenticalFlow() {
        let copy = AppAttestFlow(
            clientID: validFlow.clientID,
            keyId: validFlow.keyId,
            assertion: validFlow.assertion,
            nonce: validFlow.nonce
        )
        XCTAssertTrue(validFlow.isEqualTo(otherFlow: copy))
    }

    func test_isEqualTo_returnsFalseForDifferentNonce() {
        let other = AppAttestFlow(
            clientID: validFlow.clientID,
            keyId: validFlow.keyId,
            assertion: validFlow.assertion,
            nonce: "different-nonce"
        )
        XCTAssertFalse(validFlow.isEqualTo(otherFlow: other))
    }

    func test_isEqualTo_returnsFalseForDifferentFlowType() {
        let other = ClientCredentials(clientID: "x", clientSecret: "y", scope: ["read"])
        XCTAssertFalse(validFlow.isEqualTo(otherFlow: other))
    }

    func test_isEqualTo_returnsFalseForNil() {
        XCTAssertFalse(validFlow.isEqualTo(otherFlow: nil))
    }
}
