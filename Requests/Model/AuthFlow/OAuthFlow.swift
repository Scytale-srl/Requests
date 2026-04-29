//
//  OAuthFlow.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

public protocol OAuthFlow {

    var clientID: String { get }
    var queryParameters: [String: String]? { get }
    var httpBody: Data? { get }

    /// Content-Type the flow's `httpBody` should be sent with. Defaults to
    /// `application/x-www-form-urlencoded`, which matches the existing OAuth
    /// 2.0 grants. Flows that ship a JSON body (e.g. attestation-based
    /// flows) override this to `.applicationJson`.
    var contentType: ContentType { get }

    var isValid: Bool { get }

    func isEqualTo(otherFlow: OAuthFlow?) -> Bool
}

public extension OAuthFlow {
    /// Default keeps existing flows source-compatible: classic OAuth 2.0
    /// token endpoints expect a form-urlencoded body.
    var contentType: ContentType { .formEncoded }
}
