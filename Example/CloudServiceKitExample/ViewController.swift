//
//  ViewController.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/18.
//

import UIKit
import CloudServiceKit
import OAuthSwift

class ViewController: UIViewController {

    enum Section {
        case main
        case saved
    }
    
    enum Item: Hashable {
        case provider(CloudDriveType)
        case cached(CloudAccount)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .cached(let account):
                hasher.combine(account.identifier)
            case .provider(let type):
                hasher.combine(type)
            }
        }
    }
    
    private var collectionView: UICollectionView!
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private var connector: CloudServiceConnector?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        navigationItem.title = "CloudServiceKit"
        setupCollectionView()
        setupDataSource()
        applyInitialSnapshot()
    }

    private func connect(_ drive: CloudDriveType) {
        let connector = connector(for: drive)

        if drive == .drive115 {
            let vc = Drive115QRCodeViewController(connector: connector as! Drive115Connector)
            vc.completionHandler = { (accessToken: Drive115Connector.AccessTokenPayload) in
                self.dismiss(animated: true) {
                    let credential = URLCredential(user: "user", password: accessToken.accessToken, persistence: .permanent)
                    let provider = self.provider(for: drive, credential: credential)
                    let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        } else {
            connector.connect(viewController: self) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let token):
                    
                    // fetch current user info to save account
                    let credential = URLCredential(user: "user", password: token.credential.oauthToken, persistence: .permanent)
                    let provider = self.provider(for: drive, credential: credential)
                    if let aliyun = provider as? AliyunDriveServiceProvider {
                        aliyun.getDriveInfo(completion: { driveInfoResult in
                            switch driveInfoResult {
                            case .success(let info):
                                aliyun.driveId = info.defaultDriveId
                                provider.getCurrentUserInfo { [weak self] userResult in
                                    guard let self = self else { return }
                                    switch userResult {
                                    case .success(let user):
                                        let account = CloudAccount(type: drive,
                                                                   username: user.username,
                                                                   oauthToken: token.credential.oauthToken)
                                        account.refreshToken = token.credential.oauthRefreshToken
                                        CloudAccountManager.shared.upsert(account)
                                        
                                        self.applyInitialSnapshot()
                                    case .failure(let error):
                                        print(error)
                                    }
                                    let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                                    self.navigationController?.pushViewController(vc, animated: true)
                                }
                            case .failure(let error):
                                print(error)
                            }
                        })
                    } else {
                        provider.getCurrentUserInfo { [weak self] userResult in
                            guard let self = self else { return }
                            switch userResult {
                            case .success(let user):
                                let account = CloudAccount(type: drive,
                                                           username: user.username,
                                                           oauthToken: token.credential.oauthToken)
                                account.refreshToken = token.credential.oauthRefreshToken
                                CloudAccountManager.shared.upsert(account)
                                
                                self.applyInitialSnapshot()
                            case .failure(let error):
                                print(error)
                            }
                            let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                            self.navigationController?.pushViewController(vc, animated: true)
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
        self.connector = connector
    }
    
    private func connector(for drive: CloudDriveType) -> CloudServiceConnector {
        let message = "Please configure app info in CloudConfiguration.swift"
        let connector: CloudServiceConnector
        switch drive {
        case .aliyunDrive:
            assert(CloudConfiguration.aliyun != nil, message)
            let aliyun = CloudConfiguration.aliyun!
            connector = AliyunDriveConnector(appId: aliyun.appId, appSecret: aliyun.appSecret, callbackUrl: aliyun.redirectUrl)
            connector.customURLHandler = CustomOAuthWebViewController(callbackUrl: aliyun.redirectUrl)
        case .baiduPan:
            assert(CloudConfiguration.baidu != nil, message)
            let baidu = CloudConfiguration.baidu!
            connector = BaiduPanConnector(appId: baidu.appId, appSecret: baidu.appSecret, callbackUrl: baidu.redirectUrl)
        case .box:
            assert(CloudConfiguration.box != nil, message)
            let box = CloudConfiguration.box!
            connector = BoxConnector(appId: box.appId, appSecret: box.appSecret, callbackUrl: box.appSecret)
        case .dropbox:
            assert(CloudConfiguration.dropbox != nil, message)
            let dropbox = CloudConfiguration.dropbox!
            connector = DropboxConnector(appId: dropbox.appId, appSecret: dropbox.appSecret, callbackUrl: dropbox.appSecret)
        case .googleDrive:
            assert(CloudConfiguration.googleDrive != nil, message)
            let googledrive = CloudConfiguration.googleDrive!
            connector = GoogleDriveConnector(appId: googledrive.appId, appSecret: googledrive.appSecret, callbackUrl: googledrive.redirectUrl)
        case .oneDrive:
            assert(CloudConfiguration.oneDrive != nil, message)
            let onedrive = CloudConfiguration.oneDrive!
            connector = OneDriveConnector(appId: onedrive.appId, appSecret: onedrive.appSecret, callbackUrl: onedrive.redirectUrl)
        case .pCloud:
            assert(CloudConfiguration.pCloud != nil, message)
            let pcloud = CloudConfiguration.pCloud!
            connector = PCloudConnector(appId: pcloud.appId, appSecret: pcloud.appSecret, callbackUrl: pcloud.redirectUrl)
        case .drive115:
            assert(CloudConfiguration.drive115 != nil, message)
            let drive115 = CloudConfiguration.drive115!
            connector = Drive115Connector(appId: drive115.appId, appSecret: drive115.appSecret, callbackUrl: drive115.redirectUrl)
        case .drive123:
            assert(CloudConfiguration.drive123 != nil, message)
            let drive123 = CloudConfiguration.drive123!
            connector = Drive123Connector(appId: drive123.appId, appSecret: drive123.appSecret, callbackUrl: drive123.redirectUrl)
        }
        return connector
    }
    
    private func provider(for driveType: CloudDriveType, credential: URLCredential) -> CloudServiceProvider {
        let provider: CloudServiceProvider
        switch driveType {
        case .aliyunDrive:
            provider = AliyunDriveServiceProvider(credential: credential)
        case .baiduPan:
            provider = BaiduPanServiceProvider(credential: credential)
        case .box:
            provider = BoxServiceProvider(credential: credential)
        case .dropbox:
            provider = DropboxServiceProvider(credential: credential)
        case .googleDrive:
            provider = GoogleDriveServiceProvider(credential: credential)
        case .oneDrive:
            provider = OneDriveServiceProvider(credential: credential)
        case .pCloud:
            provider = PCloudServiceProvider(credential: credential)
        case .drive115:
            provider = Drive115ServiceProvider(credential: credential)
        case .drive123:
            provider = Drive123ServiceProvider(credential: credential)
        }
        return provider
    }
    
    private func connect(_ account: CloudAccount) {
        let connector = connector(for: account.driveType)
        if let refreshToken = account.refreshToken, !refreshToken.isEmpty {
            // For BaiduPan, we only refresh access token when it expires
            if account.driveType == .baiduPan {
                let credential = URLCredential(user: account.username,
                                               password: account.oauthToken,
                                               persistence: .permanent)
                let provider = provider(for: account.driveType, credential: credential)
                provider.refreshAccessTokenHandler = { [weak self] callback in
                    guard let self = self else { return }
                    self.refreshAccessToken(with: refreshToken, connector: connector, account: account) { result in
                        callback?(result)
                    }
                }
                let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                connector.renewToken(with: refreshToken) { result in
                    switch result {
                    case .success(let token):
                        
                        // update oauth token and refresh token of existing account
                        account.oauthToken = token.credential.oauthToken
                        if !token.credential.oauthRefreshToken.isEmpty {
                            account.refreshToken = token.credential.oauthRefreshToken
                        }
                        CloudAccountManager.shared.upsert(account)
                        
                        // create CloudServiceProvider with new oauth token
                        let credential = URLCredential(user: account.username,
                                                       password: token.credential.oauthToken,
                                                       persistence: .permanent)
                        let provider = self.provider(for: account.driveType, credential: credential)
                        
                        let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                        self.navigationController?.pushViewController(vc, animated: true)
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        } else {
            // For pCloud which do not contains refresh token and its oauth is valid for long time
            // we just use cached oauth token to create CloudServiceProvider
            let credential = URLCredential(user: account.username,
                                           password: account.oauthToken,
                                           persistence: .permanent)
            let provider = provider(for: account.driveType, credential: credential)
            let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
            self.navigationController?.pushViewController(vc, animated: true)
        }
        self.connector = connector
    }
    
    private func refreshAccessToken(with refreshToken: String, connector: CloudServiceConnector, account: CloudAccount, completionHandler: @escaping (Result<URLCredential, Error>) -> Void) {
        connector.renewToken(with: refreshToken) { result in
            switch result {
            case .success(let token):
                // update oauth token and refresh token of existing account
                account.oauthToken = token.credential.oauthToken
                if !token.credential.oauthRefreshToken.isEmpty {
                    account.refreshToken = token.credential.oauthRefreshToken
                }
                CloudAccountManager.shared.upsert(account)
                let credential = URLCredential(user: account.username,
                                               password: token.credential.oauthToken,
                                               persistence: .permanent)
                completionHandler(.success(credential))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}

// MARK: - Setup
extension ViewController {
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }
    
    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { (cell, indexPath, item) in
            var content = cell.defaultContentConfiguration()
            switch item {
            case .cached(let account):
                content.image = account.driveType.image
                content.text = account.username
            case .provider(let driveItem):
                content.image = driveItem.image
                content.text = driveItem.title
            }
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView, cellProvider: { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        })
    }
    
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(CloudDriveType.allCases.map { Item.provider($0) }, toSection: .main)
        
        let accounts = CloudAccountManager.shared.accounts
        if !accounts.isEmpty {
            snapshot.appendSections([.saved])
            snapshot.appendItems(accounts.map { Item.cached($0) }, toSection: .saved)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .provider(let driveType):
            connect(driveType)
        case .cached(let account):
            connect(account)
        }
    }
}
