//
//  CloudAccountManager.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/29.
//

import Foundation
import KeychainAccess

class CloudAccount: Codable, Equatable {
    
    static func == (lhs: CloudAccount, rhs: CloudAccount) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    let identifier: String
    
    let username: String
    
    let driveType: CloudDriveType
    
    var oauthToken: String
    
    var refreshToken: String?
    
    init(type: CloudDriveType, username: String, oauthToken: String) {
        self.identifier = UUID().uuidString
        self.driveType = type
        self.username = username
        self.oauthToken = oauthToken
    }
}

class CloudAccountManager {
 
    static let shared = CloudAccountManager()
    
    private let keychain = Keychain(service: "me.shuifeng.CloudServiceKit.CloudAccount")
    
    private(set) var accounts: [CloudAccount] = []
    
    private let key = "accounts"
    
    private init() {
        if let data = try? keychain.getData(key) {
            let items = try? JSONDecoder().decode([CloudAccount].self, from: data)
            accounts = items ?? []
        }
    }
    
    func remove(_ account: CloudAccount) {
        if let index = accounts.firstIndex(of: account) {
            accounts.remove(at: index)
            save()
        }
    }
    
    func upsert(_ account: CloudAccount) {
        if let index = accounts.firstIndex(of: account) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(accounts)
            try keychain.set(data, key: key)
        } catch {
            print(error)
        }
    }
}
