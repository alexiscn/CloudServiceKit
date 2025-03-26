//
//  PCloudServiceProvider.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2021/8/16.
//

import Foundation
import OAuthSwift

/*
 https://docs.pcloud.com/methods/
 */
public class PCloudServiceProvider: CloudServiceProvider {
    
    public var delegate: CloudServiceProviderDelegate?
    
    /// The name of service provider.
    public var name: String { return "pCloud" }
    
    /// The root folder of pCloud. You can use this property to list root items.
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    public var credential: URLCredential?
    
    /// The API URL of pCloud service.
    public var apiURL = URL(string: "https://api.pcloud.com")!
    
    /// This handler do nothing since pCloud does not return a refresh token.
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    /// Since pCloud API does not provide a search API, we list all files and filter by keyword
    private var allItemsForSearch: [CloudItem] = []
    
    required public init(credential: URLCredential?) {
        self.credential = credential
    }
    
    /// Get information of file. Folder not supported
    /// Document can be found here: https://docs.pcloud.com/methods/file/stat.html
    /// - Parameters:
    ///   - item: The file item
    ///   - completion: Completion block.
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        if item.isDirectory {
            completion(.failure(CloudServiceError.unsupported))
        } else {
            let url = apiURL.appendingPathComponent("stat")
            let data = ["fileid": item.id]
            post(url: url, data: data) { response in
                switch response.result {
                case .success(let result):
                    if let object = result.json as? [String: Any],
                       let item = PCloudServiceProvider.cloudItemFromJSON(object) {
                        completion(.success(item))
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get files of the target directory. You can use `rootItem` to load files in root folder.
    /// Document can be found here: https://docs.pcloud.com/methods/folder/listfolder.html
    /// - Parameters:
    ///   - directoryItem: The target directory.
    ///   - completion: Completion block.
    public func contentsOfDirectory(_ directoryItem: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("listfolder")
        let data = ["folderid": directoryItem.id]
        post(url: url, data: data) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let metadata = json["metadata"] as? [String: Any],
                   let list = metadata["contents"] as? [[String: Any]] {
                    let items = list.compactMap { PCloudServiceProvider.cloudItemFromJSON($0) }
                    items.forEach { item in
                        if item.name == item.path {
                            item.path = [directoryItem.path, item.path].joined(separator: "/")
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
    
    /// Copy file/folder to target directory.
    /// Document can be found here:
    /// https://docs.pcloud.com/methods/file/copyfile.html
    /// https://docs.pcloud.com/methods/folder/copyfolder.html
    /// - Parameters:
    ///   - item: The item to be copied.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "copyfolder": "copyfile"
        let url = apiURL.appendingPathComponent(path)
        var data: [String: Any] = [:]
        data["path"] = path
        post(url: url, data: data, completion: completion)
    }
    
    /// Create a folder at target directory.
    /// Document can be found here: https://docs.pcloud.com/methods/folder/createfolder.html
    /// - Parameters:
    ///   - folderName: The folder name to be create.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("createfolder")
        var data: [String: Any] = [:]
        data["folderid"] = directory.id
        data["name"] = folderName
        post(url: url, data: data, completion: completion)
    }
    
    /// Get the space usage information for the current user's account.
    /// Document can be found here: https://docs.pcloud.com/methods/general/userinfo.html
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("userinfo")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let total = json["quota"] as? Int64,
                   let used = json["usedquota"] as? Int64 {
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
    /// Document can be found here: https://docs.pcloud.com/methods/general/userinfo.html
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("userinfo")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let username = json["email"] as? String {
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
    
    /// Get a download link for file Takes fileid (or path) as parameter and provides links from which the file can be downloaded.
    /// Document can be found here: https://docs.pcloud.com/methods/streaming/getfilelink.html
    /// - Parameters:
    ///   - item: The item to be downloaded.
    ///   - completion: Completion block.
    public func downloadLink(of item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        if item.isDirectory {
            completion(.failure(CloudServiceError.unsupported))
        } else {
            let url = apiURL.appendingPathComponent("getfilelink")
            let params = ["fileid": item.id]
            get(url: url, params: params) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any],
                       let path = json["path"] as? String,
                       let host = (json["hosts"] as? [String])?.first {
                        let urlString = String(format: "https://%@%@", host, path)
                        if let url = URL(string: urlString) {
                            completion(.success(url))
                        }
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Move file/folder item to target directory.
    /// Document can be found here:
    /// https://docs.pcloud.com/methods/file/renamefile.html
    /// https://docs.pcloud.com/methods/folder/renamefolder.html
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "renamefolder" : "renamefile"
        let url = apiURL.appendingPathComponent(path)
        var data: [String: Any] = [:]
        if item.isDirectory {
            data["folderid"] = item.id
        } else {
            data["fileid"] = item.id
        }
        data["tofolderid"] = directory.id
        post(url: url, data: data, completion: completion)
    }
    
    /// Remove file/folder item.
    /// Document can be found here:
    /// Delete File: https://docs.pcloud.com/methods/file/deletefile.html
    /// Delete Folder: https://docs.pcloud.com/methods/folder/deletefolder.html
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "deletefolder": "deletefile"
        let url = apiURL.appendingPathComponent(path)
        var data: [String: Any] = [:]
        if item.isDirectory {
            data["folderid"] = item.id
        } else {
            data["fileid"] = item.id
        }
        post(url: url, data: data, completion: completion)
    }
    
    /// Rename file/folder to a new name.
    /// Document can be found here:
    /// Delete File: https://docs.pcloud.com/methods/file/deletefile.html
    /// Delete Folder: https://docs.pcloud.com/methods/folder/deletefolder.html
    /// - Parameters:
    ///   - item: The item be to renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let path = item.isDirectory ? "renamefolder" : "renamefile"
        let url = apiURL.appendingPathComponent(path)
        var data: [String: Any] = [:]
        data["path"] = item.path
        data["toname"] = newName
        post(url: url, data: data, completion: completion)
    }
    
    /// Search file by a keyword.
    /// - Parameters:
    ///   - keyword: The keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        
        func searchInMemory() {
            let items = allItemsForSearch.filter { $0.name.lowercased().contains(keyword.lowercased()) }
            completion(.success(items))
        }
        
        if allItemsForSearch.isEmpty {
            let url = apiURL.appendingPathComponent("listfolder")
            let data: [String: Any] = [
                "folderid": rootItem.id,
                "recursive": 1
            ]
            post(url: url, data: data) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any],
                       let metadata = json["metadata"] as? [String: Any],
                       let list = metadata["contents"] as? [Any] {
                        
                        var items: [CloudItem] = []
                        func parse(contents: [Any]) {
                            for entry in contents {
                                if let object = entry as? [String: Any],
                                   let item = PCloudServiceProvider.cloudItemFromJSON(object) {
                                    items.append(item)
                                    if let innercontents = item.json["contents"] as? [Any] {
                                        parse(contents: innercontents)
                                    }
                                }
                            }
                        }
                        parse(contents: list)
                        self.allItemsForSearch = items
                        searchInMemory()
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            searchInMemory()
        }
    }
    
    /// Get a streaming link for audio file Takes fileid (or path) of an audio (or video) file and provides links from which audio can be streamed in mp3 format. (Same way getfilelink does with hosts and path)
    /// Document can be found here: https://docs.pcloud.com/methods/streaming/getaudiolink.html
    /// - Parameters:
    ///   - item: The audio item.
    ///   - completion: Completion block.
    public func streamingAudioLink(_ item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("getaudiolink")
        let params = ["fileid": item.id]
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let path = json["path"] as? String,
                   let host = (json["hosts"] as? [String])?.first {
                    let urlString = String(format: "https://%@%@", host, path)
                    if let url = URL(string: urlString) {
                        completion(.success(url))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get a streaming link for video file Takes fileid (or path) of a video file and provides links (same way getfilelink does with hosts and path) from which the video can be streamed with lower bitrate (and/or resolution)
    /// Document can be found here: https://docs.pcloud.com/methods/streaming/getvideolink.html
    /// - Parameters:
    ///   - item: The video item.
    ///   - completion: Completion block.
    public func streamingVideoLink(_ item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("getvideolink")
        let params = ["fileid": item.id]
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let path = json["path"] as? String,
                   let host = (json["hosts"] as? [String])?.first {
                    let urlString = String(format: "https://%@%@", host, path)
                    if let url = URL(string: urlString) {
                        completion(.success(url))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Upload file data to target directory.
    /// Document can be found here: https://docs.pcloud.com/methods/file/uploadfile.html
    /// - Parameters:
    ///   - data: The data to be uploaded.
    ///   - filename: The filename of the data.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter.
    ///   - completion: Completion block.
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("uploadfile")
        
        var postdata: [String: Any] = [:]
        postdata["filename"] = filename
        postdata["folderid"] = directory.id
        
        let file = HTTPFile.data(filename, data, nil)
        let length = Int64(data.count)
        let reportProgress = Progress(totalUnitCount: length)
        post(url: url, data: postdata, files: ["file": file], progressHandler: { progress in
            reportProgress.completedUnitCount = Int64(Float(length) * progress.percent)
            progressHandler(reportProgress)
        }, completion: completion)
    }
    
    /// Upload file to target directory. (NOT TESTED)
    /// Document can be found here: https://docs.pcloud.com/methods/file/uploadfile.html
    /// - Parameters:
    ///   - fileURL: The file url to be uploaded.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter.
    ///   - completion: Completion block.
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard let length = fileSize(of: fileURL) else { return }
        let url = apiURL.appendingPathComponent("uploadfile")
        
        var data: [String: Any] = [:]
        data["filename"] = fileURL.lastPathComponent
        data["folderid"] = directory.id
        
        let file = HTTPFile.url(fileURL, nil)
        let reportProgress = Progress(totalUnitCount: length)
        post(url: url, data: data, files: ["file": file], progressHandler: { progress in
            reportProgress.completedUnitCount = Int64(Float(length) * progress.percent)
            progressHandler(reportProgress)
        }, completion: completion)
    }
}

// MARK: - CloudServiceResponseProcessing
extension PCloudServiceProvider: CloudServiceResponseProcessing {
    
    public static func cloudItemFromJSON(_ json: [String: Any]) -> CloudItem? {
     
        guard let name = json["name"] as? String else {
            return nil
        }
        // path maybe nil when the item is file, we use name as the path.
        let path = json["path"] as? String ?? name
        let isDirectory = (json["isfolder"] as? Bool) ?? false
        let id: String
        if isDirectory, let folderId = json["folderid"] as? Int64 {
            id = String(folderId)
        } else if let fileId = json["fileid"] as? Int64 {
            id = String(fileId)
        } else {
            id = (json["id"] as? String) ?? ""
        }
        let item = CloudItem(id: id, name: name, path: path, isDirectory: isDirectory, json: json)
        item.size = (json["size"] as? Int64) ?? -1
        item.fileHash = json["hash"] as? String
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.dateFormat = "E, dd MMM yyyy HH:mm:ss ZZZZZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let created = json["created"] as? String {
            item.creationDate = dateFormatter.date(from: created)
        }
        if let modified = json["modified"] as? String {
            item.modificationDate = dateFormatter.date(from: modified)
        }
        
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        // https://docs.pcloud.com/protocols/http_json_protocol/
        guard let json = response.json as? [String: Any] else { return false }
        if let code = json["result"] as? Int, code != 0 {
            let msg = json["error"] as? String
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(code, msg))))
            return true
        }
        return false
    }
}

