//
//  CloudServiceError.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2021/9/14.
//

import Foundation

/// The cloud service error.
public enum CloudServiceError: LocalizedError {
    /// The method not supported.
    case unsupported
    /// JSON Decode response error.
    case responseDecodeError(HTTPResult)
    /// Something went wrong with the cloud service. Contains error code and error message.
    case serviceError(Int, String?)
    /// The upload file url not exist.
    case uploadFileNotExist
    
    public var errorDescription: String? {
        switch self {
        case .unsupported: return "Unsupported"
        case .responseDecodeError(_): return "Response Decode Error"
        case .serviceError(_, let message): return message ?? "Unknown"
        case .uploadFileNotExist: return "Upload file not found"
        }
    }
}
