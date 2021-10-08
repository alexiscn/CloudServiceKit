//
//  Cloud189ServiceProvider.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2021/9/30.
//

import Foundation
import CryptoKit

public class Cloud189ServiceProvider: CloudServiceProvider {
    
    /// Cloud Type, current only support personal
    public enum CloudType: Int {
        case family = 1
        case personal = 2
    }
    
    public var name: String { return "189" }
    
    public var credential: URLCredential?
    
    public var rootItem: CloudItem { return CloudItem(id: "", name: name, path: "") }
    
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    public var apiURL = URL(string: "https://api.cloud.189.cn/app/open/api")!
    
    public let cloudType: CloudType = .personal
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        let method = item.isDirectory ? "folder.info": "file.info"
        let headers = requestHeaders(method: method)
        var json: [String: Any] = [:]
        if item.isDirectory {
            json["folderId"] = item.id
        } else {
            json["fileId"] = item.id
        }
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers) { response in
            
        }
    }
    
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let headers = requestHeaders(method: "file.list")
        var json: [String: Any] = [:]
        json["folderId"] = directory.id
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let jsonObject = result.json as? [String: Any],
                   let listFiles = jsonObject["listFiles"] as? [String: Any],
                   let fileList = listFiles["fileList"] as? [Any] {
                    var items: [CloudItem] = []
                    for file in fileList {
                        if let fileObject = file as? [String: Any] {
                            if let folders = fileObject["folder"] as? [[String: Any]] {
                                items.append(contentsOf: folders.compactMap { Cloud189ServiceProvider.cloudItemFromJSON($0) })
                            }
                            if let files = fileObject["file"] as? [[String: Any]] {
                                items.append(contentsOf: files.compactMap { Cloud189ServiceProvider.cloudItemFromJSON($0) })
                            }
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
    
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        if item.isDirectory {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let headers = requestHeaders(method: "file.copy")
        var json: [String: Any] = [:]
        json["fileId"] = item.id
        json["destParentId"] = directory.id
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers, completion: completion)
    }
    
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let headers = requestHeaders(method: "folder.create")
        var json: [String: Any] = [:]
        json["parentFolderId"] = directory.id
        json["relativePath"] = directory.path
        json["folderName"] = folderName
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers, completion: completion)
    }
    
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        let headers = requestHeaders(method: "user.info")
        let json = ["cloudType": cloudType.rawValue]
        post(url: apiURL, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let jsonObject = result.json as? [String: Any],
                   let user = jsonObject["user"] as? [String: Any],
                   let capacity = user["capacity"] as? Int64,
                   let available = user["available"] as? Int64 {
                    let info = CloudSpaceInformation(totalSpace: capacity, availableSpace: available, json: user)
                    completion(.success(info))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let headers = requestHeaders(method: "user.ext.info")
        let json = ["cloudType": cloudType.rawValue]
        post(url: apiURL, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let jsonObject = result.json as? [String: Any],
                   let userExt = jsonObject["userExt"] as? [String: Any],
                   let nickname = userExt["nickname"] as? String {
                    let user = CloudUser(username: nickname, json: userExt)
                    completion(.success(user))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let method = item.isDirectory ? "folder.move": "file.move"
        let headers = requestHeaders(method: method)
        var json: [String: Any] = [:]
        if item.isDirectory {
            json["folderId"] = item.id
            json["destParentFolderId"] = directory.id
        } else {
            json["fileId"] = item.id
            json["destParentId"] = directory.id
        }
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers, completion: completion)
    }
    
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let method = item.isDirectory ? "folder.delete": "file.delete"
        let headers = requestHeaders(method: method)
        var json: [String: Any] = [:]
        if item.isDirectory {
            json["folderId"] = item.id
        } else {
            json["fileId"] = item.id
        }
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers, completion: completion)
    }
    
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let method = item.isDirectory ? "folder.rename": "file.rename"
        let headers = requestHeaders(method: method)
        var json: [String: Any] = [:]
        if item.isDirectory {
            json["folderId"] = item.id
            json["destFolderName"] = newName
        } else {
            json["fileId"] = item.id
            json["destFileName"] = newName
        }
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers, completion: completion)
    }
    
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        completion(.failure(CloudServiceError.unsupported))
    }
    
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/\(filename)"))
        do {
            try data.write(to: tempURL)
            uploadFile(tempURL, to: directory, progressHandler: progressHandler) { response in
                completion(response)
                try? FileManager.default.removeItem(at: tempURL)
            }
        } catch {
            completion(CloudResponse(response: nil, result: .failure(error)))
        }
    }
    
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        createUploadSession(fileURL: fileURL, to: directory, progressHandler: progressHandler, completion: completion)
    }
    
    public func getDownloadUrl(of item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        if item.isDirectory {
            completion(.failure(CloudServiceError.unsupported))
            return
        }
        let headers = requestHeaders(method: "file.download.url")
        var json: [String: Any] = [:]
        json["fileId"] = item.id
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let jsonObject = result.json as? [String: Any],
                   let downloadUrl = jsonObject["fileDownloadUrl"] as? String,
                   let url = URL(string: downloadUrl) {
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

// MARK: - Private work
extension Cloud189ServiceProvider {
    
    public func requestHeaders(method: String) -> [String: String] {
        let accessToken = credential?.password ?? ""
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = dateFormatter.string(from: Date())
        
        let key = String(format: "AccessToken=%@&DateTime=%@&Method=%@", accessToken, date, method)
        let sign = Insecure.MD5.hash(data: key.data(using: .utf8)!).toHexString()
        
        var dict: [String: String] = [:]
        dict["AccessToken"] = accessToken
        dict["Method"] = method
        dict["Signature"] = sign
        dict["Date"] = date
        return dict
    }
}

// MARK: - Resume Upload
extension Cloud189ServiceProvider {
    
    struct UploadSession: Codable {
        
        let uploadFile: UploadFile
        
        let uploadHeader: UploadHeader
     
        struct UploadFile: Codable {
            let uploadFileId: Int64
            let fileUploadUrl: String
            let fileDataExists: Int?
            let dataSize: Int64?
        }
        
        struct UploadHeader: Codable {
            let accessToken: String
            let signature: String
            let date: String
            let familyId: Int64?
        }
    }
    
    private func createUploadSession(fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard let size = fileSize(of: fileURL) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        
        var md5String: String = ""
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            let bufferSize = 5 * 1024 * 1024
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
            md5String = md5.finalize().toHexString()
        } catch {
            print(error)
            completion(.init(response: nil, result: .failure(error)))
            return
        }
        
        let headers = requestHeaders(method: "file.resume.create")
        
        var json: [String: Any] = [:]
        json["parentId"] = directory.id
        json["filename"] = fileURL.lastPathComponent
        json["size"] = size
        json["md5"] = md5String
        json["cloudType"] = cloudType.rawValue
        
        post(url: apiURL, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                do {
                    let data = result.content ?? Data()
                    let session = try JSONDecoder().decode(UploadSession.self, from: data)
                    self.upload(fileURL: fileURL, totalSize: size, session: session, offset: 0, progressHandler: progressHandler, completion: completion)
                } catch {
                    completion(.init(response: result, result: .failure(error)))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
    
    private func upload(fileURL: URL, totalSize: Int64, session: UploadSession, offset: Int64, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
        do {
            let chunkSize: Int64 = 4 * 1024 * 1024 // 4M
            let length = min(chunkSize, totalSize - offset)
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            try fileHandle.seek(toOffset: UInt64(offset))
            let data = fileHandle.readData(ofLength: Int(length))
            try fileHandle.close()
            
            var headers: [String: String] = [:]
            headers["ResumePolicy"] =  "1"
            headers["Edrive-UploadFileId"] = String(session.uploadFile.uploadFileId)
            headers["Offset"] = String(offset)
            headers["AccessToken"] = session.uploadHeader.accessToken
            headers["Signature"] = session.uploadHeader.signature
            headers["Date"] = session.uploadHeader.date
            
            put(url: session.uploadFile.fileUploadUrl, headers: headers, requestBody: data) { progress in
                
            } completion: { [weak self] response in
                switch response.result {
                case .success(_):
                    self?.checkUploadSessionStatus(session, fileURL: fileURL, totalSize: totalSize, progressHandler: progressHandler, completion: completion)
                case .failure(let error):
                    completion(.init(response: response.response, result: .failure(error)))
                }
            }
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
    private func checkUploadSessionStatus(_ session: UploadSession, fileURL: URL, totalSize: Int64, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        let headers = requestHeaders(method: "file.resume.info")
        var json: [String: Any] = [:]
        json["uploadFileId"] = session.uploadFile.uploadFileId
        json["cloudType"] = cloudType.rawValue
        post(url: session.uploadFile.fileUploadUrl, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                do {
                    let data = result.content ?? Data()
                    let session = try JSONDecoder().decode(UploadSession.self, from: data)
                    let uploadedSize = session.uploadFile.dataSize ?? 0
                    if uploadedSize == totalSize {
                        self.commitUploadSession(session, completion: completion)
                    } else {
                        self.upload(fileURL: fileURL, totalSize: totalSize, session: session, offset: uploadedSize, progressHandler: progressHandler, completion: completion)
                    }
                } catch {
                    completion(.init(response: result, result: .failure(error)))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
    
    private func commitUploadSession(_ session: UploadSession, completion: @escaping CloudCompletionHandler) {
        let headers = requestHeaders(method: "file.resume.commit")
        var json: [String: Any] = [:]
        json["uploadFileId"] = session.uploadFile.uploadFileId
        json["cloudType"] = cloudType.rawValue
        post(url: apiURL, json: json, headers: headers, completion: completion)
    }
}

extension Cloud189ServiceProvider {
    
    static let dateFormatter = ISO8601DateFormatter()
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let id = json["id"] as? Int64, let name = json["name"] as? String else {
            return nil
        }
        let size = (json["size"] as? Int64) ?? -1
        let isDirectory = size == -1
        let path = (json["path"] as? String) ?? name
        let item = CloudItem(id: String(id), name: name, path: path, isDirectory: isDirectory, json: json)
        item.size = size
        
        if let createDate = json["createDate"] as? String, !createDate.isEmpty {
            item.creationDate = dateFormatter.date(from: createDate)
        }
        if let lastOpTime = json["lastOpTime"] as? String, !lastOpTime.isEmpty {
            item.modificationDate = dateFormatter.date(from: lastOpTime)
        }
        return item
    }
}
