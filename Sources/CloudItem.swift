//
//  CloudItem.swift
//  
//
//  Created by alexiscn on 2021/8/11.
//

import Foundation

/// The representation of file/folder item.
/// You can create your own cloud file model and parse with the `json` property.
public class CloudItem: Hashable {
        
    /// The identifier of the fileId.
    /// Some cloud service (Box/Dropbox) use fileId instead path to do file operations.
    public let id: String
    
    /// The file name.
    public let name: String
    
    /// The file path.
    public let path: String
    
    /// A boolean value indicates if the cloud item is directory.
    public let isDirectory: Bool
    
    /// The original json of the file. You can access to get the information you interested.
    public var json: [String: Any] = [:]
    
    /// The size of the cloud item. Maybe -1 if item is directory.
    public var size: Int64 = -1
    
    /// The creation date of the cloud item.
    public var creationDate: Date?
    
    /// The modification date of the cloud item.
    public var modificationDate: Date?
    
    /// Hash value of cloud file. `nil` for folder.
    public var fileHash: String? = nil
    
    public init(id: String, name: String, path: String, isDirectory: Bool = true, json: [String: Any] = [:]) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.json = json
    }
    
    public static func == (lhs: CloudItem, rhs: CloudItem) -> Bool {
        return lhs.name == rhs.name &&
            lhs.path == rhs.path &&
            lhs.id == rhs.id &&
            lhs.isDirectory == rhs.isDirectory
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(path)
        hasher.combine(isDirectory)
    }
}

public struct CloudUser {
    
    /// The account user name of cloud service. The value is usually the display name.
    public var username: String
    
    /// The origin json response data of the user information.
    public var json: [String: Any]
    
    public init(username: String, json: [String: Any]) {
        self.username = username
        self.json = json
    }
}

public struct CloudSpaceInformation {
    
    /// Total space in bytes.
    public var totalSpace: Int64
    
    /// Available space in bytes.
    public var availableSpace: Int64
    
    /// The origin json response where you can get what you want
    public var json: [String: Any]
    
    public init(totalSpace: Int64, availableSpace: Int64, json: [String: Any]) {
        self.totalSpace = totalSpace
        self.availableSpace = availableSpace
        self.json = json
    }
}
