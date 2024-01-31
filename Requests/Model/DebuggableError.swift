//
//  DebuggableError.swift
//  Requests
//
//  Created by Francesco Bianco on 29/01/24.
//

import Foundation

public protocol DebuggableError {
    
    var errorCode: Int { get }
    var debugMessage: String? { get }
    var humanReadableMessage: String? { get }
    
}
