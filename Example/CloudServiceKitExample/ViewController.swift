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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        navigationItem.title = "CloudServiceKit"
        setupCollectionView()
        setupDataSource()
        applyInitialSnapshot()
    }

    private func connect(_ drive: CloudDriveType) {
        let connector: CloudServiceConnector
        switch drive {
        case .baiduPan:
            connector = BaiduPanConnector(appId: "", appSecret: "", callbackUrl: "")
        case .box:
            connector = BoxConnector(appId: "", appSecret: "", callbackUrl: "")
        case .dropbox:
            connector = DropboxConnector(appId: "", appSecret: "", callbackUrl: "")
        case .googleDrive:
            connector = GoogleDriveConnector(appId: "", appSecret: "", callbackUrl: "")
        case .oneDrive:
            connector = OneDriveConnector(appId: "", appSecret: "", callbackUrl: "")
        case .pCloud:
            connector = PCloudConnector(appId: "", appSecret: "", callbackUrl: "")
        }
        print(connector)
        
    }
}

// MARK: - Setup
extension ViewController {
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
