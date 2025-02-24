//
//  Drive115ServiceProvider.swift
//
//
//  Created by alexiscn on 2025/2/16.
//

import Foundation
import CryptoKit

/// Drive115ServiceProvider
/// https://www.yuque.com/115yun/open/gv0l5007pczskivz
public class Drive115ServiceProvider: CloudServiceProvider {
    
    public var delegate: CloudServiceProviderDelegate?
    
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    public var name: String { return "115" }
    
    public var credential: URLCredential?
    
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    public var apiURL = URL(string: "https://proapi.115.com")!
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        completion(.success(item))
    }
    
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        
        var items: [CloudItem] = []
        
        func loadList(offset: Int?) {
            var params: [String: Any] = [:]
            params["limit"] = 100
            params["asc"] = "1"
            params["cid"] = directory.id
            params["show_dir"] = 1
            if let offset = offset {
                params["offset"] = offset
            }
            let url = apiURL.appendingPathComponent("/open/ufile/files")
            get(url: url, params: params) { response in
                switch response.result {
                case .success(let result):
                    if let object = result.json as? [String: Any],
                       let list = object["data"] as? [[String: Any]] {
                        let files = list.compactMap { Self.cloudItemFromJSON($0) }
                        files.forEach { $0.fixPath(with: directory) }
                        items.append(contentsOf: files)
                        
                        if let offset = object["offset"] as? Int, offset > 0 {
                            loadList(offset: offset)
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
        
        loadList(offset: nil)
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
        let url = apiURL.appendingPathComponent("/open/folder/add")
        var data: [String: Any] = [:]
        data["pid"] = directory.id
        data["file_name"] = folderName
        post(url: url, data: data, completion: completion)
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
        let url = apiURL.appendingPathComponent("/open/user/info")
        post(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let data = json["data"] as? [String: Any],
                   let info = data["rt_space_info"] as? [String: Any],
                   let totalSizeObject = info["all_total"] as? [String: String], let totalSizeStr = totalSizeObject["size"], let totalSize = Int64(totalSizeStr),
                   let usedSizeObject = info["all_use"] as? [String: String], let usedSizeStr = usedSizeObject["suze"], let usedSize = Int64(usedSizeStr) {
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
        let url = apiURL.appendingPathComponent("/open/user/info")
        post(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let username = json["nick_name"] as? String {
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
                    var request = URLRequest(url: url)
                    request.setValue("CloudServiceKit", forHTTPHeaderField: "User-Agent")
                    continuation.resume(returning: request)
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
                    var request = URLRequest(url: url)
                    request.setValue("CloudServiceKit", forHTTPHeaderField: "User-Agent")
                    continuation.resume(returning: request)
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
        let url = apiURL.appendingPathComponent("/open/ufile/move")
        var data = [String: Any]()
        data["file_ids"] = item.id
        data["to_cid"] = directory.id
        post(url: url, data: data, completion: completion)
    }
    
    /// Remove file/folder.
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/open/ufile/delete")
        var data = [String: Any]()
        data["file_ids"] = item.id
        post(url: url, data: data, completion: completion)
    }
    
    public func trashItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/api/v1/file/trash")
        var data = [String: Any]()
        data["fileIDs"] = [item.id]
        post(url: url, data: data, completion: completion)
    }
    
    /// Rename file/folder item.
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/open/ufile/update")
        var data: [String: Any] = [:]
        data["file_id"] = item.id
        data["name"] = newName
        post(url: url, data: data, completion: completion)
    }
    
    /// Search files by keyword.
    /// - Parameters:
    ///   - keyword: The keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/open/ufile/search")
        var params: [String: Any] = [:]
        params["limit"] = 100
        params["offset"] = 0
        params["search_value"] = keyword
        params["pick_code"] = "0"
        
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let list = object["data"] as? [Any] {
                    var items = [CloudItem]()
                    for obj in list {
                        if let json = obj as? [String: Any],
                            let fileId = json["file_id"] as? String,
                           let filename = json["file_name"] as? String {
                            let isDirectory = (json["file_category"] as? String) == "0"
                            let item = CloudItem(id: fileId, name: filename, path: filename, isDirectory: isDirectory, json: json)
                            item.size = Int64(json["file_size"] as? String ?? "-1") ?? -1
                            if let uploadTime = json["user_ptime"] as? String, let timestamp = TimeInterval(uploadTime) {
                                item.creationDate = Date(timeIntervalSince1970: timestamp)
                            }
                            if let updateTime = json["user_utime"] as? String, let timestamp = TimeInterval(updateTime) {
                                item.modificationDate = Date(timeIntervalSince1970: timestamp)
                            }
                            items.append(item)
                        }
                    }
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
        if let thumb = item.json["thumb"] as? String, let url = URL(string: thumb) {
            var request = URLRequest(url: url)
            return request
        } else {
            throw CloudServiceError.unsupported
        }
    }
    
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func getDownloadUrl(of item: CloudItem, parameters: [String: Any] = [:], completion: @escaping (Result<URL, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/open/ufile/downurl")
        var data: [String: Any] = [:]
        
        if let pickCode = item.json["pc"] as? String {
            data["pick_code"] = pickCode
        } else if let pickCode = item.json["pick_code"] as? String {
            data["pick_code"] = pickCode
        }
        
        if !parameters.isEmpty {
            for (key, value) in parameters {
                data[key] = value
            }
        }
        post(url: url, data: data, headers: ["User-Agent": "CloudServiceKit"]) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                    let dataObject = json["data"] as? [String: Any],
                    let object = dataObject[item.id] as? [String: Any],
                   let urlObject = object["url"] as? [String: Any],
                   let urlString = urlObject["url"] as? String, let url = URL(string: urlString) {
                    // request download url must contains User-Agent: CloudServiceKit
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

extension Drive115ServiceProvider {
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let fileId = json["fid"] as? String, let filename = json["fn"] as? String else {
            return nil
        }
        let isFolder = (json["fc"] as? String) == "0"
        let item = CloudItem(id: fileId, name: filename, path: filename, isDirectory: isFolder, json: json)
        item.size = (json["fs"] as? Int64) ?? -1
        if let uploadTime = json["uppt"] as? Int64 {
            item.creationDate = Date(timeIntervalSince1970: TimeInterval(uploadTime))
        }
        if let updateTime = json["upt"] as? Int64 {
            item.modificationDate = Date(timeIntervalSince1970: TimeInterval(updateTime))
        }
        return item
    }
}
