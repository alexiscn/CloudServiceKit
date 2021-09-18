# CloudServiceKit

Easy to integrate cloud service using Oauth2. Supported platforms:

- [x] BaiduPan
- [x] Box
- [x] Dropbox
- [x] Google Drive
- [x] OneDrive
- [x] pCloud

# Installation

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

# CloudServiceProvider

`CloudServiceProvider` is a protocol offers methods to operate with cloud services.

- list `contents(at:)`
- delete
- move
- rename
- mkdir

## Get Started

Create a connector of the cloud service, pass the 

```swift
let connector = DropboxConnector(appId: "your_app_id", appSecret: "your_app_secret", callbackUrl: "your_app_redirect_url")
connector.connect(token: nil, from: self) // self is an instance of UIViewController

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

If you want to create your own connector

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
