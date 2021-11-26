//
//  DriveBrowserViewController.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/18.
//

import UIKit
import CloudServiceKit

class DriveBrowserViewController: UIViewController {

    enum Section {
        case main
    }
    
    private var collectionView: UICollectionView!
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, CloudItem>!
    
    let provider: CloudServiceProvider
    
    let directory: CloudItem
    
    init(provider: CloudServiceProvider, directory: CloudItem) {
        self.provider = provider
        self.directory = directory
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = directory.name
        setupCollectionView()
        setupDataSource()
        applySnapshot()
    }
    
}

// MARK: - Setup
extension DriveBrowserViewController {
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }
    
    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, CloudItem> { (cell, indexPath, item) in
            var content = cell.defaultContentConfiguration()
            content.image = item.isDirectory ? UIImage(named: "folder_32x32_"): UIImage(named: "file_32x32_")
            content.text = item.name
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, CloudItem>(collectionView: collectionView, cellProvider: { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        })
    }
    
    private func applySnapshot() {
        provider.contentsOfDirectory(directory) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let items):
                var snapshot = NSDiffableDataSourceSnapshot<Section, CloudItem>()
                snapshot.appendSections([.main])
                snapshot.appendItems(items)
                self.dataSource.apply(snapshot, animatingDifferences: false)
            case .failure(let error):
                print(error)
            }
        }
    }
}

// MARK: - UICollectionViewDelegate
extension DriveBrowserViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        if item.isDirectory {
            let vc = DriveBrowserViewController(provider: provider, directory: item)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            print("Do with files")
        }
    }
    
}

// MARK: - CloudDriveKit
extension DriveBrowserViewController {
    
    // You can test more function, eg: add trailing context
    func removeItem(_ item: CloudItem) {
        provider.removeItem(item) { response in
            switch response.result {
            case .success(_):
                print("Remove success")
            case .failure(let error):
                print("Remove failed:\(error.localizedDescription)")
            }
        }
    }
}
