//
//  CloudServiceConnector.swift
//  CloudServiceKit
//
//  Created by alexiscn on 2021/8/26.
//

import Foundation
import OAuthSwift

public protocol CloudServiceOAuth {
    
    var authorizeUrl: String { get }
    
    var accessTokenUrl: String { get }

}

/// The base connector provided by CloudService.
/// CloudServiceKit provides a default connector for each cloud service, such as `DropboxConnector`.
/// You can implement your own connector if you want customizations.
public class CloudServiceConnector: CloudServiceOAuth {
    
    /// subclass must provide authorizeUrl
    public var authorizeUrl: String { return "" }
    
    /// subclass must provide accessTokenUrl
    public var accessTokenUrl: String { return "" }
    
    public var scope: String = ""
    
    public var responseType: String
    
    /// The appId or appKey of your service.
    let appId: String
    
    /// The app scret of your service.
    let appSecret: String
    
    /// The redirectUrl.
    let callbackUrl: String
    
    public let state: String
    
    private var oauth: OAuth2Swift?
    
    
    /// Create cloud service connector
    /// - Parameters:
    ///   - appId: The appId.
    ///   - appSecret: The app secret.
    ///   - callbackUrl: The redirect url
    ///   - responseType: The response type.  The default value is `code`.
    ///   - scope: The scope your app use for the service.
    ///   - state: The state information. The default value is empty.
    public init(appId: String, appSecret: String, callbackUrl: String, responseType: String = "code", scope: String = "", state: String = "") {
        self.appId = appId
        self.appSecret = appSecret
        self.callbackUrl = callbackUrl
        self.responseType = responseType
        self.scope = scope
        self.state = state
    }
    
    public func connect(viewController: UIViewController,
                        completion: @escaping (Result<OAuthSwift.TokenSuccess, Error>) -> Void) {
        let oauth = OAuth2Swift(consumerKey: appId, consumerSecret: appSecret, authorizeUrl: authorizeUrl, accessTokenUrl: accessTokenUrl, responseType: responseType, contentType: nil)
        oauth.allowMissingStateCheck = true
        oauth.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauth)
        self.oauth = oauth
        _ = oauth.authorize(withCallbackURL: URL(string: callbackUrl), scope: scope, state: state, completionHandler: { result in
            switch result {
            case .success(let token):
                completion(.success(token))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    public func renewToken(with refreshToken: String, completion: @escaping (Result<OAuthSwift.TokenSuccess, Error>) -> Void) {
        let oauth = OAuth2Swift(consumerKey: appId, consumerSecret: appSecret, authorizeUrl: authorizeUrl, accessTokenUrl: accessTokenUrl, responseType: responseType, contentType: nil)
        oauth.allowMissingStateCheck = true
        oauth.renewAccessToken(withRefreshToken: refreshToken) { result in
            switch result {
            case .success(let token):
                completion(.success(token))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        self.oauth = oauth
    }
}

// MARK: - BaiduPanConnector
public class BaiduPanConnector: CloudServiceConnector {
    
    /// The OAuth2 url, which is `https://openapi.baidu.com/oauth/2.0/authorize`.
    public override var authorizeUrl: String { return "https://openapi.baidu.com/oauth/2.0/authorize" }
    
    /// The access token url, which is `https://openapi.baidu.com/oauth/2.0/token`.
    public override var accessTokenUrl: String { return "https://openapi.baidu.com/oauth/2.0/token" }
    
    /// The scope to access baidu pan service. The default and only value is `basic,netdisk`.
    public override var scope: String {
        get { return "basic,netdisk" }
        set {  }
    }
}

// MARK: - BoxConnector
public class BoxConnector: CloudServiceConnector {
    
    public override var authorizeUrl: String {
        return "https://account.box.com/api/oauth2/authorize"
    }
    
    public override var accessTokenUrl: String {
        return "https://api.box.com/oauth2/token"
    }
    
    private var defaultScope = "root_readwrite"
    public override var scope: String {
        get { return defaultScope }
        set { defaultScope = newValue }
    }
}

// MARK: - DropboxConnector
public class DropboxConnector: CloudServiceConnector {
    
    public override var authorizeUrl: String {
        return "https://www.dropbox.com/oauth2/authorize?token_access_type=offline"
    }
    
    public override var accessTokenUrl: String {
        return "https://api.dropbox.com/oauth2/token"
    }
}

// MARK: - GoogleDriveConnector
public class GoogleDriveConnector: CloudServiceConnector {
    
    public override var authorizeUrl: String {
        return "https://accounts.google.com/o/oauth2/auth"
    }
    
    public override var accessTokenUrl: String {
        return "https://accounts.google.com/o/oauth2/token"
    }
    
    private var defaultScope = "https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/userinfo.profile"
    public override var scope: String {
        get { return defaultScope }
        set { defaultScope = newValue }
    }
}


// MARK: - OneDriveConnector
public class OneDriveConnector: CloudServiceConnector {

    public override var authorizeUrl: String {
        return "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
    }

    public override var accessTokenUrl: String {
        return "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    }

    private var defaultScope = "offline_access User.Read Files.ReadWrite.All"
    /// The scope to access OneDrive service. The default value is `offline_access User.Read Files.ReadWrite.All`.
    public override var scope: String {
        get { return defaultScope }
        set { defaultScope = newValue }
    }
}

// MARK: - PCloudConnector
public class PCloudConnector: CloudServiceConnector {
    
    public override var authorizeUrl: String {
        return "https://my.pcloud.com/oauth2/authorize"
    }
    
    public override var accessTokenUrl: String {
        return "https://api.pcloud.com/oauth2_token"
    }
    
    public override func renewToken(with refreshToken: String, completion: @escaping (Result<OAuthSwift.TokenSuccess, Error>) -> Void) {
        // pCloud OAuth does not respond with a refresh token, so renewToken is unsupported.
        completion(.failure(CloudServiceError.unsupported))
    }
}
