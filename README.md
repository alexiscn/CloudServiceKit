# CloudServiceKit

Easy to integrate cloud service using Oauth2. Supported platforms:

- [x] BaiduPan
- [x] Box
- [x] Dropbox
- [x] Google Drive
- [x] OneDrive
- [x] pCloud

## Requirements

- Swift 5.0 +
- Xcode 12 +
- iOS 13.0 +

## Installation

#### CocoaPods
CloudServiceKit is available through CocoaPods. To install it, simply add the following line to your Podfile:

```bash
pod 'CloudServiceKit'
```

#### Swift Package Manager

The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding CloudServiceKit as a dependency is as easy as adding it to the dependencies value of your Package.swift.

```bash
dependencies: [
    .package(url: "https://github.com/alexiscn/CloudServiceKit.git", from: "1.0.0")
]
```

## Get Started

Using `CloudServiceKit` should follow following steps:

> Assuming that you have already registered app and got `appId`, `appSecret` and `redirectUrl`.

### 1. Create a connector

Create a connector of the cloud service, pass the necessary parameters:

```swift
let connector = DropboxConnector(appId: "your_app_id", appSecret: "your_app_secret", callbackUrl: "your_app_redirect_url")
```

### 2. Handle the openURL

Since CloudServiceKit depends on [OAuthSwift](https://github.com/OAuthSwift/OAuthSwift). You app should handle openURL. Assuming your `redirectUrl` is like `filebox_oauth://oauth-callback`. 

* On iOS implement UIApplicationDelegate method

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey  : Any] = [:]) -> Bool {
  if url.host == "oauth-callback" {
    OAuthSwift.handle(url: url)
  }
  return true
}
```

* On iOS 13, UIKit will notify UISceneDelegate instead of UIApplicationDelegate. Implement UISceneDelegate method

```swift
import OAuthSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // ...

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let url = URLContexts.first?.url else {
            return
        }
        if url.host == "oauth-callback" {
            OAuthSwift.handle(url: url)
        }    
    }
```

### 3. Connect to service

```swift
connector.connect(viewController: self) { result in
    switch result {
    case .success(let token):
        let credential = URLCredential(user: "user", password: token.credential.oauthToken, persistence: .permanent)
        // You can save token for next use.
        let provider = DropboxServiceProvider(credential: credential)
        let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
        self.navigationController?.pushViewController(vc, animated: true)
    case .failure(let error):
        print(error)
    }
}
```


## CloudServiceProvider

`CloudServiceProvider` is a protocol offers methods to operate with cloud services.

```swift
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
```

## Connector

CloudServiceKit provides a default connector for each cloud service that CloudServiceKit supported. It handles OAuth2.0 flow. What you need to do is provide the app information that you applied from cloud service console.

```swift
let connector = DropboxConnector(appId: "{you_app_id}", 
                                 appSecret: "{your_app_secret}", 
                                 callbackUrl: "{your_redirect_url}")
```

Here is the connector list that CloudServiceKit supported.

- [x] BaiduPanConnector
- [x] BoxConnector
- [x] DropboxConnector
- [x] GoogleDriveConnector
- [x] OneDriveConnector
- [x] PCloudConnector 

You can also create your own connector.

## Advance Usage

You can create extensions to add more functions to existing providers.

Following example shows show to add lock file to Dropbox.

```swift
extension DropboxServiceProvider {
    
    func lock(file: CloudItem, completion: @escaping CloudCompletionHandler) {
        let url = apiURL.appendingPathComponents("")

    }
}
```
