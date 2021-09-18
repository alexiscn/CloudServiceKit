//
//  CloudServiceError.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2021/9/14.
//

import Foundation

/// The cloud service error.
public enum CloudServiceError: Error {
    /// The method not supported.
    case unsupported
    /// JSON Decode response error.
    case responseDecodeError(HTTPResult)
    /// Something went wrong with the cloud service. Contains error code and error message.
    case serviceError(Int, String?)
    /// The upload file url not exist.
    case uploadFileNotExist
}
