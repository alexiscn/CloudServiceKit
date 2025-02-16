//
//  Drive123ServiceProvider.swift
//
//
//  Created by alexiscn on 2025/2/16.
//

import Foundation
import CryptoKit

/// Drive123ServiceProvider
/// https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced
public class Drive123ServiceProvider: CloudServiceProvider {
    
    public var delegate: CloudServiceProviderDelegate?
    
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    public var name: String { return "123Pan" }
    
    public var credential: URLCredential?
    
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    /// Upload chunsize which is 10M.
    public let chunkSize: Int64 = 10 * 1024 * 1024
    
    public var apiURL = URL(string: "https://open-api.123pan.com")!
    
    private var headers: [String: String] {
        return ["Platform": "open_platform"]
    }
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/api/v1/file/detail")
        var params = [String: Any]()
        params["fileID"] = item.id
        get(url: url, params: params, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let file = Self.cloudItemFromJSON(object) {
                    completion(.success(file))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        
        var items: [CloudItem] = []
        
        func loadList(lastFileId: Int?) {
            var json: [String: Any] = [:]
            json["limit"] = 100
            json["parentFileId"] = directory.id
            if let lastFileId = lastFileId {
                json["lastFileId"] = lastFileId
            }
            let url = apiURL.appendingPathComponent("/api/v2/file/list")
            get(url: url, params: json, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    if let object = result.json as? [String: Any], let data = object["data"] as? [String: Any],
                       let list = data["fileList"] as? [[String: Any]] {
                        let files = list.compactMap { Self.cloudItemFromJSON($0) }
                        files.forEach { $0.fixPath(with: directory) }
                        items.append(contentsOf: files)
                        
                        if let lastFileId = object["lastFileId"] as? Int {
                            loadList(lastFileId: lastFileId)
                        } else {
                            completion(.success(items))
                        }
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        loadList(lastFileId: nil)
    }
    
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
    }
    
    /// Create a folder at a given directory.
    /// - Parameters:
    ///   - folderName: The folder name to be created.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/upload/v1/file/mkdir")
        var json: [String: Any] = [:]
        json["parentID"] = directory.id
        json["name"] = folderName
        post(url: url, json: json, headers: headers, completion: completion)
    }
    
    public func createFolder(_ folderName: String, at directory: CloudItem) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            createFolder(folderName, at: directory) { response in
                switch response.result {
                case .success(_):
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get the space usage information for the current user's account.
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/api/v1/user/info")
        get(url: url, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let totalSize = json["spacePermanent"] as? Int64,
                   let usedSize = json["spaceUsed"] as? Int64 {
                    let cloudInfo = CloudSpaceInformation(totalSpace: totalSize, availableSpace: totalSize - usedSize, json: json)
                    completion(.success(cloudInfo))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get information about the current user's account.
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/api/v1/user/info")
        get(url: url, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let username = json["nickname"] as? String {
                    let user = CloudUser(username: username, json: json)
                    completion(.success(user))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func downloadRequest(item: CloudItem) async throws -> URLRequest {
        try await withCheckedThrowingContinuation { continuation in
            getDownloadUrl(of: item) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: URLRequest(url: url))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func mediaRequest(item: CloudItem) async throws -> URLRequest {
        try await withCheckedThrowingContinuation { continuation in
            getDownloadUrl(of: item, parameters: [:]) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: URLRequest(url: url))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Move file to directory.
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/api/v1/file/move")
        var json = [String: Any]()
        json["fileIDs"] = [item.id]
        json["toParentFileID"] = directory.id
        post(url: url, json: json, headers: headers, completion: completion)
    }
    
    /// Remove file/folder.
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/api/v1/file/trash")
        var json = [String: Any]()
        json["fileIDs"] = [item.id]
        post(url: url, json: json, headers: headers, completion: completion)
    }
    
    public func trashItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/api/v1/file/delete")
        var json = [String: Any]()
        json["fileIDs"] = [item.id]
        post(url: url, json: json, headers: headers, completion: completion)
    }
    
    /// Rename file/folder item.
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/api/v1/file/name")
        var json: [String: Any] = [:]
        json["fileId"] = item.id
        json["fileName"] = newName
        put(url: url, json: json, headers: headers, completion: completion)
    }
    
    /// Search files by keyword.
    /// - Parameters:
    ///   - keyword: The keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/api/v2/file/list")
        var json: [String: Any] = [:]
        json["limit"] = 100
        json["parentFileId"] = 0
        json["searchData"] = keyword
        json["searchMode"] = 1
        
        get(url: url, params: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let list = object["items"] as? [[String: Any]] {
                    let items = list.compactMap { Self.cloudItemFromJSON($0) }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func thumbnailRequest(item: CloudItem) async throws -> URLRequest {
        throw CloudServiceError.unsupported
    }
    
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func getDownloadUrl(of item: CloudItem, parameters: [String: Any] = [:], completion: @escaping (Result<URL, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/api/v1/file/download_info")
        var data: [String: Any] = [:]
        
        data["fileId"] = item.id
        
        if !parameters.isEmpty {
            for (key, value) in parameters {
                data[key] = value
            }
        }
        get(url: url, params: data, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let data = json["data"] as? [String: Any],
                   let urlString = data["downloadUrl"] as? String, let url = URL(string: urlString) {
                    completion(.success(url))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
}

extension Drive123ServiceProvider {
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let fileId = json["fileId"] as? Int, let filename = json["filename"] as? String else {
            return nil
        }
        if json["trashed"] as? Int == 1 {
            return nil
        }
        let isFolder = (json["type"] as? Int) == 1
        let item = CloudItem(id: String(fileId), name: filename, path: filename, isDirectory: isFolder, json: json)
        item.size = (json["size"] as? Int64) ?? -1
        return item
    }
}
