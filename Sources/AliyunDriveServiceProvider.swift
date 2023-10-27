//
//  AliyunDriveServiceProvider.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2023/10/24.
//

import Foundation
import CryptoKit

/// https://www.yuque.com/aliyundrive/zpfszx
public class AliyunDriveServiceProvider: CloudServiceProvider {
    
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    public var delegate: CloudServiceProviderDelegate?
    
    public var name: String { "AliyunDrive" }
    
    public var credential: URLCredential?
    
    public var rootItem: CloudItem { CloudItem(id: "root", name: name, path: "/") }
    
    public var driveId: String = ""
    
    /// Upload chunsize which is 10M.
    public let chunkSize: Int64 = 10 * 1024 * 1024
    
    public var apiURL = URL(string: "https://openapi.alipan.com")!
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/get")
        var json = [String: Any]()
        json["drive_id"] = driveId
        json["file_id"] = item.id
        post(url: url, json: json) { response in
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
        
        func loadList(marker: String?) {
            var json: [String: Any] = [:]
            json["all"] = false
            json["drive_id"] = driveId
            json["fields"] = "*"
            json["limit"] = 100
            json["order_by"] = "updated_at"
            json["order_direction"] = "DESC"
            json["parent_file_id"] = directory.id
            if let marker = marker {
                json["marker"] = marker
            }
            let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/list")
            post(url: url, json: json) { response in
                switch response.result {
                case .success(let result):
                    if let object = result.json as? [String: Any],
                       let list = object["items"] as? [[String: Any]] {
                        let files = list.compactMap { Self.cloudItemFromJSON($0) }
                        files.forEach { $0.fixPath(with: directory) }
                        items.append(contentsOf: files)
                        
                        if let nextMarker = object["next_marker"] as? String, !nextMarker.isEmpty {
                            loadList(marker: nextMarker)
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
        
        loadList(marker: nil)
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
        let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/create")
        var json: [String: Any] = [:]
        json["drive_id"] = driveId
        json["parent_file_id"] = directory.id
        json["name"] = folderName
        json["type"] = "folder"
        json["check_name_mode"] = "refuse"
        post(url: url, json: json, completion: completion)
    }
    
    /// Get the space usage information for the current user's account.
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/adrive/v1.0/user/getSpaceInfo")
        post(url: url) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let info = json["personal_space_info"] as? [String: Any],
                   let totalSize = info["total_size"] as? Int64,
                   let usedSize = info["used_size"] as? Int64 {
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
        let url = "https://api.aliyundrive.com/v2/user/get"
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
    
    /// Move file to directory.
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/move")
        var json = [String: Any]()
        json["drive_id"] = driveId
        json["file_id"] = item.id
        json["to_parent_file_id"] = directory.id
        post(url: url, json: json, completion: completion)
    }
    
    /// Remove file/folder.
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/delete")
        var json = [String: Any]()
        json["drive_id"] = driveId
        json["file_id"] = item.id
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
        json["drive_id"] = driveId
        json["file_id"] = item.id
        json["name"] = newName
        post(url: url, json: json, completion: completion)
    }
    
    /// Search files by keyword.
    /// - Parameters:
    ///   - keyword: The keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("/adrive/v1.0/openFile/search")
        var json: [String: Any] = [:]
        json["drive_id"] = driveId
        json["limit"] = 100
        json["order_by"] = "updated_at DESC"
        json["query"] = "name match \"\(keyword)\""
        
        post(url: url, json: json) { response in
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
    
    /// Upload file data to target directory.
    /// - Parameters:
    ///   - data: The data to be uploaded.
    ///   - filename: The filename to be created.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/\(filename)"))
        do {
            try data.write(to: tempURL)
            uploadFile(tempURL, to: directory, progressHandler: progressHandler) { response in
                try? FileManager.default.removeItem(at: tempURL)
                completion(response)
            }
        } catch {
            completion(CloudResponse(response: nil, result: .failure(error)))
        }
    }
    
    /// Upload file to target directory with local file url.
    /// Note: remote file url is not supported.
    /// - Parameters:
    ///   - fileURL: The local file url.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard let size = fileSize(of: fileURL) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        precreate(fileURL: fileURL, size: size, directory: directory, progressHandler: progressHandler, completion: completion)
    }
}

extension AliyunDriveServiceProvider {
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let id = json["file_id"] as? String, let name = json["name"] as? String else {
            return nil
        }
        let isFolder = (json["type"] as? String) == "folder"
        let item = CloudItem(id: id, name: name, path: name, isDirectory: isFolder, json: json)
        
        if let createdAt = json["created_at"] as? String {
            item.creationDate = ISO3601DateFormatter.shared.date(from: createdAt)
        }
        if let updatedAt = json["updated_at"] as? String {
            item.modificationDate = ISO3601DateFormatter.shared.date(from: updatedAt)
        }
        item.size = (json["size"] as? Int64) ?? -1
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        guard let json = response.json as? [String: Any] else { return false }
        if response.statusCode == 409 { return false }
        if let _ = json["code"] as? String, let msg = json["message"] as? String {
            completion(CloudResponse(response: response, result: .failure(CloudServiceError.serviceError(-1, msg))))
            return true
        }
        return false
    }
}

extension AliyunDriveServiceProvider {
    
    private func checkPrehash(fileURL: URL, size: Int64, directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        let partNumber = size % chunkSize == 0 ? (size / chunkSize) : ((size / chunkSize) + 1)
        let partList = (1...partNumber).map { ["part_number": $0] }
        
        let url = "https://api.aliyundrive.com/adrive/v2/file/createWithFolders"
        var json: [String: Any] = [:]
        json["drive_id"] = driveId
        json["name"] = fileURL.lastPathComponent
        json["size"] = size
        json["check_name_mode"] = "auto_rename"
        json["parent_file_id"] = directory.id
        json["type"] = "file"
        json["part_info_list"] = partList
        
        if let hash = calculatePreHash(fileURL: fileURL) {
            json["pre_hash"] = hash
        }
        post(url: url, json: json) { [weak self] response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any] {
                    if let code = json["code"] as? String, code == "PreHashMatched" {
                        self?.precreate(fileURL: fileURL, size: size, directory: directory, progressHandler: progressHandler, completion: completion)
                    } else {
                        self?.performUpload(result: result, fileURL: fileURL, size: size, directory: directory, progressHandler: progressHandler, completion: completion)
                    }
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
    
    private func precreate(fileURL: URL, size: Int64, directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        let partNumber = size % chunkSize == 0 ? (size / chunkSize) : ((size / chunkSize) + 1)
        let partList = (1...partNumber).map { ["part_number": $0] }
        
        var json: [String: Any] = [:]
        json["drive_id"] = driveId
        json["name"] = fileURL.lastPathComponent
        json["size"] = size
        json["check_name_mode"] = "auto_rename"
        json["parent_file_id"] = directory.id
        json["type"] = "file"
        if let hash = calculateContentHash(fileURL: fileURL),
            let proofCode = calculateProofcode(fileURL: fileURL, size: size) {
            json["content_hash"] = hash
            json["content_hash_name"] = "sha1"
            json["proof_version"] = "v1"
            json["proof_code"] = proofCode
        }
        json["part_info_list"] = partList
        
        let url = apiURL.absoluteString.appending("/adrive/v1.0/openFile/create")
        post(url: url, json: json) { [weak self] response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any] {
                    if let rapidUpload = json["rapid_upload"] as? Bool, rapidUpload == true {
                        completion(.init(response: result, result: .success(result)))
                    } else {
                        self?.performUpload(result: result, fileURL: fileURL, size: size, directory: directory, progressHandler: progressHandler, completion: completion)
                    }
                } else {
                    completion(.init(response: result, result: .failure(CloudServiceError.responseDecodeError(result))))
                }
                print(result)
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
    
    private func calculatePreHash(fileURL: URL) -> String? {
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            let data = fileHandle.readData(ofLength: 1024)
            try fileHandle.close()
            return Insecure.SHA1.hash(data: data).toHexString()
        } catch {
            print(error)
        }
        return nil
    }
    
    private func calculateContentHash(fileURL: URL) -> String? {
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
            try fileHandle.close()
            return sha1.finalize().toHexString().uppercased()
        } catch {
            print(error)
        }
        return nil
    }
    
    private func calculateProofcode(fileURL: URL, size: Int64) -> String? {
        do {
            let accessTokenData = (credential?.password ?? "").data(using: .utf8) ?? Data()
            let accessTokenMD5 = Insecure.MD5.hash(data: accessTokenData).toHexString()
            
            let startIndex = accessTokenMD5.startIndex
            let endIndex = accessTokenMD5.index(startIndex, offsetBy: 16)
            let sub = accessTokenMD5[startIndex..<endIndex]
            let start = Int64((UInt64(sub, radix: 16) ?? 0) % UInt64(size))
            let end = min(Int64(start + 8), size)
            
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            try fileHandle.seek(toOffset: UInt64(start))
            let subdata = fileHandle.readData(ofLength: Int(end - start))
            try fileHandle.close()
            return subdata.base64EncodedString()
        } catch {
            print(error)
        }
        return nil
    }
 
    private func performUpload(result: HTTPResult, fileURL: URL, size: Int64, directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        do {
            let content = result.content ?? Data()
            let session = try JSONDecoder().decode(UploadSession.self, from: content)
            if let part = session.partInfoList?.first {
                chunkUpload(session: session, part: part, fileURL: fileURL, size: size, progressHandler: progressHandler, completion: completion)
            }
        } catch {
            completion(.init(response: result, result: .failure(error)))
        }
    }

    private func chunkUpload(session: UploadSession, part: PartInfo, fileURL: URL, size: Int64, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        do {
            let offset: Int64 = Int64(part.partNumber - 1) * chunkSize
            let length = min(chunkSize, size - offset)
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            let data = fileHandle.readData(ofLength: Int(length))
            try fileHandle.close()
                        
            let headers = ["Content-Type": ""]
            
            let progressReport = Progress(totalUnitCount: size)
            put(url: part.uploadUrl, headers: headers, requestBody: data, progressHandler: { progress in
                progressReport.completedUnitCount = offset + Int64(Float(length) * progress.percent)
                progressHandler(progressReport)
            }, completion: { response in
                switch response.result {
                case .success(_):
                    guard let partList = session.partInfoList else {
                        return
                    }
                    let index = partList.firstIndex(where: { $0.partNumber == part.partNumber }) ?? 0
                    if index == partList.count - 1 {
                        self.complete(session, completion: completion)
                    } else if index < partList.count - 1 {
                        self.chunkUpload(session: session, part: partList[index + 1], fileURL: fileURL, size: size, progressHandler: progressHandler, completion: completion)
                    }
                case .failure(let error):
                    completion(.init(response: response.response, result: .failure(error)))
                }
            })
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
    private func complete(_ session: UploadSession, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.absoluteString.appending("/adrive/v1.0/openFile/complete")
        var json: [String: Any] = [:]
        json["drive_id"] = driveId
        json["file_id"] = session.fileId
        json["upload_id"] = session.uploadId
        post(url: url, json: json, completion: completion)
    }
}

// MARK: - Models
extension AliyunDriveServiceProvider {
    
    struct UploadSession: Codable {
        enum CodingKeys: String, CodingKey {
            case driveId = "drive_id"
            case fileId = "file_id"
            case filename = "file_name"
            case parentFileId = "parent_file_id"
            case partInfoList = "part_info_list"
            case rapidUpload = "rapid_upload"
            case uploadId = "upload_id"
        }
    
        let driveId: String
        let fileId: String
        let filename: String
        let parentFileId: String
        let partInfoList: [PartInfo]?
        let rapidUpload: Bool
        let uploadId: String
    }
    
    struct PartInfo: Codable {
        enum CodingKeys: String, CodingKey {
            case contentType = "content_type"
            case internalUploadUrl = "internal_upload_url"
            case partNumber = "part_number"
            case uploadUrl = "upload_url"
        }
        let contentType: String?
        let internalUploadUrl: String?
        let partNumber: Int
        let uploadUrl: String
    }
    
    public struct VideoPreviewPlayInfo: Codable {
        
        public struct PreviewInfo: Codable {
            enum CodingKeys: String, CodingKey {
                case category
                case transcodingList = "live_transcoding_task_list"
                case subtitleList = "live_transcoding_subtitle_task_list"
            }
            
            public let category: String
            public let transcodingList: [VideoTranscoding]
            public var subtitleList: [SubtitleTranscoding]?
        }
        
        public struct VideoTranscoding: Codable {
            enum CodingKeys: String, CodingKey {
                case templateId = "template_id"
                case status
                case url
            }
            public let templateId: String
            public let status: String
            public var url: String?
        }
        
        public struct SubtitleTranscoding: Codable {
            public var language: String?
            public var status: String?
            public var url: String?
        }
        
        enum CodingKeys: String, CodingKey {
            case driveId = "drive_id"
            case fileId = "file_id"
            case videoPreviewPlayInfo = "video_preview_play_info"
        }
        
        public let driveId: String
        public let fileId: String
        public let videoPreviewPlayInfo: PreviewInfo
    }
}
