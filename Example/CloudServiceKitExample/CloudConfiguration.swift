//
//  CloudConfiguration.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/28.
//

import Foundation

struct CloudConfiguration {
    
    let appId: String
    
    let appSecret: String
    
    let redirectUrl: String
}

extension CloudConfiguration {
    
    static var aliyun: CloudConfiguration? {
        // fulfill your aliyundrive app info
        return nil
    }
    
    static var baidu: CloudConfiguration? {
        // fulfill your baidu app info
        return nil
    }
    
    static var box: CloudConfiguration? {
        return nil
    }
    
    static var dropbox: CloudConfiguration? {
        return nil
    }
    
    static var googleDrive: CloudConfiguration? {
        return nil
    }
    
    static var oneDrive: CloudConfiguration? {
        return nil
    }
    
    static var pCloud: CloudConfiguration? {
        return nil
    }
    
    static var drive115: CloudConfiguration? {
        return nil
    }
}
