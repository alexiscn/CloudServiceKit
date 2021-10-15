//
//  OneDriveServiceProvider.swift
//
//
//  Created by alexiscn on 2021/8/11.
//

import Foundation

/*
 A wrapper for OneDrive using OAuth2.
 Documents can be found here:
 https://docs.microsoft.com/en-us/onedrive/developer/rest-api/?view=odsp-graph-online
 */
public class OneDriveServiceProvider: CloudServiceProvider {
    
    public var delegate: CloudServiceProviderDelegate?
    
    /// Route to access file container on OneDrive. For default logined user use `.me` otherwise you can acesss
    /// container based on drive id, group id, site id or user id for another user's default container
    public enum Route {
        /// Access to default container for current user
        case me
        /// Access to a specific drive by id
        case drive(String)
        /// Access to a default drive of a group by their id
        case group(String)
        /// Access to a default drive of a site by their id
        case site(String)
        /// Access to a default drive of a user by their id
        case user(String)
        
        var drives: String {
            switch self {
            case .me: return "me/drives"
            case .drive(let driveId): return "drives/\(driveId)"
            case .group(let groupId): return "groups/\(groupId)/drives"
            case .site(let siteId): return "sites/\(siteId)/drives"
            case .user(let userId): return "users/\(userId)/drives"
            }
        }
        
        func url(of subpath: String) -> URL {
            let path: String
            switch self {
            case .me: path = "me/drive/" + subpath
            case .drive(let driveId): path = "drives/\(driveId)/" + subpath
            case .group(let groupId): path = "groups/\(groupId)/drive/" + subpath
            case .site(let siteId): path = "sites/\(siteId)/drive/" + subpath
            case .user(let userId): path = "users/\(userId)/drive" + subpath
            }
            return URL(string: "https://graph.microsoft.com/v1.0")!.appendingPathComponent(path)
        }
    }
    
    /// The name of service provider.
    public var name: String { return "OneDrive" }
    
    /// The root folder of OneDrove service. You can use this property to list root items.
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "") }
    
    public var credential: URLCredential?
    
    private var apiURL = URL(string: "https://graph.microsoft.com/v1.0")!
    
    public let route: Route
    
    /// The refresh access token handler. Used to refresh access token when the token expires.
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    /// Create an instance of OneDriveServiceProvider of personal drive.
    /// - Parameter credential: The credential to sign in OneDrive.
    public required init(credential: URLCredential?) {
        self.credential = credential
        self.route = .me
    }
    
    /// Create an instance of OneDriveServiceProvider.
    /// - Parameters:
    ///   - credential: The credential to sign in OneDrive.
    ///   - route: The route. See `Route` to view more details.
    public init(credential: URLCredential?, route: Route) {
        self.credential = credential
        self.route = route
    }
    
    /// Get attributes of cloud item.
    /// - Parameters:
    ///   - item: The item.
    ///   - completion: Completion block.
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("me/drive/items/\(item.id)")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let item = OneDriveServiceProvider.cloudItemFromJSON(json) {
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
        
        var items: [CloudItem] = []
        
        func load(nextLink: String?) {
            let url: URL
            if let link = nextLink, !link.isEmpty, let linkURL = URL(string: link) {
                url = linkURL
            } else if directory.path.isEmpty {
                url = apiURL.appendingPathComponent("me/drive/root/children")
            } else {
                url = apiURL.appendingPathComponent("me/drive/items/\(directory.id)/children")
            }
            let params = ["$expand": "thumbnails"]
            get(url: url, params: params) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any], let files = json["value"] as? [[String: Any]] {
                        items.append(contentsOf: files.compactMap { OneDriveServiceProvider.cloudItemFromJSON($0) })
                        
                        if let nextLink = json["odata.nextLink"] as? String, !nextLink.isEmpty {
                            load(nextLink: nextLink)
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
        
        load(nextLink: nil)
    }
    
    /// Asynchronously creates a copy of an driveItem (including any children), under a new parent item or with a new name.
    /// Document can be found here: https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/driveitem_copy?view=odsp-graph-online
    /// - Parameters:
    ///   - item: The item to be copied.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("me/drive/items/\(item.id)/copy")
        var json: [String: Any] = [:]
        json["parentReference"] = ["id": directory.id]
        post(url: url, json: json, completion: completion)
    }
    
    /// Create a new folder or DriveItem in a Drive with a specified parent item or path.
    /// Document can be found here: https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/driveitem_post_children?view=odsp-graph-online
    /// - Parameters:
    ///   - folderName: The folder name to be created.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("me/drive/items/\(directory.id)/children")
        var json: [String: Any] = [:]
        json["name"] = folderName
        json["folder"] = [:]
        json["@microsoft.graph.conflictBehavior"] = "rename"
        post(url: url, json: json, completion: completion)
    }
    
    /// Get download link of file.
    /// Note: folder not supported.
    /// - Parameters:
    ///   - item: The file to be downloaded.
    ///   - completion: Completion block.
    public func downloadLink(of item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        if item.isDirectory {
            completion(.failure(CloudServiceError.unsupported))
        } else {
            let url = apiURL.appendingPathComponent("me/drive/items/\(item.id)/content")
            get(url: url) { response in
                switch response.result {
                case .success(let result):
                    if let location = result.headers["Content-Location"], let url = URL(string: location) {
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
    
    /// Get the space usage information for the current user's account.
    /// Document can be found here: https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/drive_get?view=odsp-graph-online
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("me")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let quota = json["quota"] as? [String: Any],
                   let total = quota["total"] as? Int64,
                   let free = quota["remaining"] as? Int64 {
                    let info = CloudSpaceInformation(totalSpace: total, availableSpace: free, json: json)
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
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("me")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let name = json["displayName"] as? String {
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
    
    /// Delete a DriveItem by using its ID or path. Note that deleting items using this method will move the items to the recycle bin instead of permanently deleting the item.
    /// - Parameters:
    ///   - item: The item to be delete.
    ///   - completion: Completion callback.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("me/drive/items/\(item.id)")
        delete(url: url, completion: completion)
    }
    
    /// Rename a DriveItem to a new name.
    /// - Parameters:
    ///   - item: The item to be renamed
    ///   - newName: The new name.
    ///   - completion: Completion callback.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("me/drive/items/\(item.id)")
        let json = ["name": newName]
        patch(url: url, json: json, completion: completion)
    }
    
    /// Move item to target directory.
    /// Document can be found here: https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/driveitem_move?view=odsp-graph-online
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("me/drive/items/\(item.id)")
        var json: [String: Any] = [:]
        json["name"] = item.name
        json["parentReference"] = ["id": directory.id]
        patch(url: url, json: json, completion: completion)
    }
    
    /// Search the hierarchy of items for items matching a query. You can search within a folder hierarchy, a whole drive, or files shared with the current user.
    /// Document can be found here: https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/driveitem_search?view=odsp-graph-online
    /// - Parameters:
    ///   - keyword: The query keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("me/drive/root/search(q='\(keyword)')")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let files = json["value"] as? [[String: Any]] {
                    let items = files.compactMap { OneDriveServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Upload data to cloud service.
    /// - Parameters:
    ///   - data: The data to be upload.
    ///   - filename: The filename to be created at the cloud service.
    ///   - directory: The target folder.
    ///   - progressHandler: The upload progress.
    ///   - completion: Completion callback.
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        if data.count >= 10 * 1024 * 1024 {
            do {
                let path = NSTemporaryDirectory().appending(filename)
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.removeItem(atPath: path)
                }
                try data.write(to: URL(fileURLWithPath: path))
                uploadFile(URL(fileURLWithPath: path), to: directory, progressHandler: progressHandler, completion: completion)
            } catch {
                completion(.init(response: nil, result: .failure(error)))
            }
            return
        }
        let url = apiURL.appendingPathComponent("me/drive/items/\(directory.id):/\(filename):/content")
        put(url: url, requestBody: data, completion: completion)
    }
    
    /// Upload file to target directory with local file url.
    /// Note: remote url is not supported.
    /// - Parameters:
    ///   - fileURL: The local file url.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let folderPath: String
        if directory.path.hasPrefix("/") {
            folderPath = String(directory.path.dropFirst())
        } else {
            folderPath = directory.path
        }
        let url = apiURL.appendingPathComponent("\(folderPath)/\(fileURL.lastPathComponent):/createUploadSession")
        post(url: url) { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let uploadUrl = json["uploadUrl"] as? String {
                    self.performUpload(fileURL: fileURL, uploadUrl: uploadUrl, progressHandler: progressHandler, completion: completion)
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
}


// MARK: - CloudServiceResponseProcessing
extension OneDriveServiceProvider: CloudServiceResponseProcessing {
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let name = json["name"] as? String, let id = json["id"] as? String else { return nil }
        
        let path: String
        if let parentReference = json["parentReference"] as? [String: Any],
           let parentPath = (parentReference["path"] as? String)?.removingPercentEncoding {
            path = [parentPath, name].joined(separator: "/")
        } else {
            path = name
        }
        let isDirectory = json["folder"] != nil
        let item = CloudItem(id: id, name: name, path: path, isDirectory: isDirectory, json: json)
        item.size = (json["size"] as? Int64) ?? -1
        if let file = json["file"] as? [String: Any],
           let hashes = file["hashes"] as? [String: Any] {
            item.fileHash = hashes["sha1Hash"] as? String
        }
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        // https://docs.microsoft.com/en-us/onedrive/developer/rest-api/concepts/errors?view=odsp-graph-online
        guard let json = response.json as? [String: Any] else { return false }
        if let error = json["error"] as? [String: Any] {
            let code = response.statusCode ?? 400
            let msg = error["message"] as? String
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(code, msg))))
            return true
        }
        return false
    }
}


// MARK: - Chunk upload
extension OneDriveServiceProvider {
    
    private func performUpload(fileURL: URL, uploadUrl: String, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        do {
            let fileAttribute = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let totalLength = (fileAttribute[.size] as? Int64) ?? -1
            guard totalLength > 0 else {
                // TODO completion with error, file can not be read
                return
            }
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            // The recommended fragment size is between 5-10 MiB.
            let maximumChunkSize = 5 * 1024 * 1024
            let progress = Progress(totalUnitCount: totalLength)
            
            func perform(expectedRange: String, totalLength: Int64) {
                do {
                    let components = expectedRange.split(separator: "-").compactMap { Int64($0) }
                    guard components.count > 0 else {
                        // TODO invalid expectedRange
                        try fileHandle.close()
                        return
                    }
                    let startOffset: Int64 = components[0]
                    let endOffset: Int64 = components.last ?? totalLength
                    
                    try fileHandle.seek(toOffset: UInt64(startOffset))
                    let length = min(Int(endOffset - startOffset) + 1, maximumChunkSize)
                    let data = fileHandle.readData(ofLength: length)
                    let range = String(format: "%ld-%ld", startOffset, startOffset + Int64(length) - 1)
                    
                    var headers: [String: String] = [:]
                    headers["Content-Length"] = String(data.count)
                    headers["Content-Range"] = String(format: "bytes %@/%ld", range, totalLength)
                    put(url: uploadUrl, headers: headers, requestBody: data, progressHandler: { changes in
                        progress.completedUnitCount = startOffset + changes.bytesProcessed
                        progressHandler(progress)
                    }) { response in
                        switch response.result {
                        case .success(let result):
                            if let json = result.json as? [String: Any] {
                                if let nextExpectedRange = (json["nextExpectedRanges"] as? [String])?.first {
                                    perform(expectedRange: nextExpectedRange, totalLength: totalLength)
                                } else if json["file"] != nil {
                                    progress.completedUnitCount = totalLength
                                    progressHandler(progress)
                                    try? fileHandle.close()
                                    completion(.init(response: result, result: .success(result)))
                                }
                            } else {
                                try? fileHandle.close()
                                completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                            }
                        case .failure(let error):
                            try? fileHandle.close()
                            completion(.init(response: response.response, result: .failure(error)))
                        }
                    }
                } catch {
                    completion(.init(response: nil, result: .failure(error)))
                }
            }
            
            perform(expectedRange: "0-\(maximumChunkSize - 1)", totalLength: totalLength)
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
}
