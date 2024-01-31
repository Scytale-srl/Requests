//
//  DefaultOutputErroe.swift
//  Requests
//
//  Created by Francesco Bianco on 31/01/24.
//

import Foundation

// A simple error container.
public struct DefaultError: DebuggableError, Codable {
    public var errorCode: Int
    
    public var debugMessage: String?
    
    public var humanReadableMessage: String?
    
    // Implementa qui i metodi/proprietà richiesti da DebuggableError
    
    public init(errorCode: Int,
                debugMessage: String? = nil,
                humanReadableMessage: String? = nil) {
        self.errorCode = errorCode
        self.debugMessage = debugMessage
        self.humanReadableMessage = humanReadableMessage
    }
    
    public static let empty = DefaultError(errorCode: 0)
}
