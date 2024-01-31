//
//  URLRequest + debugging.swift
//  Requests
//
//  Created by Francesco Bianco on 29/01/24.
//

import Foundation

let debugHeaderLength = 80
let debugVerbosity = 0

extension URLRequest {
    
    public func debug() {
#if DEBUG
        var trail = debugHeaderLength - 20
        if trail < 1 { trail = 1 }
        print("== 🔎 URLRequest 🔍 \(String(repeating: "=", count: trail))")
        if debugVerbosity > 0 {
            print(asCurl)
        } else {
            print(httpMethod ?? "", "➡️", url?.absoluteString ?? "URL??")
        }
        print(String(repeating: "=", count: debugHeaderLength))
#endif
    }
    
    public var asCurl: String {
        
        guard let url else {
            return ""
        }
        
        var cUrlRepresentation = "curl -v -X \(httpMethod ?? "Unknown") \\\n"
        
        allHTTPHeaderFields?.forEach { touple in
            cUrlRepresentation.append("-H \"\(touple.key): \(touple.value)\" \\\n")
        }
        
        if let httpBody,
           let stringBody = String(data: httpBody, encoding: .utf8) {
            cUrlRepresentation += "-d \"\(stringBody)\" \\\n"
        }
        
        cUrlRepresentation += url.absoluteString
        
        return cUrlRepresentation
    }
}
