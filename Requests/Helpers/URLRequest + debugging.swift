//
//  URLRequest + debugging.swift
//  Requests
//
//  Created by Francesco Bianco on 29/01/24.
//

import Foundation


extension URLRequest {
    
    public func debug() {

        guard RequestConfiguration.debugsHTTPRequests else { return }
        var trail = RequestConfiguration.debugHeaderLength - 20
        if trail < 1 { trail = 1 }
        print("== 🔎 URLRequest 🔍 \(String(repeating: "=", count: trail))")
        // if RequestConfiguration.debugVerbosity > 0 {
            print(asCurl)
        //} else {
        //    print(httpMethod ?? "", "➡️", url?.absoluteString ?? "URL??")
        // }
        print(String(repeating: "=", count: RequestConfiguration.debugHeaderLength))
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
