//
//  Cloud115ServiceProvider.swift
//  Pods
//
//  Created by alexis on 2022/4/29.
//

import Foundation

public class Cloud115ServiceProvider: CloudServiceProvider {
    
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    public var delegate: CloudServiceProviderDelegate?
    
    public var name: String { return "115" }
    
    public var credential: URLCredential?
    
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    private var hasRefreshedCookie = false
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        
    }
    
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        
        func fetchList() {
            let url = "https://aps.115.com/natsort/files.php"
            var params = [String: Any]()
            params["aid"] = 1
            params["cid"] = directory.id
            params["o"] = "file_name"
            params["asc"] = 1
            params["offset"] = 0
            params["show_dir"] = 1
            params["limit"] = 1000
            params["code"] = ""
            params["scid"] = ""
            params["snap"] = 0
            params["natsort"] = 1
            params["record_open_time"] = 1
            params["source"] = ""
            params["format"] = "json"
            params["type"] = ""
            params["star"] = ""
            params["is_share"] = ""
            params["suffix"] = ""
            params["custom_order"] = ""
            params["fc_mix"] = 0
            params["is_q"] = ""
            
            get(url: url, params: params, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    print("Response headers:\(result.headers)")
                    if let object = result.json as? [String: Any], let data = object["data"] as? [[String: Any]] {
                        let files = data.compactMap { Cloud115ServiceProvider.cloudItemFromJSON($0) }
                        completion(.success(files))
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                    print(result)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        func getFiles() {
            let url = "https://webapi.115.com/files"
            var params = [String: Any]()
            params["aid"] = 1
            params["cid"] = directory.id
            params["o"] = "user_ptime"
            params["asc"] = 0
            params["offset"] = 0
            params["show_dir"] = 1
            params["limit"] = 1000
            params["code"] = ""
            params["scid"] = ""
            params["snap"] = 0
            params["natsort"] = 1
            params["record_open_time"] = 1
            params["source"] = ""
            params["format"] = "json"
            
            get(url: url, params: params, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    print("Response headers:\(result.headers)")
                    if let object = result.json as? [String: Any] {
                        
                        if let errNo = object["errNo"] as? Int, errNo == 20130827 {
                            fetchList()
                        } else if let data = object["data"] as? [[String: Any]] {
                            let files = data.compactMap { Cloud115ServiceProvider.cloudItemFromJSON($0) }
                            completion(.success(files))
                        } else {
                            completion(.failure(CloudServiceError.responseDecodeError(result)))
                        }
                    } else {
                        completion(.failure(CloudServiceError.responseDecodeError(result)))
                    }
                    print(result)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        getFiles()
    }
    
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = "https://webapi.115.com/files/add"
        var json = [String: Any]()
        json["pid"] = directory.id
        json["cname"] = folderName
        post(url: url, json: json, headers: headers, completion: completion)
    }
    
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        
    }
    
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        
    }
    
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = "https://webapi.115.com/files/move"
        var data = [String: Any]()
        if let pid = directory.json["cid"] as? String {
            data["pid"] = pid
        }
        data["fid[0]"] = item.id
        data["move_proid"] = Int64(Date().timeIntervalSince1970)
        post(url: url, data: data, headers: headers, completion: completion)
    }
    
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = "https://webapi.115.com/rb/delete"
        
        var data = [String: Any]()
        if let pid = item.json["cid"] as? String {
            data["pid"] = pid
        }
        data["fid[0]"] = item.id
        data["ignore_warn"] = true
        post(url: url, data: data, headers: headers, completion: completion)
    }
    
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = "https://webapi.115.com/files/batch_rename"
        let data = ["files_new_name[\(item.id)]": newName]
        post(url: url, data: data, headers: headers, completion: completion)
    }
    
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = "https://webapi.115.com/files/search"
        var params = [String: Any]()
        params["offset"] = 0
        params["limit"] = 50
        params["search_value"] = keyword
        params["source"] = ""
        params["format"] = "json"
        
        get(url: url, params: params, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let data = object["data"] as? [[String: Any]] {
                    let files = data.compactMap { Cloud115ServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(files))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
                print(result)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
    }
    
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
    }
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        
        guard let cid = json["cid"] as? String, let name = json["n"] as? String else {
            return nil
        }
        let fid = json["fid"] as? String
        let isFolder = fid == nil
        let item = CloudItem(id: fid ?? cid, name: name, path: name, isDirectory: isFolder, json: json)
        item.size = (json["s"] as? Int64) ?? -1
        if let time = json["te"] as? String, let timestamp = TimeInterval(time) {
            item.creationDate = Date(timeIntervalSince1970: timestamp)
            item.modificationDate = Date(timeIntervalSince1970: timestamp)
        }
        return item
    }
    
}

extension Cloud115ServiceProvider {
    
    public var headers: [String: String] {
        return [
            "Cookie":  credential?.password ?? "",
            "Accept":  "application/json, text/plain, */*",
            "Origin": "https://115.com",
            "User-Agent": "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.75 Safari/537.36 115Browser/7.2.5",
            "Referer": "https://115.com/"
        ]
    }
}

public class Cloud115Connector {
    
    public let cookie: String
    
    public init(cookie: String) {
        self.cookie = cookie
    }
    
    public func login(completion: @escaping (Result<Cloud115ServiceProvider, Error>) -> Void) {
        let provider = Cloud115ServiceProvider(credential: URLCredential(user: "", password: cookie, persistence: .forSession))
        completion(.success(provider))
    }
} 
