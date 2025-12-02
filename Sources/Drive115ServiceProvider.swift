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
    
    private let ossClient = AliyunOSSClient()
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        completion(.success(item))
    }
    
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        
        var items: [CloudItem] = []
        
        var index = 0
        
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
                        
                        let count = object["count"] as? Int ?? 0
                        index += list.count
                        
                        if index < count {
                            loadList(offset: index)
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
            let sha1Hash = sha1.finalize().toHexString().uppercased()
            let filename = fileURL.lastPathComponent
            
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes[.size] as? Int64) ?? 0
            self.initUpload(fileURL: fileURL, filename: filename, fileSize: fileSize, fileid: sha1Hash, directory: directory, signCalculator: { check in
                let components = check.components(separatedBy: "-")
                if components.count == 2, let lower = Int(components[0]), let upper = Int(components[1]), lower >= 0, upper < fileSize {
                    do {
                        let handle = try FileHandle(forReadingFrom: fileURL)
                        var hash = Insecure.SHA1()
                        try handle.seek(toOffset: UInt64(lower))
                        let data = handle.readData(ofLength: upper - lower + 1)
                        hash.update(data: data)
                        let value = hash.finalize().toHexString().uppercased()
                        return value
                    } catch {
                        return ""
                    }
                }
                return ""
            }, completion: completion)
            
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
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

struct UploadToken {
    let accessKeyId: String
    let accessKeySecret: String
    let expiration: String
    let securityToken: String
    let endpoint: String
}

// MARK: - Upload file
extension Drive115ServiceProvider {
    
    private func getUploadToken(completion: @escaping (Result<UploadToken, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/open/upload/get_token")
        get(url: url, completion: { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                    let data = json["data"] as? [String: Any],
                    let accessKeyId = data["AccessKeyId"] as? String,
                    let accessKeySecret = data["AccessKeySecret"] as? String,
                    let expiration = data["Expiration"] as? String,
                    let securityToken = data["SecurityToken"] as? String,
                    let endpoint = data["endpoint"] as? String {
                    let token = UploadToken(accessKeyId: accessKeyId, accessKeySecret: accessKeySecret, expiration: expiration, securityToken: securityToken, endpoint: endpoint)
                    completion(.success(token))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    private func initUpload(fileURL: URL, filename: String, fileSize: Int64, fileid: String, directory: CloudItem, signKey: String? = nil, signVal: String? = nil, signCalculator: ((String) -> String)?, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/open/upload/init")
        var formData = [String: Any]()
        formData["file_name"] = filename
        formData["file_size"] = fileSize
        formData["target"] = "U_1_\(directory.id)"
        formData["fileid"] = fileid
        
        if let signKey, !signKey.isEmpty {
            formData["sign_key"] = signKey
        }
        if let signVal, !signVal.isEmpty {
            formData["sign_val"] = signVal
        }
        post(url: url, data: formData) { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let state = json["state"] as? Int, state == 1, let data = json["data"] as? [String: Any] {
                    if let fileId = data["file_id"] as? String, !fileId.isEmpty {
                        completion(.init(response: result, result: .success(result)))
                    } else if let code = data["code"] as? Int, [700, 701, 702].contains(code), let signCheck = data["sign_check"] as? String, !signCheck.isEmpty, let key = data["sign_key"] as? String, !key.isEmpty {
                        let signValue = signCalculator?(signCheck)
                        self.initUpload(fileURL: fileURL, filename: filename, fileSize: fileSize, fileid: fileid, directory: directory, signKey: key, signVal: signValue, signCalculator: nil, completion: completion)
                    } else if let bucket = data["bucket"] as? String, !bucket.isEmpty, let object = data["object"] as? String, !object.isEmpty, let callback = data["callback"] as? [String: String] {
                        self.getUploadToken { [weak self] tokenResult in
                            guard let self else { return }
                            switch tokenResult {
                            case .success(let token):
                                self.uploadFileToOss(fileURL: fileURL, token: token, callback: callback, bucket: bucket, object: object, fileSize: fileSize, fileHash: fileid, completion: completion)
                            case .failure(let error):
                                completion(.init(response: nil, result: .failure(error)))
                            }
                        }
                    }
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                print(error)
                completion(.init(response: nil, result: .failure(error)))
            }
        }
    }
    
    private func uploadFileToOss(fileURL: URL, token: UploadToken, callback: [String: String], bucket: String, object: String, fileSize: Int64, fileHash: String, completion: @escaping CloudCompletionHandler) {
        ossClient.multipartUpload(fileURL: fileURL, endpoint: token.endpoint, bucket: bucket, objectKey: object, token: token, callback: callback, progressHandler: {
            progress in
            print(progress)
        }, completionHandler: { result in
            switch result {
            case .success(let data):
                completion(.init(response: nil, result: .success(HTTPResult(data: data, response: nil, error: nil, task: nil))))
            case .failure(let error):
                completion(.init(response: nil, result: .failure(error)))
            }
        })
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
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        guard let json = response.json as? [String: Any] else { return false }
        if let state = json["state"] as? Bool, state == false {
            let msg = json["message"] as? String ?? "Unknown error"
            completion(.init(response: response, result: .failure(CloudServiceError.serviceError(-1, msg))))
            return true
        }
        return false
    }
    
    public func isUnauthorizedResponse(_ response: HTTPResult) -> Bool {
        guard let json = response.json as? [String: Any] else { return false }
        if let code = json["code"] as? Int, code == 40140125 {
            return true
        }
        return false
    }
}

fileprivate class AliyunOSSClient {
    
    struct UploadPart {
        let partNumber: Int
        let etag: String
    }
    
    enum OSSError: Error, LocalizedError {
        case invalidResponse
        case requestFailed(statusCode: Int, body: String)
        case xmlParsingError
        case fileError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server."
            case .requestFailed(let statusCode, let body):
                return "Request failed with status code \(statusCode): \(body)"
            case .xmlParsingError:
                return "Failed to parse XML response."
            case .fileError(let reason):
                return "File error: \(reason)"
            }
        }
    }
    
    private let chunkSize: Int
    private let session: URLSession
    
    init(session: URLSession = .shared, chunkSize: Int = 5 * 1024 * 1024) {
        self.session = session
        self.chunkSize = chunkSize
    }
    
    func multipartUpload(
        fileURL: URL,
        endpoint: String,
        bucket: String,
        objectKey: String,
        token: UploadToken,
        callback: [String: String],
        progressHandler: @escaping (Progress) -> Void,
        completionHandler: @escaping (Result<Data, Error>) -> Void
    ) {
        Task {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                guard let fileSize = values.fileSize else {
                    throw OSSError.fileError("Could not determine file size.")
                }
                
                let uploadId = try await initiateMultipartUpload(endpoint: endpoint, bucket: bucket, objectKey: objectKey, token: token)
                
                let partCount = (fileSize + chunkSize - 1) / chunkSize
                let progress = Progress(totalUnitCount: Int64(fileSize))
                
                var uploadedParts: [UploadPart] = []
                
                try await withThrowingTaskGroup(of: UploadPart.self) { group in
                    for partNumber in 1...partCount {
                        if Task.isCancelled { break }
                        group.addTask {
                            let offset = (partNumber - 1) * self.chunkSize
                            let size = min(self.chunkSize, fileSize - offset)
                            
                            let fileHandle = try FileHandle(forReadingFrom: fileURL)
                            defer { try? fileHandle.close() }
                            try fileHandle.seek(toOffset: UInt64(offset))
                            // Autoreleasepool to manage memory for large files
                            let data = autoreleasepool {
                                fileHandle.readData(ofLength: size)
                            }
                            
                            let part = try await self.uploadPart(
                                data: data,
                                partNumber: partNumber,
                                uploadId: uploadId,
                                endpoint: endpoint,
                                bucket: bucket,
                                objectKey: objectKey,
                                token: token
                            )
                            
                            progress.completedUnitCount += Int64(size)
                            progressHandler(progress)
                            
                            return part
                        }
                    }
                    
                    for try await part in group {
                        uploadedParts.append(part)
                    }
                }
                
                uploadedParts.sort { $0.partNumber < $1.partNumber }
                
                let responseData = try await completeMultipartUpload(
                    parts: uploadedParts,
                    uploadId: uploadId,
                    endpoint: endpoint,
                    bucket: bucket,
                    objectKey: objectKey,
                    token: token,
                    callback: callback
                )
                
                completionHandler(.success(responseData))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    private func initiateMultipartUpload(endpoint: String, bucket: String, objectKey: String, token: UploadToken) async throws -> String {
        let subresource = "?sequential&uploads"
        let url = try makeURL(endpoint: endpoint, bucketName: bucket, objectKey: objectKey, subresource: subresource)
        
        var headers = makeHeaders(token: token)
        headers["Content-Type"] = "application/xml"
        
        headers["Authorization"] = createAuthorizationHeader(method: "POST", headers: headers, bucket: bucket, objectKey: objectKey, subresource: subresource, token: token)
        
        let (data, _) = try await makeRequest(url: url, method: "POST", headers: headers)
        
        let parser = XMLParser(data: data)
        let delegate = InitiateMultipartUploadParserDelegate()
        parser.delegate = delegate
        
        if parser.parse(), let uploadId = delegate.uploadId {
            return uploadId
        } else {
            throw OSSError.xmlParsingError
        }
    }
    
    private func uploadPart(data: Data, partNumber: Int, uploadId: String, endpoint: String, bucket: String, objectKey: String, token: UploadToken) async throws -> UploadPart {
        let subresource = "?partNumber=\(partNumber)&uploadId=\(uploadId)"
        let url = try makeURL(endpoint: endpoint, bucketName: bucket, objectKey: objectKey, subresource: subresource)
        
        var headers = makeHeaders(token: token)
        headers["Content-Length"] = "\(data.count)"
        headers["Content-Type"] = "application/octet-stream"
        
        headers["Authorization"] = createAuthorizationHeader(method: "PUT", headers: headers, bucket: bucket, objectKey: objectKey, subresource: subresource, token: token)
        
        let (_, httpResponse) = try await makeRequest(url: url, method: "PUT", headers: headers, body: data)
        
        guard let etag = httpResponse.value(forHTTPHeaderField: "ETag") else {
            throw OSSError.invalidResponse
        }
        
        return UploadPart(partNumber: partNumber, etag: etag)
    }
    
    private func completeMultipartUpload(parts: [UploadPart], uploadId: String, endpoint: String, bucket: String, objectKey: String, token: UploadToken, callback: [String: String]) async throws -> Data {
        let subresource = "?uploadId=\(uploadId)"
        let url = try makeURL(endpoint: endpoint, bucketName: bucket, objectKey: objectKey, subresource: subresource)
        
        let partsXML = parts.map { "  <Part><PartNumber>\($0.partNumber)</PartNumber><ETag>\($0.etag)</ETag></Part>" }.joined(separator: "\n")
        let bodyString = "<CompleteMultipartUpload>\n\(partsXML)\n</CompleteMultipartUpload>"
        let bodyData = bodyString.data(using: .utf8)!
        
        var headers = makeHeaders(token: token)
        headers["Content-Type"] = "application/xml"
        headers["Content-Length"] = "\(bodyData.count)"
        
        if let callbackText = callback["callback"], let variable = callback["callback_var"] {
            headers["x-oss-callback"] = callbackText.data(using: .utf8)!.base64EncodedString()
            headers["x-oss-callback-var"] = variable.data(using: .utf8)!.base64EncodedString()
        }
        
        headers["Authorization"] = createAuthorizationHeader(method: "POST", headers: headers, bucket: bucket, objectKey: objectKey, subresource: subresource, token: token)
        
        let (data, _) = try await makeRequest(url: url, method: "POST", headers: headers, body: bodyData)
        return data
    }
    
    private func makeURL(endpoint: String, bucketName: String, objectKey: String, subresource: String) throws -> URL {
        guard let endpointURL = URL(string: endpoint),
              let scheme = endpointURL.scheme,
              let host = endpointURL.host else {
            throw URLError(.badURL)
        }
        let urlString = "\(scheme)://\(bucketName).\(host)/\(objectKey)\(subresource)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        return url
    }
    
    private func makeRequest(url: URL, method: String, headers: [String: String], body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OSSError.invalidResponse
        }
        
        if !(200..<300).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            throw OSSError.requestFailed(statusCode: httpResponse.statusCode, body: errorBody)
        }
        return (data, httpResponse)
    }
    
    private func createAuthorizationHeader(method: String, headers: [String: String], bucket: String, objectKey: String, subresource: String?, token: UploadToken) -> String {
        let contentType = headers["Content-Type"] ?? ""
        let date = headers["Date"] ?? ""
        
        let canonicalizedOSSHeaders = headers
            .filter { $0.key.lowercased().hasPrefix("x-oss-") }
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { "\($0.key.lowercased()):\($0.value)" }
            .joined(separator: "\n")
        
        let canonicalizedResource = "/\(bucket)/\(objectKey)" + (subresource ?? "")
        
        var stringToSign = "\(method)\n\n\(contentType)\n\(date)\n"
        if !canonicalizedOSSHeaders.isEmpty {
            stringToSign += "\(canonicalizedOSSHeaders)\n"
        }
        stringToSign += canonicalizedResource
        
        let key = SymmetricKey(data: token.accessKeySecret.data(using: .utf8)!)
        let signatureData = HMAC<Insecure.SHA1>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)
        let signature = Data(signatureData).base64EncodedString()
        
        return "OSS \(token.accessKeyId):\(signature)"
    }
    
    private func makeHeaders(token: UploadToken) -> [String: String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: Date())
        
        return [
            "Date": dateString,
            "x-oss-security-token": token.securityToken
        ]
    }
    
    private class InitiateMultipartUploadParserDelegate: NSObject, XMLParserDelegate {
        var uploadId: String?
        private var currentElement: String?
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if currentElement == "UploadId" {
                uploadId = (uploadId ?? "") + string.replacingOccurrences(of: "\n", with: "")
            }
        }
    }
}
