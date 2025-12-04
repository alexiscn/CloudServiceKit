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
    
    fileprivate static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh-CN")
        return formatter
    }()
    
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
                        
                        if let lastFileId = data["lastFileId"] as? Int, lastFileId > 0 {
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
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension(URL(fileURLWithPath: filename).pathExtension)
        do {
            try data.write(to: tempURL, options: .atomic)
            uploadFile(tempURL, to: directory, progressHandler: progressHandler) { response in
                try? FileManager.default.removeItem(at: tempURL)
                completion(response)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        do {
            let bufferSize = 5 * 1024 * 1024
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            var md5 = Insecure.MD5()
            var loop = true
            while loop {
                autoreleasepool {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.count > 0 {
                        md5.update(data: data)
                    } else {
                        loop = false
                    }
                }
            }
            let md5Hash = md5.finalize().toHexString()
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes[.size] as? Int64) ?? 0
            createFile(fileURL: fileURL, filename: fileURL.lastPathComponent, fileSize: fileSize, fileMD5: md5Hash, directory: directory, completion: completion)
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
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

// MARK: - Upload
extension Drive123ServiceProvider {
        
    private func createFile(fileURL: URL, filename: String, fileSize: Int64, fileMD5: String, directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/upload/v2/file/create")
        var json = [String: Any]()
        json["parentFileID"] = directory.id
        json["filename"] = filename
        json["etag"] = fileMD5
        json["size"] = fileSize
        json["duplicate"] = 1
        
        post(url: url, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let data = object["data"] as? [String: Any] {
                    if let fileID = data["fileID"] as? Int, fileID > 0, let reuse = data["reuse"] as? Bool, reuse == true {
                        completion(.init(response: result, result: .success(result)))
                    } else if let preuploadID = data["preuploadID"] as? String, let sliceSize = data["sliceSize"] as? Int64,
                                let servers = data["servers"] as? [String], let server = servers.first, let serverURL = URL(string: server) {
                        self.startUpload(fileURL: fileURL, preuploadID: preuploadID, fileSize: fileSize, sliceSize: sliceSize, uploadServerURL: serverURL, completion: completion)
                    } else {
                        completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                    }
                } else {
                    completion(.init(response: nil, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                completion(.init(response: nil, result: .failure(error)))
            }
        }
    }
    
    private func startUpload(fileURL: URL, preuploadID: String, fileSize: Int64, sliceSize: Int64, uploadServerURL: URL, completion: @escaping CloudCompletionHandler) {
        Task { @MainActor in
            do {
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                let partCount = Int((fileSize + sliceSize - 1) / sliceSize)
                
                var uploadedParts = [Bool]()
                try await withThrowingTaskGroup(of: Bool.self) { group in
                    for partNumber in 1...partCount {
                        if Task.isCancelled { break }
                        group.addTask {
                            let offset = (Int(partNumber) - 1) * Int(sliceSize)
                            let size = min(sliceSize, fileSize - Int64(offset))
                            try fileHandle.seek(toOffset: UInt64(offset))
                            let data = autoreleasepool {
                                fileHandle.readData(ofLength: Int(size))
                            }
                            
                            let part = try await self.uploadData(data, to: uploadServerURL, preuploadID: preuploadID, sliceNo: partNumber)
                            return part
                        }
                    }
                    
                    for try await part in group {
                        uploadedParts.append(part)
                    }
                }
                
                try? fileHandle.close()
                
                let completeResult = try await self.completeUpload(preuploadID: preuploadID)
                if completeResult {
                    completion(.init(response: nil, result: .success(HTTPResult(data: nil, response: nil, error: nil, task: nil))))
                }
            } catch {
                completion(.init(response: nil, result: .failure(error)))
            }
        }
    }
        
    private func uploadData(_ data: Data, to url: URL, preuploadID: String, sliceNo: Int) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let uploadUrl = url.appendingPathComponent("/upload/v2/file/slice")
            var md5 = Insecure.MD5()
            md5.update(data: data)
            let sliceMD5 = md5.finalize().toHexString()
            
            var formData = [String: Any]()
            formData["preuploadID"] = preuploadID
            formData["sliceNo"] = sliceNo
            formData["sliceMD5"] = sliceMD5
            let file = HTTPFile.data("slice", data, nil)
            
            post(url: uploadUrl, data: formData, headers: headers, files: ["slice": file], completion: { result in
                switch result.result {
                case .success(_):
                    continuation.resume(returning: true)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    
    private func completeUpload(preuploadID: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let url = apiURL.appendingPathComponent("/upload/v1/file/upload_complete")
            var json: [String: Any] = [:]
            json["preuploadID"] = preuploadID
            post(url: url, json: json, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any], let data = json["data"] as? [String: Any] {
                        let completed = data["completed"] as? Bool ?? false
                        continuation.resume(returning: completed)
                    } else {
                        continuation.resume(throwing: CloudServiceError.responseDecodeError(result))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func checkAsyncUploadResult(preuploadID: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let url = apiURL.appendingPathComponent("/upload/v1/file/upload_async_result")
            var json: [String: Any] = [:]
            json["preuploadID"] = preuploadID
            post(url: url, json: json, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any], let data = json["data"] as? [String: Any] {
                        let completed = data["completed"] as? Bool ?? false
                        continuation.resume(returning: completed)
                    } else {
                        continuation.resume(throwing: CloudServiceError.responseDecodeError(result))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
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
        if let createdAt = json["createAt"] as? String, let creationDate = Self.dateFormatter.date(from: createdAt) {
            item.creationDate = creationDate
        }
        if let updatedAt = json["updateAt"] as? String, let updateDate = Self.dateFormatter.date(from: updatedAt) {
            item.modificationDate = updateDate
        }
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        guard let json = response.json as? [String: Any] else { return false }
        if let code = json["code"] as? Int, code != 0 {
            let msg = json["message"] as? String ?? "Unknown error"
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(-1, msg))))
            return true
        }
        return false
    }
    
    public func isUnauthorizedResponse(_ response: HTTPResult) -> Bool {
        guard let json = response.json as? [String: Any] else { return false }
        if let code = json["code"] as? Int {
            return code == 401
        }
        return false
    }

}
