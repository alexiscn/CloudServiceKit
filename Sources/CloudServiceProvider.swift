import Foundation

/// The general response with CloudServiceProvider.
public struct CloudResponse<HTTPResult, Failure: Error> {
    
    /// The origin http response. Maybe `nil` if throws error by CloudServiceKit.
    public let response: HTTPResult?
    
    /// The result of response.
    public let result: Result<HTTPResult, Failure>
    
    public init(response: HTTPResult?, result: Result<HTTPResult, Failure>) {
        self.response = response
        self.result = result
    }
}

/// Common completion handler for cloud file operations, such as copy/move/rename
/// Note: The completion block will called in main-thread.
public typealias CloudCompletionHandler = (CloudResponse<HTTPResult, Error>) -> Void

/// Cloud refresh acess token handler.
public typealias CloudRefreshAccessTokenHandler = (((Result<URLCredential, Error>) -> Void)?) -> Void

// CloudServiceResponseProcessing
public protocol CloudServiceResponseProcessing {
    
    /// Parse `CloudItem` from JSON.
    /// - Parameter json: JSON object of file item.
    static func cloudItemFromJSON(_ json: [String: Any]) -> CloudItem?
    
    /// Return `true` if service provider wants to process the response. Default value is `false`.
    /// - Parameters:
    ///   - response: The response object to be processed.
    ///   - completion: The completion block.
    func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool
    
}

/// Some cloud service (eg: BaiduPan, Dropbox) supports batch operations
public protocol CloudServiceBatching {
    
    /// Remove items.
    /// - Parameters:
    ///   - items: The items to be removed.
    ///   - completion: Completion block.
    func removeItems(_ items: [CloudItem], completion: @escaping CloudCompletionHandler)
    
    /// Move items to target directory.
    /// - Parameters:
    ///   - items: The items to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    func moveItems(_ items: [CloudItem], to directory: CloudItem, completion: @escaping CloudCompletionHandler)
}

/// The protocol of cloud service provider.
public protocol CloudServiceProvider: AnyObject, CloudServiceResponseProcessing {

    /// The name the cloud service.
    var name: String { get }
    
    /// The credential to login with cloud service.
    var credential: URLCredential? { get set }
    
    /// The refresh token to refresh the access token. If provided, CloudSeriveKit will automatically handle the access token expires.
    /// Note: The access token of some cloud service (eg: OneDrive) are short time. So we need a refresh token to refresh the access token when expired.
    var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler? { get set }
    
    /// The root path of cloud service. You can use this property to load contents at root directory.
    var rootItem: CloudItem { get }
    
    init(credential: URLCredential?)
    
    /// Get attributes of cloud item.
    /// - Parameters:
    ///   - item: The target item.
    ///   - completion: Completion callback.
    func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void)
    
    /// Load the contents at directory.
    /// - Parameters:
    ///   - directory: The target directory to load.
    ///   - completion: Completion callback.
    func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void)
    
    /// Copy item to directory
    /// - Parameters:
    ///   - item: The item to be copied.
    ///   - directory: The destination directory.
    ///   - completion: Completion callback.
    func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler)
    
    /// Create folder at directory.
    /// - Parameters:
    ///   - folderName: The folder to be created.
    ///   - directory: The destination directory.
    ///   - completion: Completion callback. The completion block will called in main-thread.
    func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler)
    
    /// Get the space usage information for the current user's account.
    /// - Parameter completion: Completion block.
    func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void)
    
    /// Get information about the current user's account.
    /// - Parameter completion: Completion block.
    func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void)
    
    /// Move item to target directory.
    /// - Parameters:
    ///   - item: The item to be moved.
    ///   - directory: The target directory.
    ///   - completion: Completion block.
    func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler)
    
    /// Remove cloud file/folder item.
    /// - Parameters:
    ///   - item: The item to be removed.
    ///   - completion: Completion block.
    func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler)
    
    /// Rename cloud file/folder to a new name.
    /// - Parameters:
    ///   - item: The item to be renamed.
    ///   - newName: The new name.
    ///   - completion: Completion block.
    func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler)
    
    /// Search files with provided keyword.
    /// - Parameters:
    ///   - keyword: The keyword.
    ///   - completion: Completion block.
    func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void)
    
    /// Upload file data to target directory.
    /// - Parameters:
    ///   - data: The data to be uploaded.
    ///   - filename: The filename to be created.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler)
    
    /// Upload file to target directory with local file url.
    /// Note: remote file url is not supported.
    /// - Parameters:
    ///   - fileURL: The local file url.
    ///   - directory: The target directory.
    ///   - progressHandler: The upload progress reporter. Called in main thread.
    ///   - completion: Completion block.
    func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler)
}

// Default implementation of CloudServiceProvider
extension CloudServiceProvider {
    
    public var refreshAccessTokenHandler: (((Result<URLCredential, Error>) -> Void) -> Void)? {
        return nil
    }
    
    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        return false
    }
}

// MARK: - Helper
extension CloudServiceProvider {
    
    func fileSize(of fileURL: URL) -> Int64? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            print(error)
        }
        return nil
    }
    
}

// MARK: - HTTP Requests
extension CloudServiceProvider {
    
    public func get(url: URLComponentsConvertible, params: [String: Any] = [:], headers: [String: String] = [:], completion: @escaping CloudCompletionHandler) {
        request(.get, url: url, params: params, data: [:], headers: headers, completion: completion)
    }
    
    public func post(url: URLComponentsConvertible,
                     params: [String: Any] = [:],
                     data: [String: Any] = [:],
                     json: Any? = nil,
                     headers: [String: String] = [:],
                     files: [String: HTTPFile] = [:],
                     requestBody: Data? = nil,
                     progressHandler: ((HTTPProgress) -> Void)? = nil,
                     completion: @escaping CloudCompletionHandler) {
        request(.post, url: url, params: params, data: data, json: json, headers: headers, files: files, requestBody: requestBody, progressHandler: progressHandler, completion: completion)
    }
    
    public func delete(url: URLComponentsConvertible,
                       headers: [String: String] = [:],
                       completion: @escaping CloudCompletionHandler) {
        request(.delete, url: url, params: [:], data: [:], headers: headers, completion: completion)
    }
    
    public func put(url: URLComponentsConvertible,
                    params: [String: Any] = [:],
                    data: [String: Any] = [:],
                    json: Any? = nil,
                    headers: [String: String] = [:],
                    files: [String: HTTPFile] = [:],
                    requestBody: Data? = nil,
                    progressHandler: ((HTTPProgress) -> Void)? = nil,
                    completion: @escaping CloudCompletionHandler) {
        request(.put, url: url, params: params, data: data, json: json, headers: headers, files: files, requestBody: requestBody, progressHandler: progressHandler, completion: completion)
    }
    
    public func patch(url: URLComponentsConvertible,
                      params: [String: Any] = [:],
                      data: [String: Any] = [:],
                      json: Any? = nil,
                      headers: [String: String] = [:],
                      completion: @escaping CloudCompletionHandler) {
        request(.patch, url: url, params: params, data: data, json: json, headers: headers, completion: completion)
    }
    
    func request(_ method: HTTPMethod,
                 url: URLComponentsConvertible,
                 params: [String: Any] = [:],
                 data: [String: Any] = [:],
                 json: Any? = nil,
                 headers: [String: String] = [:],
                 files: [String: HTTPFile] = [:],
                 requestBody: Data? = nil,
                 progressHandler: ((HTTPProgress) -> Void)? = nil,
                 completion: @escaping CloudCompletionHandler) {
        
        var httpheaders = headers
        httpheaders["Authorization"] = "Bearer \(credential?.password ?? "")"
        
        Just.request(method, url: url, params: params, data: data, json: json,
                     headers: httpheaders, files: files, requestBody: requestBody, asyncProgressHandler: { progress in
            DispatchQueue.main.async {
                progressHandler?(progress)
            }
        }, asyncCompletionHandler: { response in
            DispatchQueue.main.async {
                self.handleResponse(response,
                                    method: method,
                                    url: url,
                                    params: params,
                                    data: data,
                                    json: json,
                                    headers: headers,
                                    requestBody: requestBody,
                                    progressHandler: progressHandler,
                                    completion: completion)
            }
        })
    }
    
    func handleResponse(_ response: HTTPResult,
                        method: HTTPMethod,
                        url: URLComponentsConvertible,
                        params: [String: Any] = [:],
                        data: [String: Any] = [:],
                        json: Any? = nil,
                        headers: [String: String] = [:],
                        requestBody: Data? = nil,
                        progressHandler: ((HTTPProgress) -> Void)? = nil,
                        completion: @escaping CloudCompletionHandler) {
        if let error = response.error {
            if response.statusCode == 401, let refreshAccessTokenHandler = refreshAccessTokenHandler {
                refreshAccessTokenHandler { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let credential):
                        self.credential = credential
                        self.request(method, url: url,
                                     params: params, data: data,
                                     json: json, headers: headers,
                                     progressHandler: progressHandler, completion: completion)
                    case .failure(let error):
                        completion(CloudResponse(response: response, result: .failure(error)))
                    }
                }
            } else {
                completion(CloudResponse(response: response, result: .failure(error)))
            }
        } else {
            if !shouldProcessResponse(response, completion: completion) {
                completion(CloudResponse(response: response, result: .success(response)))
            }
        }
    }
}
