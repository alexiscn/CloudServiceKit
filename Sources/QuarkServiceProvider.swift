//
//  QuarkServiceProvider.swift
//  Pods
//
//  Created by alexiscn on 2022/3/26.
//

import Foundation

public class QuarkServiceProvider: CloudServiceProvider {
    
    public var delegate: CloudServiceProviderDelegate?
    
    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?
    
    public var cookieRefreshedHandler: ((String) -> Void)?
    
    public var name: String { return "Quark" }
    
    public var credential: URLCredential?
    
    public var rootItem: CloudItem { return CloudItem(id: "0", name: name, path: "/") }
    
    private var hasRefreshedCookie = false
    
    public required init(credential: URLCredential?) {
        self.credential = credential
    }
    
    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        
    }
    
    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        
        var items: [CloudItem] = []
        var page = 1
        
        func loadList() {
            let url = "https://drive.quark.cn/1/clouddrive/file/sort"
            var params = [String: Any]()
            params["pdir_fid"] = directory.id
            params["_size"] = "100"
            params["_fetch_total"] = "1"
            params["pr"] = "ucpro"
            params["fr"] = "pc"
            params["_page"] = page
            
            get(url: url, params: params, headers: headers) { response in
                switch response.result {
                case .success(let result):
                    if let object = result.json as? [String: Any], let data = object["data"] as? [String: Any], let list = data["list"] as? [[String: Any]] {
                        
                        if !self.hasRefreshedCookie, let cookie = result.headers["Set-Cookie"] {
                            let components = cookie.components(separatedBy: ";")
                            if let puus = components.first(where: { $0.hasPrefix("__puus=") }) {
                                self.updatePuus(puus)
                                self.hasRefreshedCookie = true
                            }
                        }
                        
                        let files = list.compactMap { QuarkServiceProvider.cloudItemFromJSON($0) }
                        items.append(contentsOf: files)
                        
                        if let metadata = object["metadata"] as? [String: Any], let total = metadata["_total"] as? Int {
                            if 100 * page >= total {
                                completion(.success(items))
                            } else {
                                page += 1
                                loadList()
                            }
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
        
        loadList()
    }
    
    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = "https://drive.quark.cn/1/clouddrive/file"
        var json = [String: Any]()
        json["dir_init_lock"] = false
        json["dir_path"] = ""
        json["file_name"] = folderName
        json["pdir_fid"] = directory.id
        
        var params = [String: Any]()
        params["pr"] = "ucpro"
        params["fr"] = "pc"
        post(url: url, params: params, json: json, headers: headers, completion: completion)
    }
    
    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        completion(.failure(CloudServiceError.unsupported))
    }
    
    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        completion(.failure(CloudServiceError.unsupported))
    }
    
    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = "https://drive.quark.cn/1/clouddrive/file/move"
        var json = [String: Any]()
        json["action_type"] = 1
        json["exclude_fids"] = []
        json["filelist"] = [item.id]
        json["to_pdir_fid"] = directory.id
        
        var params = [String: Any]()
        params["pr"] = "ucpro"
        params["fr"] = "pc"
        post(url: url, params: params, json: json, headers: headers, completion: completion)
    }
    
    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = "https://drive.quark.cn/1/clouddrive/file/delete"
        var json = [String: Any]()
        json["action_type"] = 1
        json["exclude_fids"] = []
        json["filelist"] = [item.id]
        
        var params = [String: Any]()
        params["pr"] = "ucpro"
        params["fr"] = "pc"
        post(url: url, params: params, json: json, headers: headers, completion: completion)
    }
    
    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        let url = "https://drive.quark.cn/1/clouddrive/file/rename"
        let json = [
            "fid": item.id,
            "file_name": newName
        ]
        var params = [String: Any]()
        params["pr"] = "ucpro"
        params["fr"] = "pc"
        post(url: url, params: params, json: json, headers: headers, completion: completion)
    }
    
    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        let url = "https://drive.quark.cn/1/clouddrive/file/search"
        var params = [String: Any]()
        params["q"] = keyword
        params["pr"] = "ucpro"
        params["fr"] = "pc"
        
        get(url: url, params: params, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let object = result.json as? [String: Any], let data = object["data"] as? [String: Any], let list = data["list"] as? [[String: Any]] {
                    let files = list.compactMap { QuarkServiceProvider.cloudItemFromJSON($0) }
                    completion(.success(files))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
    }
    
    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        
    }
}

extension QuarkServiceProvider {
    
    private var headers: [String: String] {
        return [
            "Cookie":  credential?.password ?? "",
            "Accept":  "application/json, text/plain, */*",
            "Referer": "https://pan.quark.cn/"]
    }
    
    private func updatePuus(_ puss: String) {
        let cookie = credential?.password ?? ""
        var components = cookie.components(separatedBy: ";")
        if let index = components.firstIndex(where: { $0.contains("__puus=") }) {
            components[index] = puss
            let newCookie = components.joined(separator: ";")
            self.credential = URLCredential(user: "", password: newCookie, persistence: .forSession)
            self.cookieRefreshedHandler?(newCookie)
        }
    }
    
    public static func cloudItemFromJSON(_ json: [String : Any]) -> CloudItem? {
        guard let id = json["fid"] as? String, let filename = json["file_name"] as? String else {
            return nil
        }
        let isFolder = (json["file"] as? Bool) == false
        let item = CloudItem(id: id, name: filename, path: filename, isDirectory: isFolder, json: json)
        if let size = json["size"] as? Int64 {
            item.size = size
        }
        if let ctime = json["created_at"] as? TimeInterval {
            item.creationDate = Date(timeIntervalSince1970: ctime/1000.0)
        }
        if let mtime = json["l_updated_at"] as? TimeInterval {
            item.modificationDate = Date(timeIntervalSince1970: mtime/1000.0)
        }
        return item
    }
    
    public func getWebContentLink(_ item: CloudItem, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let url = "https://drive.quark.cn/1/clouddrive/file/download"
        let json = ["fids": [item.id]]
        
        var params = [String: Any]()
        params["pr"] = "ucpro"
        params["fr"] = "pc"
        post(url: url, params: params, json: json, headers: headers) { response in
            switch response.result {
            case .success(let result):
                if let json = result.json as? [String: Any],
                   let data = (json["data"] as? [[String: Any]])?.first,
                    let downloadLink = data["download_url"] as? String,
                    let url = URL(string: downloadLink) {
                    var urlRequest = URLRequest(url: url)
                    urlRequest.setValue(self.credential?.password ?? "", forHTTPHeaderField: "Cookie")
                    completion(.success(urlRequest))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(result)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

public class QuarkConnector: CloudServiceConnector {
        
    public let cookie: String
    
    public init(cookie: String) {
        self.cookie = cookie
        super.init(appId: "", appSecret: "", callbackUrl: "")
    }
    
    public func login(completion: @escaping (Result<QuarkServiceProvider, Error>) -> Void) {
        let provider = QuarkServiceProvider(credential: URLCredential(user: "", password: cookie, persistence: .forSession))
        completion(.success(provider))
    }
}
