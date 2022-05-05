//
//  Extensions.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2021/9/14.
//

import Foundation
import CryptoKit

// MARK: - Array
extension Array {
    var json: String {
        let data = (try? JSONSerialization.data(withJSONObject: self, options: .fragmentsAllowed)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - Dictionary
extension Dictionary {
    var json: String {
        let data = (try? JSONSerialization.data(withJSONObject: self, options: .fragmentsAllowed)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

// MARK: - String
extension String {
    func asciiEscaped() -> String {
        var res = ""
        for char in self.unicodeScalars {
            let substring = String(char)
            if substring.canBeConverted(to: .ascii) {
                res.append(substring)
            } else {
                res = res.appendingFormat("\\u%04x", char.value)
            }
        }
        return res
    }
    
    /// Encodes url string making it ready to be passed as a query parameter. This encodes pretty much everything apart from
    /// alphanumerics and a few other characters compared to standard query encoding.
    var urlEncoded: String {
        let customAllowedSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return self.addingPercentEncoding(withAllowedCharacters: customAllowedSet)!
    }
}

// MARK: - Digest
extension Digest {
    
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
    
    func toBase64() -> String {
        return Data(self).base64EncodedString()
    }
}
