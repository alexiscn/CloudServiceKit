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
    
    private var collectionView: UICollectionView!
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, CloudDriveType>!
    
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
        connector.connect(viewController: self) { result in
            switch result {
            case .success(let token):
                // you can save token here
                // if you want get current authed user, you can call
                // provider.getCurrentAccount(completion:)
                let credential = URLCredential(user: "user", password: token.credential.oauthToken, persistence: .permanent)
                let provider = self.provider(for: drive, credential: credential)
                let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                self.navigationController?.pushViewController(vc, animated: true)
            case .failure(let error):
                print(error)
            }
        }
        self.connector = connector
    }
    
    private func connector(for drive: CloudDriveType) -> CloudServiceConnector {
        let message = "Please configure app info in CloudConfiguration.swift"
        let connector: CloudServiceConnector
        switch drive {
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
        }
        return connector
    }
    
    private func provider(for driveType: CloudDriveType, credential: URLCredential) -> CloudServiceProvider {
        let provider: CloudServiceProvider
        switch driveType {
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
        }
        return provider
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
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, CloudDriveType> { (cell, indexPath, item) in
            var content = cell.defaultContentConfiguration()
            content.image = item.image
            content.text = item.title
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, CloudDriveType>(collectionView: collectionView, cellProvider: { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        })
    }
    
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, CloudDriveType>()
        snapshot.appendSections([.main])
        snapshot.appendItems(CloudDriveType.allCases, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let driveItem = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        connect(driveItem)
    }
}
