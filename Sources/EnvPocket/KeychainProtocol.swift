//
//  KeychainProtocol.swift
//  EnvPocket
//
//  Created by thieso2 on 2024.
//  Copyright © 2025 thieso2. All rights reserved.
//
//  MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

// Protocol for keychain operations
protocol KeychainProtocol {
    func save(account: String, data: Data, label: String?, comment: String?) -> OSStatus
    func load(account: String) -> (data: Data?, attributes: [String: Any]?, status: OSStatus)
    func delete(account: String) -> OSStatus
    func list() -> (items: [[String: Any]], status: OSStatus)
}

// Real keychain implementation
class RealKeychain: KeychainProtocol {
    func save(account: String, data: Data, label: String?, comment: String?) -> OSStatus {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        if let label = label {
            query[kSecAttrLabel as String] = label
        }
        
        if let comment = comment {
            query[kSecAttrComment as String] = comment
        }
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    func load(account: String) -> (data: Data?, attributes: [String: Any]?, status: OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess,
           let result = item as? [String: Any] {
            let data = result[kSecValueData as String] as? Data
            return (data, result, status)
        }
        
        return (nil, nil, status)
    }
    
    func delete(account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary)
    }
    
    func list() -> (items: [[String: Any]], status: OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let items = result as? [[String: Any]] {
            return (items, status)
        } else if status == errSecItemNotFound {
            return ([], errSecSuccess)
        }
        
        return ([], status)
    }
}

// Mock keychain for testing
class MockKeychain: KeychainProtocol {
    private var storage: [String: (data: Data, attributes: [String: Any])] = [:]
    
    func save(account: String, data: Data, label: String?, comment: String?) -> OSStatus {
        var attributes: [String: Any] = [
            kSecAttrAccount as String: account
        ]
        
        if let label = label {
            attributes[kSecAttrLabel as String] = label
        }
        
        if let comment = comment {
            attributes[kSecAttrComment as String] = comment
        }
        
        storage[account] = (data, attributes)
        return errSecSuccess
    }
    
    func load(account: String) -> (data: Data?, attributes: [String: Any]?, status: OSStatus) {
        if let item = storage[account] {
            var attributes = item.attributes
            attributes[kSecValueData as String] = item.data
            return (item.data, attributes, errSecSuccess)
        }
        return (nil, nil, errSecItemNotFound)
    }
    
    func delete(account: String) -> OSStatus {
        if storage[account] != nil {
            storage.removeValue(forKey: account)
            return errSecSuccess
        }
        return errSecItemNotFound
    }
    
    func list() -> (items: [[String: Any]], status: OSStatus) {
        let items = storage.map { (key, value) in
            value.attributes
        }
        return (items, errSecSuccess)
    }
    
    // Helper method for tests to clear all data
    func clear() {
        storage.removeAll()
    }
}