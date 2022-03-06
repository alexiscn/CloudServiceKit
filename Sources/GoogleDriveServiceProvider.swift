//
//  GoogleDriveServiceProvider.swift
//  
//
//  Created by alexsicn on 2021/8/11.
//

import Foundation

/*
 A wrapper for Google Drive using OAuth2.
 Documents can be found here:
 https://developers.google.com/drive/api/v3/reference
 */
public class GoogleDriveServiceProvider: CloudServiceProvider {

    public var delegate: CloudServiceProviderDelegate?
    
    /// The name of service provider.
    public var name: String { return "GoogleDrive" }
    
    /// If not empty, file operation do to target shared drive
    public var sharedDrive: SharedDrive? = nil
    
    public var rootItem: CloudItem {
        if let sharedDrive = sharedDrive {
            return CloudItem(id: sharedDrive.id, name: sharedDrive.name, path: "/")
        } else {
            return CloudItem(id: "root", name: name, path: "/")
        }
    }
        
    public var credential: URLCredential?
    
    /// The api url of Google Drive Service. Which is [https://www.googleapis.com/drive/v3]() .
    public var apiURL = URL(string: "https://www.googleapis.com/drive/v3")!
    
    /// The upload url of Google Drive Service. Which is [https://www.googleapis.com/upload/drive/v3](https://www.googleapis.com/upload/drive/v3) .
    public var uploadURL = URL(string: "https://www.googleapis.com/upload/drive/v3")!
    
    /// The refresh access token handler. Used to refresh access token when the token expires.
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    /// The chunk size of resumable upload. The value is 6M.
    public let chunkSize: Int64 = 6 * 1024 * 1026
    
    required public init(credential: URLCredential?) {
        self.credential = credential
    }

    /// Get attributes of cloud item.
    /// - Parameters:
    ///   - item: The target item.
    ///   - completion: Completion callback.
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("files/\(item.id)")
        var params: [String: Any] = [:]
        params["fields"] = "*"
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let item = GoogleDriveServiceProvider.cloudItemFromJSON(json) {
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
        let url = apiURL.appendingPathComponent("files")
        var contents: [CloudItem] = []
        func fetch(pageToken: String? = nil) {
            var params: [String: Any] = [:]
            params["q"] = String(format: "trashed = false and '%@' in parents", directory.id)
            params["fields"] = "files(id,kind,name,size,createdTime,modifiedTime,mimeType,md5Checksum,webContentLink,thumbnailLink,shortcutDetails),nextPageToken"
            if let pageToken = pageToken {
                params["pageToken"] = pageToken
            }
            params["includeItemsFromAllDrives"] = true
            params["supportsAllDrives"] = true
            if let sharedDrive = sharedDrive {
                params["includeItemsFromAllDrives"] = true
                params["driveId"] = sharedDrive.id
                params["supportsAllDrives"] = true
                params["corpora"] = "drive"
            }
            get(url: url, params: params) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any], let files = json["files"] as? [[String: Any]] {
                        let items = files.compactMap { GoogleDriveServiceProvider.cloudItemFromJSON($0) }
                        items.forEach { $0.fixPath(with: directory) }
                        contents.append(contentsOf: items)
                        if let nextPageToken = json["nextPageToken"] as? String, !nextPageToken.isEmpty {
                            fetch(pageToken: nextPageToken)
                        } else {
                            completion(.success(contents))
                        }
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        fetch(pageToken: nil)
    }
    
    /// Creates a copy of a file.
    /// Note: Folders cannot be copied.
    /// Document can be found here: https://developers.google.com/drive/api/v3/reference/files/copy
    /// - Parameters:
    ///   - item: The file to be copied.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        if item.isDirectory {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
        } else {
            let url = apiURL.appendingPathComponent("files/\(item.id)/copy")
            var data: [String: Any] = [:]
            data["parents"] = [directory.id]
            post(url: url, data: data, completion: completion)
        }
    }
    
    /// Create a folder at a given directory.
    /// Document can be found here https://developers.google.com/drive/api/v3/reference/files/create
    /// - Parameters:
    ///   - folderName: Folder name to be created.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files")
        var data: [String: Any] = [:]
        data["mimeType"] = MIMETypes.folder
        data["name"] = folderName
        data["parents"] = [directory.id]
        
        var params: [String: Any] = [:]
        if let sharedDrive = sharedDrive {
            params["includeItemsFromAllDrives"] = true
            params["driveId"] = sharedDrive.id
            params["supportsAllDrives"] = true
            params["corpora"] = "drive"
        }
        post(url: url, params: params, json: data, completion: completion)
    }
    
    /// Get downloadable request of cloud file.
    /// - Parameter item: The item to be downloaded.
    /// - Returns: Completion block.
    public func downloadableRequest(of item: CloudItem) -> URLRequest? {
        if item.isDirectory {
            return nil
        }
        let url = apiURL.appendingPathComponent("files/\(item.id)")
        let params = ["alt": "media"]
        let headers: CaseInsensitiveDictionary = ["Authorization": "Bearer \(credential?.password ?? "")"]
        return Just.adaptor.synthesizeRequest(.get, url: url, params: params, data: [:], json: nil, headers: headers, files: [:], auth: nil, timeout: nil, urlQuery: nil, requestBody: nil)
    }
    
    /// Get the space usage information for the current user's account.
    /// Document can be found here: https://developers.google.com/drive/api/v3/reference/about#resource
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("about")
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let storageQuota = json["storageQuota"] as? [String: Any],
                   let total = storageQuota["limit"] as? Int64,
                   let used = storageQuota["usageInDrive"] as? Int64 {
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
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = "https://www.googleapis.com/oauth2/v2/userinfo"
        get(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let name = json["name"] as? String {
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
    
    /// Lists the user's shared drives.
    /// - Parameter completion: Completion block.
    public func listSharedDrives(completion: @escaping (Result<[GoogleDriveServiceProvider.SharedDrive], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("drives")
        
        var drives: [GoogleDriveServiceProvider.SharedDrive] = []
        func fetch(pageToken: String? = nil) {
            var params: [String: Any] = [:]
            params["pageSize"] = 50
            if let pageToken = pageToken {
                params["pageToken"] = pageToken
            }
            
            get(url: url, params: params) { response in
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any], let list = json["drives"] as? [Any] {
                        for item in list {
                            if let object = item as? [String: Any],
                                let id = object["id"] as? String,
                                let name = object["name"] as? String {
                                let drive = SharedDrive(id: id, name: name)
                                drives.append(drive)
                            }
                        }
                        if let nextPageToken = json["nextPageToken"] as? String, !nextPageToken.isEmpty {
                            fetch(pageToken: nextPageToken)
                        } else {
                            completion(.success(drives))
                        }
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        fetch()
    }
    
    /// Move item to target directory.
    /// Document can be found here: https://developers.google.com/drive/api/v3/reference/files/update
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/\(item.id)")
        var params: [String: Any] = [:]
        params["addParents"] = directory.id
        //params["removeParents"] = item
        patch(url: url, params: params, completion: completion)
    }
    
    /// Permanently deletes a file owned by the user without moving it to the trash.
    /// If the file belongs to a shared drive the user must be an organizer on the parent.
    /// If the target is a folder, all descendants owned by the user are also deleted.
    /// Document can be found here: https://developers.google.com/drive/api/v3/reference/files/delete
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion callback.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/\(item.id)")
        var params: [String: Any] = [:]
        if sharedDrive != nil {
            params["supportsAllDrives"] = true
        }
        delete(url: url, params: params, completion: completion)
    }
    
    /// Rename cloud file to a new name.
    /// Document can be found here: https://developers.google.com/drive/api/v3/reference/files/update
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("files/\(item.id)")
        var json: [String: Any] = [:]
        json["name"] = newName
        
        var params: [String: Any] = [:]
        if sharedDrive != nil {
            params["supportsAllDrives"] = true
        }
        patch(url: url, params: params, json: json, completion: completion)
    }

    /// Search files which name contains keyword.
    /// Document can be found here: https://developers.google.com/drive/api/v3/search-files
    /// - Parameters:
    ///   - keyword: The query keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("files")
        var params: [String: Any] = [:]
        params["q"] = "name contains '\(keyword)'"
        params["fields"] = "files(id,kind,name,size,createdTime,modifiedTime,mimeType,parents)"
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let files = json["files"] as? [[String: Any]] {
                    let items = files.compactMap { GoogleDriveServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Upload file to directory.
    /// Document can be found here: https://developers.google.com/drive/api/v3/manage-uploads#multipart
    /// - Parameters:
    ///   - data: The file data to be uploaded.
    ///   - filename: The filename to be created.
    ///   - directory: The target directory.
    ///   - progressHandler: The progress report of upload.
    ///   - completion: Completion block.
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let url = uploadURL.appendingPathComponent("files")
        var params: [String: Any] = [:]
        params["uploadType"] = "multipart"
        if sharedDrive != nil {
            params["supportsAllDrives"] = true
        }
        let json: [String: Any] = ["name": filename, "parents": [directory.id]]
        
        // Google Drive multipart upload is not supported by Just
        // So here we construct the request body manually
        let boundary = "Ju5tH77P15Aw350m3"
        var body = Data()
        body.append("--" + boundary + "\n")
        body.append("Content-Type: application/json; charset=UTF-8")
        body.append("\n\n")
        body.append(json.json)
        body.append("\n\n")
        body.append("--" + boundary + "\n")
        body.append("Content-Type: application/octet-stream")
        body.append("\n\n")
        body.append(data)
        body.append("\n")
        body.append("--" + boundary + "--\n")
        
        let headers = ["Content-Type": "multipart/related; boundary=\(boundary)"]
        let length = Int64(data.count)
        let reportProgress = Progress(totalUnitCount: length)
        post(url: url, params: params, headers: headers, requestBody: body, progressHandler: { progress in
            reportProgress.completedUnitCount = Int64(Float(length) * progress.percent)
            progressHandler(reportProgress)
        }, completion: completion)
    }
    
    /// Upload file to target directory with local file url.
    /// Note: remote file url is not supported.
    /// Document can be found here: https://developers.google.com/drive/api/v3/manage-uploads#resumable
    /// - Parameters:
    ///   - fileURL: The local file url.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        createUploadRequest(fileURL: fileURL, directory: directory, progressHandler: progressHandler, completion: completion)
    }
}

// MARK: - Upload
extension GoogleDriveServiceProvider {
    
    // https://developers.google.com/drive/api/v3/manage-uploads#send_the_initial_request
    private func createUploadRequest(fileURL: URL, directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        guard let size = fileSize(of: fileURL) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        
        let url = uploadURL.appendingPathComponent("files")
        var params: [String: Any] = [:]
        params["uploadType"] = "resumable"
        if sharedDrive != nil {
            params["supportsAllDrives"] = true
        }
        
        let json: [String: Any] = ["name": fileURL.lastPathComponent, "parents": [directory.id]]
        post(url: url, params: params, json: json) { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let result):
                if let location = result.headers["Location"] {
                    let session = UploadSession(fileURL: fileURL, size: size, uploadUrl: location)
                    self.uploadFile(session, offset: 0, progressHandler: progressHandler, completion: completion)
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
    
    // https://developers.google.com/drive/api/v3/manage-uploads#uploading
    private func uploadFile(_ session: UploadSession, offset: Int64, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        do {
            let handle = try FileHandle(forReadingFrom: session.fileURL)
            try handle.seek(toOffset: UInt64(offset))
            let length = min(chunkSize, session.size - offset)
            let data = handle.readData(ofLength: Int(length))
            try handle.close()
            
            let range = String(format: "bytes %ld-%ld/%ld", offset, offset + length - 1, session.size)
            let headers = [
                "Content-Length": String(length),
                "Content-Range": range
            ]
            
            let progressReport = Progress(totalUnitCount: session.size)
            put(url: session.uploadUrl, headers: headers, requestBody: data) { progress in
                progressReport.completedUnitCount = offset + Int64(Float(length) * progress.percent)
                progressHandler(progressReport)
            } completion: { response in
                switch response.result {
                case .success(let result):
                    if result.statusCode == 200 || result.statusCode == 201 {
                        completion(.init(response: result, result: .success(result)))
                    } else {
                        let nextOffset: Int64
                        if let header = result.headers["range"],
                           header.contains("-"),
                           let upper = header.components(separatedBy: "-").last {
                            nextOffset = Int64(upper) ?? offset + length
                        } else {
                            nextOffset = offset + length
                        }
                        self.uploadFile(session, offset: nextOffset, progressHandler: progressHandler, completion: completion)
                    }
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
extension GoogleDriveServiceProvider: CloudServiceResponseProcessing {
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let name = json["name"] as? String, let id = json["id"] as? String else {
            return nil
        }
        let mimeType = json["mimeType"] as? String
        let isDirectory = mimeType == MIMETypes.folder
        let item = CloudItem(id: id, name: name, path: name, isDirectory: isDirectory, json: json)
        /// while the size field describe as long in document, but the actually response type is String
        if let size = json["size"] as? Int64 {
            item.size = size
        } else if let size = json["size"] as? String {
            item.size = Int64(size) ?? -1
        }
        item.fileHash = json["md5Checksum"] as? String
        
        let dateFormatter = ISO3601DateFormatter()
        if let createdTime = json["createdTime"] as? String {
            item.creationDate = dateFormatter.date(from: createdTime)
        }
        if let modifiedTime = json["modifiedTime"] as? String {
            item.modificationDate = dateFormatter.date(from: modifiedTime)
        }
        return item
    }

    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        // https://developers.google.com/drive/api/v3/handle-errors
        guard let json = response.json as? [String: Any] else { return false }
        if let error = json["error"] as? [String: Any], !error.isEmpty {
            let code = (json["code"] as? Int) ?? 400
            var msg = json["message"] as? String
            if msg == nil, let innerError = (error["errors"] as? [Any])?.first as? [String: Any] {
                msg = innerError["message"] as? String
            }
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(code, msg))))
            return true
        }
        return false
    }
}

public extension GoogleDriveServiceProvider {
    
    /// https://developers.google.com/drive/api/v3/mime-types?hl=en
    struct MIMETypes {
        public static let audio = "application/vnd.google-apps.audio"
        public static let document = "application/vnd.google-apps.document" // Google Docs
        public static let sdk = "application/vnd.google-apps.drive-sdk"    //3rd party shortcut
        public static let drawing = "application/vnd.google-apps.drawing"    //Google Drawing
        public static let file = "application/vnd.google-apps.file"    //Google Drive file
        public static let folder = "application/vnd.google-apps.folder"    //Google Drive folder
        public static let form = "application/vnd.google-apps.form"    //Google Forms
        public static let fusiontable = "application/vnd.google-apps.fusiontable"    //Google Fusion Tables
        public static let map = "application/vnd.google-apps.map"    //Google My Maps
        public static let photo = "application/vnd.google-apps.photo"
        public static let presentation = "application/vnd.google-apps.presentation"    //Google Slides
        public static let script = "application/vnd.google-apps.script"    //Google Apps Scripts
        public static let shortcut = "application/vnd.google-apps.shortcut"    //Shortcut
        public static let site = "application/vnd.google-apps.site"    //Google Sites
        public static let spreadsheet = "application/vnd.google-apps.spreadsheet" //Google Sheets
        public static let unknown = "application/vnd.google-apps.unknown"
        public static let video = "application/vnd.google-apps.video"
    }
    
}

fileprivate extension Data {
    
    mutating func append(_ content: String) {
        self.append(content.data(using: .utf8) ?? Data())
    }
    
}

extension GoogleDriveServiceProvider {
    
    struct UploadSession {
        
        let fileURL: URL
        
        let size: Int64
        
        let uploadUrl: String
        
    }
    
}

extension GoogleDriveServiceProvider {
    
    public struct SharedDrive {
        public let id: String
        public let name: String
        
        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }
    
}
