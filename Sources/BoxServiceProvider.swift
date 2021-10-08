//
//  BoxServiceProvider.swift
//  
//
//  Created by alexiscn on 2021/8/9.
//

import Foundation
import CryptoKit

/*
 A Wrapper of box Service.
 Developer documents can be found here: https://developer.box.com/reference/
 */
public class BoxServiceProvider: CloudServiceProvider {
    
    /// The name of service provider.
    public var name: String { return "Box" }
    
    /// The root folder of Box service. You can use this property to list root items.
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    public var credential: URLCredential?
    
    /// The api url of box service. Which is [https://api.box.com/2.0](https://api.box.com/2.0) .
    public var apiURL = URL(string: "https://api.box.com/2.0")!
    
    /// The upload url of box service. Which is [https://upload.box.com/api/2.0](https://upload.box.com/api/2.0) .
    private var uploadURL = URL(string: "https://upload.box.com/api/2.0")!
    
    /// The refresh access token handler. Used to refresh access token when the token expires.
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    required public init(credential: URLCredential?) {
        self.credential = credential
    }
    
    /// Get attributes of cloud item.
    /// - Parameters:
    ///   - item: The target item.
    ///   - completion: Completion callback.
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let path = item.isDirectory ? "folders": "files"
        let url = apiURL.appendingPathComponent("\(path)/\(item.id)")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let item = BoxServiceProvider.cloudItemFromJSON(json) {
                    completion(.success(item))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
 
    /// Load the contents at directory.
    /// - Parameters:
    ///   - directory: The target directory to load.
    ///   - completion: Completion callback.
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("folders/\(directory.id)/items")
        var params: [String: Any] = [:]
        params["fields"] = "id,type,name,size,created_at,modified_at,sha1"
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let entries = json["entries"] as? [[String: Any]] {
                    let items = entries.compactMap { BoxServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Copy item to directory
    /// Document can be found here:
    /// https://developer.box.com/reference/post-files-id-copy/
    /// https://developer.box.com/reference/post-folders-id-copy/
    /// - Parameters:
    ///   - item: The item to be copied.
    ///   - directory: The destination directory.
    ///   - completion: Completion callback.
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "folders": "files"
        let url = apiURL.appendingPathComponent("\(path)/\(item.id)/copy")
        var json: [String: Any] = [:]
        json["parent"] = ["id": directory.id]
        post(url: url, json: json, completion: completion)
    }
    
    /// Create folder at target folder.
    /// - Parameters:
    ///   - folderName: The folder name to be created.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("folders")
        var json: [String: Any] = [:]
        json["name"] = folderName
        json["parent"] = ["id": directory.id]
        post(url: url, json: json, completion: completion)
    }
    
    /// Get download request of file.
    /// - Parameter item: The item to be downloaded.
    /// - Returns: Downloadable request.
    public func downloadRequest(of item: CloudItem) -> URLRequest? {
        if item.isDirectory {
            return nil
        } else {
            let url = apiURL.appendingPathComponent("files/\(item.id)/content")
            let params = ["access_token": credential?.password ?? ""]
            return Just.adaptor.synthesizeRequest(.get, url: url, params: params, data: [:], json: nil, headers: [:], files: [:], auth: nil, timeout: nil, urlQuery: nil, requestBody: nil)
        }
    }
    
    /// Get the space usage information for the current user's account.
    /// Document can be found here: https://developer.box.com/reference/get-users-me/ .
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("users/me")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let total = json["space_amount"] as? Int64,
                   let used = json["space_used"] as? Int64 {
                    let info = CloudSpaceInformation(totalSpace: total, availableSpace: total - used, json: json)
                    completion(.success(info))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get information about the current user's account.
    /// Document can be found here https://developer.box.com/reference/get-users-me/
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("users/me")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let username = json["name"] as? String {
                    let account = CloudUser(username: username, json: json)
                    completion(.success(account))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Remove file/folder.
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "folders": "files"
        let url = apiURL.appendingPathComponent("\(path)/\(item.id)")
        delete(url: url, completion: completion)
    }
    
    /// Rename file/folder item to a new name.
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "folders": "files"
        let url = apiURL.appendingPathComponent("\(path)/\(item.id)")
        let json = ["name": newName]
        put(url: url, json: json, completion: completion)
    }
    
    /// Move file/folder to target directory.
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "folders": "files"
        let url = apiURL.appendingPathComponent("\(path)/\(item.id)")
        let json = ["parent": ["id": directory.id]]
        put(url: url, json: json, completion: completion)
    }
    
    /// Search file by keyword.
    /// Document can be found here: https://developer.box.com/reference/get-search/
    /// - Parameters:
    ///   - keyword: The query keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("search")
        let params = ["query": keyword]
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let entries = json["entries"] as? [[String: Any]] {
                    let items = entries.compactMap { BoxServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Upload file data to target directory.
    /// Document can be found here: https://developer.box.com/reference/post-files-content/
    /// - Parameters:
    ///   - data: The data to be uploaded.
    ///   - filename: The filename to be created.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let url = uploadURL.appendingPathComponent("files/content")
        
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withInternetDateTime,
                                          .withDashSeparatorInDate,
                                          .withFullDate,
                                          .withColonSeparatorInTimeZone]
        isoDateFormatter.timeZone = TimeZone.current
        let time = isoDateFormatter.string(from: Date())
        
        var formdata: [String: Any] = [:]
        formdata["attributes"] = [
            "content_created_at": time,
            "content_modified_at": time,
            "name": filename,
            "parent": [
                "id": directory.id
            ]
        ].json
        let file = HTTPFile.data(filename, data, nil)
        
        let length = Int64(data.count)
        let reportProgress = Progress(totalUnitCount: length)
        post(url: url, data: formdata, files: ["file": file], progressHandler: { progress in
            reportProgress.completedUnitCount = Int64(Float(length) * progress.percent)
            progressHandler(reportProgress)
        }, completion: completion)
    }
    
    /// Upload file to target directory with local file url.
    /// Note: remote url is not supported.
    /// Document can be found here: https://developer.box.com/guides/uploads/
    /// - Parameters:
    ///   - fileURL: The local file url.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard let size = fileSize(of: fileURL), size > 0 else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        if size < 20 * 1024 * 1024 {
            let data = (try? Data(contentsOf: fileURL)) ?? Data()
            uploadData(data, filename: fileURL.lastPathComponent, to: directory, progressHandler: progressHandler, completion: completion)
            return
        }
        let url = uploadURL.appendingPathComponent("files/upload_sessions")
        
        var json: [String: Any] = [:]
        json["file_name"] = fileURL.lastPathComponent
        json["file_size"] = size
        json["folder_id"] = directory.id
        post(url: url, json: json) { response in
            switch response.result {
            case .success(let result):
                if let data = result.content {
                    do {
                        let session = try JSONDecoder().decode(UploadSession.self, from: data)
                        self.uploadPart(session: session, fileURL: fileURL, totalSize: size, offset: 0, progressHandler: progressHandler, completion: completion)
                    } catch {
                        completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                    }
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
}

// MARK: - Chunk Upload
extension BoxServiceProvider {
    
    private func uploadPart(session: UploadSession, fileURL: URL, totalSize: Int64, offset: Int64, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        do {
            let length = min(Int64(session.partSize), totalSize - offset)
            let handle = try FileHandle(forReadingFrom: fileURL)
            try handle.seek(toOffset: UInt64(offset))
            let data = handle.readData(ofLength: Int(length))
            let sha1 = Insecure.SHA1.hash(data: data).toBase64()
            try handle.close()
            
            let url = uploadURL
                .appendingPathComponent("files/upload_sessions")
                .appendingPathComponent(session.id)
            var headers: [String: String] = [:]
            headers["Content-Range"] = String(format: "bytes %ld-%ld/%ld", offset, offset + length - 1, totalSize)
            headers["Digest"] = "sha=\(sha1)"
            headers["Content-Type"] = "application/octet-stream"
            
            let progressReport = Progress(totalUnitCount: totalSize)
            put(url: url, headers: headers, requestBody: data) { progress in
                progressReport.completedUnitCount = offset + Int64(Float(length) * progress.percent)
                progressHandler(progressReport)
            } completion: { response in
                switch response.result {
                case .success(let result):
                    do {
                        let content = result.content ?? Data()
                        let part = (try JSONDecoder().decode(UploadPart.self, from: content)).part
                        session.parts.append(part)
                        let nextOffset = part.offset + part.size
                        if nextOffset >= totalSize {
                            self.commitUploadSession(session, fileURL: fileURL, completion: completion)
                        } else {
                            self.uploadPart(session: session, fileURL: fileURL, totalSize: totalSize, offset: nextOffset, progressHandler: progressHandler, completion: completion)
                        }
                    } catch {
                        completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                    }
                case .failure(let error):
                    completion(.init(response: response.response, result: .failure(error)))
                }
            }
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
    private func commitUploadSession(_ session: UploadSession, fileURL: URL, completion: @escaping CloudCompletionHandler) {
        let url = uploadURL.appendingPathComponent("files/upload_sessions")
            .appendingPathComponent(session.id)
            .appendingPathComponent("commit")
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            let bufferSize = 1024 * 1024
            var sha1 = Insecure.SHA1()

            var loop = true
            while loop {
                autoreleasepool {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.count > 0 {
                        sha1.update(data: data)
                    } else {
                        loop = false
                    }
                }
            }
            let sha1Hash = sha1.finalize().toBase64()
            let headers = ["Digest": "sha=\(sha1Hash)"]
            let json = ["parts": session.parts.map { $0.toJSON() }]
            post(url: url, json: json, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    print(result)
                    completion(.init(response: result, result: .success(result)))
                case .failure(let error):
                    completion(.init(response: response.response, result: .failure(error)))
                }
            }
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
}

// MARK: - CloudServiceResponseProcessing
extension BoxServiceProvider: CloudServiceResponseProcessing {
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let id = json["id"] as? String,
              let name = json["name"] as? String else {
            return nil
        }
        let isDirectory = (json["type"] as? String) == "folder"
        let item = CloudItem(id: id, name: name, path: name, isDirectory: isDirectory, json: json)
        item.size = (json["size"] as? NSNumber)?.int64Value ?? -1
        item.fileHash = json["sha1"] as? String
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let modified = json["modified_at"] as? String {
            item.modificationDate = dateFormatter.date(from: modified)
        }
        if let createdat = json["created_at"] as? String {
            item.creationDate = dateFormatter.date(from: createdat)
        }
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        // https://developer.box.com/reference/resources/client-error/
        guard let json = response.json as? [String: Any] else { return false }
        if let type = json["type"] as? String, type == "error" {
            let msg = json["message"] as? String
            let code = response.statusCode ?? 400
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(code, msg))))
            return true
        }
        return false
    }
}


fileprivate class UploadSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case numberOfProcessedParts = "num_parts_processed"
        case partSize = "part_size"
        case endPoints = "session_endpoints"
        case sessionExpiresAt = "session_expires_at"
        case totalParts = "total_parts"
    }
    
    struct EndPoint: Codable {
        enum CodingKeys: String, CodingKey {
            case abort
            case commit
            case listParts = "list_parts"
            case logEvent = "log_event"
            case status
            case uploadPart = "upload_part"
        }
        let abort: String?
        let commit: String?
        let listParts: String?
        let logEvent: String?
        let status: String?
        let uploadPart: String?
    }
    
    let id: String
    let type: String
    let numberOfProcessedParts: Int
    let partSize: Int
    let endPoints: EndPoint
    let sessionExpiresAt: String
    let totalParts: Int
    
    var parts: [UploadPart.Part] = []
}

fileprivate class UploadPart: Codable {
    struct Part: Codable {
        enum CodingKeys: String, CodingKey {
            case offset
            case partId = "part_id"
            case sha1
            case size
        }
        let offset: Int64
        let partId: String
        let sha1: String
        let size: Int64
        
        func toJSON() -> [String: Any] {
            return [
                "part_id": partId,
                "offset": offset,
                "sha1": sha1,
                "size": size
            ]
        }
    }
    let part: Part
}
