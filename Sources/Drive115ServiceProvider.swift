//
//  BaiduPanServiceProvider.swift
//  
//
//  Created by alexiscn on 2021/8/9.
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
        completion(.failure(CloudServiceError.unsupported))
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
        var json: [String: Any] = [:]
        json["pid"] = directory.id
        json["file_name"] = folderName
        post(url: url, json: json, completion: completion)
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
        var json = [String: Any]()
        json["file_ids"] = item.id
        json["to_cid"] = directory.id
        post(url: url, json: json, completion: completion)
    }
    
    /// Remove file/folder.
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/open/ufile/delete")
        var json = [String: Any]()
        json["file_ids"] = item.id
        post(url: url, json: json, completion: completion)
    }
    
    public func trashItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/api/v1/file/trash")
        var json = [String: Any]()
        json["fileIDs"] = [item.id]
        post(url: url, json: json, completion: completion)
    }
    
    /// Rename file/folder item.
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/update")
        var json: [String: Any] = [:]
        json["file_id"] = item.id
        json["name"] = newName
        post(url: url, json: json, completion: completion)
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
        item.size = Int64((json["fs"] as? String) ?? "-1") ?? -1
        return item
    }
}
