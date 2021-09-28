//
//  DropboxServiceProvider.swift
//  
//
//  Created by alexiscn on 2021/8/11.
//

import Foundation

/*
 https://www.dropbox.com/developers/documentation/http/documentation
 */
public class DropboxServiceProvider: CloudServiceProvider {

    /// The name of service provider.
    public var name: String { return "Dropbox" }
    
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "") }
    
    public var credential: URLCredential?
    
    public var apiURL = URL(string: "https://api.dropboxapi.com/2")!
    
    public var contentURL = URL(string: "https://content.dropboxapi.com/2")!
    
    /// The refresh access token handler. Used to refresh access token when the token expires.
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    /// Create an instance of DropboxServiceProvider with URLCredential
    /// - Parameter credential: The URLCredential.
    required public init(credential: URLCredential?) {
        self.credential = credential
    }
    
    /// Load the contents at directory.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-list_folder
    /// - Parameters:
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("files/list_folder")
        var json: [String: Any] = [:]
        json["path"] = directory.path
        json["recursive"] = false
        
        post(url: url, json: json) { response in
            switch response.result {
            case .success(let result):
                if let jsonObject = result.json as? [String: Any], let list = jsonObject["entries"] as? [Any] {
                    var items: [CloudItem] = []
                    for entry in list {
                        if let object = entry as? [String: Any],
                           let item = DropboxServiceProvider.cloudItemFromJSON(object) {
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
    
    /// Get metadata for a file or folder.
    /// - Parameters:
    ///   - item: The item to request metadata information.
    ///   - completion: Completion block.
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("files/get_metadata")
        var json: [String: Any] = [:]
        json["path"] = item.path
        json["include_media_info"] = true
        json["include_deleted"] = false
        json["include_has_explicit_shared_members"] = false
        post(url: url, json: json) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let item = DropboxServiceProvider.cloudItemFromJSON(object) {
                    completion(.success(item))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Copy a file or folder to a different location in the user's Dropbox.
    /// - Parameters:
    ///   - item: The item to be copied.
    ///   - directory: The destination directory.
    ///   - completion: Completion block.
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/copy_v2")
        var json: [String: Any] = [:]
        json["from_path"] = item.path
        json["to_path"] = directory.path
        post(url: url, json: json, completion: completion)
    }
    
    /// Create a folder at a given directory.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-create_folder
    /// - Parameters:
    ///   - folderName: The folder name to be created.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/create_folder_v2")
        var json: [String: Any] = [:]
        json["path"] = [directory.path, folderName].joined(separator: "/")
        json["autorename"] = true
        post(url: url, json: json, completion: completion)
    }
    
    public func downloadData(item: CloudItem, progressHandler: ((Progress) -> Void)? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        let url = contentURL.appendingPathComponent("files/download")
        let headers = ["Dropbox-API-Arg": dropboxAPIArg(from: ["path": item.path])]
        post(url: url, headers: headers, progressHandler: { progress in
            let p = Progress(totalUnitCount: progress.bytesExpectedToProcess + progress.bytesProcessed)
            p.completedUnitCount = progress.bytesProcessed
            progressHandler?(p)
        }) { response in
            switch response.result {
            case .success(let result):
                if let data = result.content, !data.isEmpty {
                    completion(.success(data))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
                // TODO: check Dropbox-API-Arg in header
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get the space usage information for the current user's account.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#users-get_space_usage
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("users/get_space_usage")
        post(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let used = json["used"] as? Int64,
                   let allocation = json["allocation"] as? [String: Any],
                   let total = allocation["allocated"] as? Int64 {
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
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#users-get_current_account
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("users/get_current_account")
        post(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let nameObject = json["name"] as? [String: Any],
                   let name = nameObject["display_name"] as? String {
                    let account = CloudUser(username: name, json: json)
                    completion(.success(account))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get a temporary link to stream content of a file. This link will expire in four hours and afterwards you will get 410 Gone.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-get_temporary_link
    /// - Parameters:
    ///   - item: The video or audio item to streaming.
    ///   - completion: Completion block.
    public func getTemporaryLink(item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("files/get_temporary_link")
        let json = ["path": item.path]
        post(url: url, json: json) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let link = object["link"] as? String, let url = URL(string: link) {
                    completion(.success(url))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Delete the file or folder.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-delete
    /// - Parameters:
    ///   - item: The item to be deleted.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/delete_v2")
        let json = ["path": item.path]
        post(url: url, json: json, completion: completion)
    }
    
    /// Rename the file or folder to a new name.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-move
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name of the item.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/move_v2")
        var components = item.path.components(separatedBy: "/").dropLast()
        components.append(newName)
        let toPath = components.joined(separator: "/")
        
        var json: [String: Any] = [:]
        json["from_path"] = item.path
        json["to_path"] = toPath
        json["autorename"] = true
        post(url: url, json: json, completion: completion)
    }
    
    /// Move the file or folder to a new directory.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-move
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/move_v2")
        
        var components = item.path.components(separatedBy: "/")
        let filename = components.removeLast()
        let toPath = [directory.path, filename].joined(separator: "/")
        
        var json: [String: Any] = [:]
        json["from_path"] = item.path
        json["to_path"] = toPath
        json["autorename"] = true
        post(url: url, json: json, completion: completion)
    }
    
    /// Searches for files and folders
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-search
    /// - Parameters:
    ///   - keyword: The string to search for. May match across multiple fields based on the request arguments.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("files/search_v2")
        var json: [String: Any] = [:]
        json["query"] = keyword
        json["options"] = ["path": rootItem.path]
        post(url: url, json: json) { response in
            switch response.result {
            case .success(let result):
                if let jsonObject = result.json as? [String: Any], let list = jsonObject["matches"] as? [Any] {
                    var items: [CloudItem] = []
                    for entry in list {
                        if let metadata = entry as? [String: Any],
                           let metadataObj = metadata["metadata"] as? [String: Any],
                           let object = metadataObj["metadata"] as? [String: Any],
                           let item = DropboxServiceProvider.cloudItemFromJSON(object) {
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
    
    /// Create a new file with the contents provided in the request.
    /// Document can be found here: https://www.dropbox.com/developers/documentation/http/documentation#files-upload
    /// - Parameters:
    ///   - data: The data to be uploaded.
    ///   - filename: The filename to be created.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter.
    ///   - completion: Completion block.
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        // data can not bigger than 150M
        // If you want to upload large file, please use: `uploadFile(:to:progressHandler:completion)`.
        if data.count > 150 * 1024 * 1024 {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        
        let url = contentURL.appendingPathComponent("files/upload")
        
        var dict: [String: Any] = [:]
        dict["path"] = [directory.path, filename].joined(separator: "/")
        dict["mode"] = "add"
        dict["autorename"] = true
        dict["mute"] = false
        let headers = [
            "Dropbox-API-Arg": dropboxAPIArg(from: dict),
            "Content-Type": "application/octet-stream"
        ]
    
        let length = Int64(data.count)
        let reportProgress = Progress(totalUnitCount: length)
        post(url: url, headers: headers, requestBody: data, progressHandler: { progress in
            reportProgress.completedUnitCount = Int64(Float(length) * progress.percent)
            progressHandler(reportProgress)
        }, completion: completion)
    }
    
    /// Upload file to target directory with local file url.
    /// Note: remote file url is not supported.
    /// - Parameters:
    ///   - fileURL: The local file url.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        guard FileManager.default.fileExists(atPath: fileURL.path), let totalSize = fileSize(of: fileURL) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        
        let url = contentURL.appendingPathComponent("files/upload_session/start")
        var headers: [String: String] = [:]
        headers["Dropbox-API-Arg"] = "{\"close\": false}"
        headers["Content-Type"] = "application/octet-stream"
        
        post(url: url, headers: headers) { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let sessionId = json["session_id"] as? String {
                    self.appendUploadSession(fileURL: fileURL, to: directory, totalSize: totalSize, offset: 0, sessionId: sessionId, progressHandler: progressHandler, completion: completion)
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
}

// MARK: - Helper
extension DropboxServiceProvider {
    
    public func dropboxAPIArg(from dictionary: [String: Any]) -> String {
        return dictionary.json.asciiEscaped().replacingOccurrences(of: "\\/", with: "/")
    }
    
}

// MARK: - Chunk upload
extension DropboxServiceProvider {
    
    private func appendUploadSession(fileURL: URL, to directory: CloudItem, totalSize: Int64, offset: Int64, sessionId: String, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        do {
            //upload_session/append:2 call must be multiple of 4194304 bytes (except for last
            let chunkSize: Int64 = 4194304 * 2
            let length = min(chunkSize, totalSize - offset)
            let handle = try FileHandle(forReadingFrom: fileURL)
            try handle.seek(toOffset: UInt64(offset))
            let data = handle.readData(ofLength: Int(length))
            try handle.close()
            
            let url = contentURL.appendingPathComponent("files/upload_session/append_v2")
            
            var args: [String: Any] = [:]
            args["close"] = length < chunkSize // if length is small than chunSize, means it is the last part
            args["cursor"] = [
                "session_id": sessionId,
                "offset": offset
            ]
            
            let headers = [
                "Dropbox-API-Arg": dropboxAPIArg(from: args),
                "Content-Type": "application/octet-stream"
            ]
            
            let progressReport = Progress(totalUnitCount: totalSize)
            post(url: url, headers: headers, requestBody: data) { progress in
                progressReport.completedUnitCount = offset + Int64(Float(length) * progress.percent)
                progressHandler(progressReport)
            } completion: { response in
                switch response.result {
                case .success(_):
                    let nextOffset = offset + length
                    if nextOffset >= totalSize {
                        let path = [directory.path, fileURL.lastPathComponent].joined(separator: "/")
                        self.finishSession(sessionId, path: path, offset: totalSize, completion: completion)
                    } else {
                        self.appendUploadSession(fileURL: fileURL, to: directory, totalSize: totalSize, offset: nextOffset, sessionId: sessionId, progressHandler: progressHandler, completion: completion)
                    }
                case .failure(let error):
                    completion(.init(response: response.response, result: .failure(error)))
                }
            }
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
    private func finishSession(_ sessionId: String, path: String, offset: Int64, completion: @escaping CloudCompletionHandler) {
        let url = contentURL.appendingPathComponent("files/upload_session/finish")
        
        var args: [String: Any] = [:]
        args["commit"] = [
            "path": path,
            "mode": "add",
            "autorename": true,
            "mute": false,
            "strict_conflict": false
        ]
        args["cursor"] = [
            "session_id": sessionId,
            "offset": offset
        ]
        let headers = [
            "Dropbox-API-Arg": dropboxAPIArg(from: args),
            "Content-Type": "application/octet-stream"
        ]
        post(url: url, headers: headers) { response in
            switch response.result {
            case .success(let result):
                completion(.init(response: result, result: .success(result)))
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
}

// MARK: - CloudServiceResponseProcessing
extension DropboxServiceProvider: CloudServiceResponseProcessing {
    
    public static func cloudItemFromJSON(_ json: [String: Any]) -> CloudItem? {
        
        guard let name = json["name"] as? String, let path = json["path_display"] as? String else {
            return nil
        }
        let id = (json["id"] as? String) ?? "" // id:abcd1234
        let isDirectory = (json[".tag"] as? String) == "folder"
        let item = CloudItem(id: id, name: name, path: path, isDirectory: isDirectory, json: json)
        item.size = (json["size"] as? Int64) ?? -1
        item.fileHash = json["content_hash"] as? String
        
        if let modified = json["client_modified"] as? String {
            let dateFormatter = ISO8601DateFormatter()
            item.modificationDate = dateFormatter.date(from: modified)
        }
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        // https://developers.dropbox.com/error-handling-guide
        guard let json = response.json as? [String: Any] else { return false }
        if let error = json["error"] as? [String: Any], !error.isEmpty {
            let msg = (json["user_message"] as? String) ?? (json["error_summary"] as? String)
            let code = response.statusCode ?? 400
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(code, msg))))
            return true
        }
        return false
    }
}

// MARK: - CloudServiceBatching
extension DropboxServiceProvider: CloudServiceBatching {
    
    public func removeItems(_ items: [CloudItem], completion: @escaping CloudCompletionHandler) {
        func check(jobId: String) {
            let url = apiURL.appendingPathComponent("files/delete_batch/check")
            let data = ["async_job_id": jobId]
            post(url: url, data: data) { response in
//                switch response {
//                case .success(let result):
//                    if let json = result.json as? [String: Any], let tag = json[".tag"] as? String {
//                        if tag == "complete" {
//                            completion(.success(result))
//                        } else {
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
//                                check(jobId: jobId)
//                            })
//                        }
//                    }
//                case .failure(let error):
//                    completion(.failure(error))
//                }
            }
        }
        
        func remove() {
            let url = apiURL.appendingPathComponent("files/delete_batch")
            let entries = items.map { ["path": $0.path] }
            let data = ["entries": entries]
            post(url: url, data: data) { response in
//                switch response {
//                case .success(let result):
//                    if let json = result.json as? [String: Any],
//                       let jobId = json["async_job_id"] as? String {
//                       check(jobId: jobId)
//                    }
//                case .failure(let error):
//                    completion(.failure(error))
//                }
            }
        }
        
        remove()
    }
    
    public func moveItems(_ items: [CloudItem], to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        
    }
    
    
}

