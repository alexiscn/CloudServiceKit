//
//  BaiduPanServiceProvider.swift
//  
//
//  Created by alexiscn on 2021/8/9.
//

import Foundation
import CryptoKit

/*
 A wrapper for [https://pan.baidu.com](http://pan.baidu.com) .
 Developer documents can be found https://pan.baidu.com/union/document/entrance
 */
public class BaiduPanServiceProvider: CloudServiceProvider {
    
    /// The name of service provider.
    public var name: String { return "BaiduPan" }
    
    /// The root folder of BaiduPan service. You can use this property to list root items.
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    public var credential: URLCredential?
    
    /// The API URL of BaiduPanService
    public var apiURL = URL(string: "https://pan.baidu.com/rest/2.0")!
    
    /// The refresh access token handler. Used to refresh access token when the token expires.
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    /// The app name you applied at BaiduPan console. Used to upload file.
    /// eg: Test
    /// Note: do not pass /apps and / in appName. It's your app's name only.
    public var appName: String = ""
    
    /// The size of chunk upload. Constant to 4M.
    private let chunkSize: Int64 = 4 * 1024 * 1024
    
    required public init(credential: URLCredential?) {
        self.credential = credential
    }
    
    /// Get information of file/folder.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E6%9F%A5%E8%AF%A2%E6%96%87%E4%BB%B6%E4%BF%A1%E6%81%AF
    /// - Parameters:
    ///   - item: The file item.
    ///   - completion: Completion block.
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        if item.isDirectory {
            completion(.failure(CloudServiceError.unsupported))
            return
        }
        let url = apiURL.appendingPathComponent("xpan/multimedia")
        var params: [String: Any] = [:]
        params["method"] = "filemetas"
        params["fsids"] = [Int64(item.id) ?? -1].json
        params["thumb"] = 1
        params["dlink"] = 1
        params["extra"] = 1
        params["access_token"] = credential?.password ?? ""
        
        post(url: url, params: params) { response in
            
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                          let list = json["list"] as? [Any],
                          let object = list.first as? [String: Any],
                          let item = BaiduPanServiceProvider.cloudItemFromJSON(object) {
                   completion(.success(item))
               } else {
                   completion(.failure(CloudServiceError.responseDecodeError(result)))
               }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// List items in directory.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E8%8E%B7%E5%8F%96%E6%96%87%E4%BB%B6%E5%88%97%E8%A1%A8
    /// - Parameters:
    ///   - directory: The directory to be listed.
    ///   - completion: Completion block.
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "list"
        params["dir"] = directory.path
        params["web"] = "web"
        params["access_token"] = credential?.password ?? ""
        
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let list = json["list"] as? [[String: Any]] {
                    let items = list.compactMap { BaiduPanServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(items))
               } else {
                   completion(.failure(CloudServiceError.responseDecodeError(result)))
               }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Copy file/folder to target folder.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E7%AE%A1%E7%90%86%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - item: The item to be copied.
    ///   - directory: The target folder.
    ///   - completion: Completion block.
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "filemanager"
        params["opera"] = "copy"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["async"] = 1
        data["ondup"] = "fail"
        data["filelist"] = [["path": item.path, "dest": directory.path, "newname": item.name, "ondup": "fail"]].json
        
        post(url: url, params: params, data: data, completion: completion)
    }
    
    /// Create a folder at a given directory.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E5%88%9B%E5%BB%BA%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - folderName: The folder name to be created.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "create"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["path"] = [directory.path, folderName].joined(separator: "/")
        data["size"] = 0
        data["isdir"] = 1
        
        post(url: url, params: params, data: data, completion: completion)
    }
    
    /// Get the space usage information for the current user's account.
    /// Documents can be found here: https://pan.baidu.com/union/document/basic#%E8%8E%B7%E5%8F%96%E7%BD%91%E7%9B%98%E5%AE%B9%E9%87%8F%E4%BF%A1%E6%81%AF
    /// - Parameter completion: Completion block.
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        var params: [String: Any] = [:]
        params["checkfree"] = 0
        params["checkexpire"] = 0
        params["access_token"] = credential?.password ?? ""
        get(url: "https://pan.baidu.com/api/quota") { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let total = json["total"] as? Int64,
                   let free = json["free"] as? Int64 {
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
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E8%8E%B7%E5%8F%96%E7%94%A8%E6%88%B7%E4%BF%A1%E6%81%AF
    /// - Parameter completion: Completion block.
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("xpan/nas")
        var params: [String: Any] = [:]
        params["method"] = "uinfo"
        params["access_token"] = credential?.password ?? ""
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let name = json["baidu_name"] as? String {
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

    /// Get the download link of cloud item. The url will be expired after 8 hours.
    /// Note1: You must append `access_token` to the url query and set the request header `User-Agent` to `pan.baidu.com`.
    /// Note2: There will be 302 redirect.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E4%B8%8B%E8%BD%BD
    /// - Parameters:
    ///   - item: The cloud item to be downloaded.
    ///   - completion: Completion callback.
    public func downloadLink(of item: CloudItem, completion: @escaping (Result<URL, Error>) -> Void) {
        attributesOfItem(item) { result in
            switch result {
            case .success(let cloudItem):
                if let dlink = cloudItem.json["dlink"] as? String {
                    let urlString = dlink.appending("&access_token=\(self.credential?.password ?? "")")
                    if let url = URL(string: urlString) {
                        completion(.success(url))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Move file to directory.
    /// If you want to move files to directory, please use `moveItems(_,to:)`.
    /// If you want to rename file, prefer to use `renameItem(_,newName:)`.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E7%AE%A1%E7%90%86%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "filemanager"
        params["opera"] = "move"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["async"] = 1
        data["ondup"] = "fail"
        data["filelist"] = [["path": item.path, "dest": directory.path, "newname": item.name, "ondup": "fail"]].json
        
        post(url: url, params: params, data: data, completion: completion)
    }
    
    /// Remove file/folder.
    /// If you want to remove files/folders, prefer to use `removeItems(_:)`
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E7%AE%A1%E7%90%86%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "filemanager"
        params["opera"] = "delete"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["async"] = 1
        data["ondup"] = "fail"
        data["filelist"] = [item.path].json
        
        post(url: url, params: params, data: data, completion: completion)
    }
    
    /// Rename file/folder to new name.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E7%AE%A1%E7%90%86%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: completion callback, called in main-tread.
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "filemanager"
        params["opera"] = "rename"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["async"] = 1
        data["ondup"] = "fail"
        data["filelist"] = [["path": item.path, "newname": newName]].json
        
        post(url: url, params: params, data: data, completion: completion)
    }
    
    public func streamingVideo(item: CloudItem, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "streaming"
        params["path"] = item.path
        params["type"] = "M3U8_AUTO_480"
        params["access_token"] = credential?.password ?? ""
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let ltime = json["ltime"] as? Int,
                   let adToken = json["adToken"] as? String {
                    print(ltime)
//                    DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(ltime)) {
                        if let request = self.streamingVideoRequest(item, adToken: adToken) {
                            completion(.success(request))
                        } else {
                            completion(.failure(CloudServiceError.unsupported))
                        }
//                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func streamingVideoRequest(_ item: CloudItem, adToken: String) -> URLRequest? {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "streaming"
        params["path"] = item.path
        params["type"] = "M3U8_AUTO_480"
        params["access_token"] = credential?.password ?? ""
        params["adToken"] = adToken
        let headers = CaseInsensitiveDictionary(dictionary: ["User-Agent": "pan.baidu.com"])
        return Just.adaptor.synthesizeRequest(.get, url: url, params: params, data: [:], json: nil, headers: headers, files: [:], auth: nil, timeout: nil, urlQuery: nil, requestBody: nil)
    }
    
    public func streamingAudioRequest(_ item: CloudItem) -> URLRequest? {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "streaming"
        params["path"] = item.path
        params["type"] = "M3U8_MP3_128"
        params["access_token"] = credential?.password ?? ""
        params["app_id"] = "250528"
        
        let headers = CaseInsensitiveDictionary(dictionary: ["User-Agent": "pan.baidu.com"])
        return Just.adaptor.synthesizeRequest(.get, url: url, params: params, data: [:], json: nil, headers: headers, files: [:], auth: nil, timeout: nil, urlQuery: nil, requestBody: nil)
    }
    
    /// Search files by keyword.
    /// - Parameters:
    ///   - keyword: The query keyword.
    ///   - completion: Completion block.
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "search"
        params["key"] = keyword
        params["access_token"] = credential?.password ?? ""
        get(url: url, params: params) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let list = json["list"] as? [[String: Any]] {
                    let items = list.compactMap { BaiduPanServiceProvider.cloudItemFromJSON($0) }
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
            uploadFile(tempURL, to: directory, progressHandler: progressHandler, completion: completion)
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
        precreateUploadFile(fileURL: fileURL, directory: directory, progressHandler: progressHandler, completion: completion)
    }
}

// MARK: - CloudServiceResponseProcessing
extension BaiduPanServiceProvider: CloudServiceResponseProcessing {
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        
        var name = json["server_filename"] as? String
        if name == nil {
            name = json["filename"] as? String
        }
        
        guard let name = name,
              let path = json["path"] as? String,
              let fsid = json["fs_id"] as? Int64 else {
            return nil
        }
        let isDirectory = (json["isdir"] as? NSNumber) == 1
        let item = CloudItem(id: String(fsid), name: name, path: path, isDirectory: isDirectory, json: json)
        item.size = (json["size"] as? Int64) ?? -1
        item.fileHash = json["md5"] as? String
        if let mtime = json["server_mtime"] as? Int64 {
            item.modificationDate = Date(timeIntervalSince1970: TimeInterval(mtime))
        }
        if let ctime = json["server_ctime"] as? Int64 {
            item.creationDate = Date(timeIntervalSince1970: TimeInterval(ctime))
        }
        return item
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        guard let json = response.json as? [String: Any] else { return false }
        // errno = 133 means play ad when streaming video
        if let errno = json["errno"] as? Int, errno != 0 && errno != 133 {
            let msg = json["errmsg"] as? String
            completion(CloudResponse(response: response, result: .failure(CloudServiceError.serviceError(errno, msg))))
            return true
        }
        return false
    }
}

// MARK: - CloudServiceBatching
extension BaiduPanServiceProvider: CloudServiceBatching {
    
    /// Batch move files/folders.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E7%AE%A1%E7%90%86%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - items: The items to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    public func moveItems(_ items: [CloudItem], to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "filemanager"
        params["opera"] = "move"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["async"] = 1
        data["ondup"] = "fail"
        data["filelist"] = items.map { $0.path }
        
        post(url: url, params: params, data: data, completion: completion)
    }
    
    /// Batch remove files/folders.
    /// Document can be found here: https://pan.baidu.com/union/document/basic#%E7%AE%A1%E7%90%86%E6%96%87%E4%BB%B6
    /// - Parameters:
    ///   - items: The items to be removed.
    ///   - completion: Completion block.
    public func removeItems(_ items: [CloudItem], completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "filemanager"
        params["opera"] = "delete"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["async"] = 1
        data["ondup"] = "fail"
        data["filelist"] = items.map { $0.path }
        post(url: url, params: params, data: data, completion: completion)
    }
}

// MARK: - Chunk Upload
extension BaiduPanServiceProvider {
    
    private func precreateUploadFile(fileURL: URL, directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard let size = fileSize(of: fileURL) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        precondition(!appName.isEmpty, "Please provide your app name for upload usage")
        
        do {
            let numbers = size % chunkSize == 0 ? (size / chunkSize) : (size/chunkSize + 1)
            let handle = try FileHandle(forReadingFrom: fileURL)
            var blockList: [String] = []
            for index in 0 ..< numbers {
                let offset = index * chunkSize
                let length = min(chunkSize, size - offset)
                try handle.seek(toOffset: UInt64(Int(offset)))
                let data = handle.readData(ofLength: Int(length))
                let md5 = Insecure.MD5.hash(data: data).toHexString().lowercased()
                blockList.append(md5)
            }
            try handle.close()
            
            let url = apiURL.appendingPathComponent("xpan/file")
            var params: [String: Any] = [:]
            params["method"] = "precreate"
            params["access_token"] = credential?.password ?? ""
            let path = "/apps/\(appName)/" + fileURL.lastPathComponent
            var data: [String: Any] = [:]
            data["path"] = path
            data["size"] = size
            data["isdir"] = 0
            data["autoinit"] = 1
            data["block_list"] = blockList.json
            
            post(url: url, params: params, data: data) { [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let result):
                    if let json = result.json as? [String: Any],
                       let uploadId = json["uploadid"] as? String {
                        let session = UploadSession(fileURL: fileURL, uploadId: uploadId, size: size, path: path, blockList: blockList, directory: directory)
                        self.chunkUpload(session: session, partseq: 0, progressHandler: progressHandler, completion: completion)
                    } else {
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
    
    private func chunkUpload(session: UploadSession, partseq: Int, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        do {
            let offset = chunkSize * Int64(partseq)
            let length = min(chunkSize, session.size - offset)
            let handle = try FileHandle(forReadingFrom: session.fileURL)
            try handle.seek(toOffset: UInt64(offset))
            let data = handle.readData(ofLength: Int(length))
            try handle.close()
            
            let url = URL(string: "https://d.pcs.baidu.com/rest/2.0/pcs/superfile2")!
            var params: [String: Any] = [:]
            params["method"] = "upload"
            params["type"] = "tmpfile"
            params["path"] = session.path
            params["uploadid"] = session.uploadId
            params["partseq"] = partseq
            params["access_token"] = credential?.password ?? ""
            
            let file = HTTPFile.data("file", data, nil)
            let progressReport = Progress(totalUnitCount: session.size)
            post(url: url, params: params, files: ["file": file]) { progress in
                progressReport.completedUnitCount = offset + Int64(progress.percent * Float(length))
                progressHandler(progressReport)
            } completion: { response in
                switch response.result {
                case .success(_):
                    if length < self.chunkSize {
                        self.createUploadFile(session: session, completion: completion)
                    } else {
                        self.chunkUpload(session: session, partseq: partseq + 1, progressHandler: progressHandler, completion: completion)
                    }
                case .failure(let error):
                    completion(.init(response: response.response, result: .failure(error)))
                }
            }
        } catch {
            completion(.init(response: nil, result: .failure(error)))
        }
    }
    
    private func createUploadFile(session: UploadSession, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponent("xpan/file")
        var params: [String: Any] = [:]
        params["method"] = "create"
        params["access_token"] = credential?.password ?? ""
        
        var data: [String: Any] = [:]
        data["path"] = session.path
        data["size"] = session.size
        data["isdir"] = 0
        data["uploadid"] = session.uploadId
        data["block_list"] = session.blockList.json
        
        post(url: url, params: params, data: data) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any], let path = json["path"] as? String, let id = json["fs_id"] as? Int64 {
                    let item = CloudItem(id: String(id), name: session.fileURL.lastPathComponent, path: path, isDirectory: false, json: json)
                    /* Baidu API do not support upload to user's folder directly.
                     Third party SDK can only upload file to /apps/{app_name}
                     So after we uploaded to /apps/{app_name}/file_name,
                    we manually move item to the final destination */
                    self.moveItem(item, to: session.directory, completion: completion)
                } else {
                    completion(.init(response: result, result: .success(result)))
                }
            case .failure(let error):
                completion(.init(response: response.response, result: .failure(error)))
            }
        }
    }
}

extension BaiduPanServiceProvider {
    
    struct UploadSession {
        
        let fileURL: URL
        
        let uploadId: String
        
        /// The total size of file
        let size: Int64
        
        /// The remote path
        let path: String
        
        let blockList: [String]
        
        let directory: CloudItem
    }
    
}
