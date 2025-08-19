// File: EnvPocket.swift

import Foundation
import Security

enum Command: String {
    case save, get, delete, list, history
}

let prefix = "envpocket:"
let historyPrefix = "envpocket-history:"

func getDateFormatter() -> ISO8601DateFormatter {
    return ISO8601DateFormatter()
}

func usage() {
    print("""
    Usage:
      envpocket save <key> <file>
      envpocket get <key> [<output_file>]
      envpocket get <key> --version <version_index> [<output_file>]
      envpocket delete <key>
      envpocket list
      envpocket history <key>
    
    Notes:
      - For 'get': if output_file is omitted, uses the original filename
      - Use '-' as output_file to write to stdout
    """)
}

func prefixedKey(_ key: String) -> String {
    return prefix + key
}

func historyKey(_ key: String, timestamp: Date) -> String {
    return historyPrefix + key + ":" + getDateFormatter().string(from: timestamp)
}

func saveFileToKeychain(key: String, filePath: String) {
    let account = prefixedKey(key)
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        print("Error: Could not read file at \(filePath)")
        exit(1)
    }
    
    // Get absolute path for storage
    let fileURL = URL(fileURLWithPath: filePath)
    let absolutePath = fileURL.path
    
    // Get current version if it exists and save to history
    let currentQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecReturnData as String: kCFBooleanTrue!,
        kSecReturnAttributes as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var currentItem: CFTypeRef?
    let currentStatus = SecItemCopyMatching(currentQuery as CFDictionary, &currentItem)
    
    // If there's an existing version, save it to history with current timestamp
    if currentStatus == errSecSuccess, 
       let currentResult = currentItem as? [String: Any],
       let currentData = currentResult[kSecValueData as String] as? Data {
        let timestamp = Date()
        let historyAccount = historyKey(key, timestamp: timestamp)
        
        // Preserve the original path from the current version if it exists
        let originalPath = currentResult[kSecAttrLabel as String] as? String ?? absolutePath
        
        let historyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: historyAccount,
            kSecValueData as String: currentData,
            kSecAttrLabel as String: originalPath
        ]
        let historyStatus = SecItemAdd(historyQuery as CFDictionary, nil)
        if historyStatus != errSecSuccess {
            print("Warning: Failed to save history: \(historyStatus)")
        }
    }
    
    // Delete existing current version
    let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account
    ]
    SecItemDelete(deleteQuery as CFDictionary)
    
    // Now save the new version as current with file path
    let newTimestamp = Date()
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecValueData as String: data,
        kSecAttrComment as String: "Last modified: \(getDateFormatter().string(from: newTimestamp))",
        kSecAttrLabel as String: absolutePath  // Store the original file path
    ]
    
    let status = SecItemAdd(query as CFDictionary, nil)
    
    if status == errSecSuccess {
        print("File saved to Keychain under key '\(key)' from \(absolutePath)")
        if currentStatus == errSecSuccess {
            print("Previous version backed up to history")
        }
    } else {
        print("Error saving to Keychain: \(status)")
        exit(1)
    }
}

func getFileFromKeychain(key: String, outputPath: String? = nil, versionIndex: Int? = nil) {
    var account = prefixedKey(key)
    
    // If version specified, get from history
    if let version = versionIndex {
        let historyItems = getHistoryForKey(key)
        if version >= 0 && version < historyItems.count {
            account = historyItems[version]
        } else {
            print("Error: Invalid version index. Use 'envpocket history \(key)' to see available versions.")
            exit(1)
        }
    }
    
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
       let result = item as? [String: Any],
       let data = result[kSecValueData as String] as? Data {
        
        // Determine output destination
        let finalOutputPath: String
        if let specifiedPath = outputPath {
            if specifiedPath == "-" {
                // Write to stdout
                FileHandle.standardOutput.write(data)
                if versionIndex != nil {
                    FileHandle.standardError.write("(Retrieved historical version)\n".data(using: .utf8)!)
                }
                return
            } else {
                finalOutputPath = specifiedPath
            }
        } else {
            // Use original filename from keychain
            if let originalPath = result[kSecAttrLabel as String] as? String {
                // Extract just the filename from the full path
                let url = URL(fileURLWithPath: originalPath)
                finalOutputPath = url.lastPathComponent
            } else {
                print("Error: No original filename stored for key '\(key)'. Please specify an output file.")
                exit(1)
            }
        }
        
        do {
            try data.write(to: URL(fileURLWithPath: finalOutputPath))
            print("File retrieved and saved to \(finalOutputPath)")
            if versionIndex != nil {
                print("(Retrieved historical version)")
            }
        } catch {
            print("Error writing file: \(error)")
            exit(1)
        }
    } else {
        print("Error retrieving from Keychain: \(status)")
        exit(1)
    }
}

func deleteFileFromKeychain(key: String) {
    // Delete current version
    let account = prefixedKey(key)
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account
    ]
    let status = SecItemDelete(query as CFDictionary)
    
    // Delete all history entries for this key
    let historyQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecReturnAttributes as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitAll
    ]
    
    var historyResult: CFTypeRef?
    let historyStatus = SecItemCopyMatching(historyQuery as CFDictionary, &historyResult)
    
    var historyDeleted = 0
    if historyStatus == errSecSuccess, let items = historyResult as? [[String: Any]] {
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String, 
               account.hasPrefix(historyPrefix + key + ":") {
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: account
                ]
                if SecItemDelete(deleteQuery as CFDictionary) == errSecSuccess {
                    historyDeleted += 1
                }
            }
        }
    }
    
    if status == errSecSuccess {
        print("Deleted key '\(key)' from Keychain")
        if historyDeleted > 0 {
            print("Also deleted \(historyDeleted) history entries")
        }
    } else {
        print("Error deleting from Keychain: \(status)")
        exit(1)
    }
}

func getHistoryForKey(_ key: String) -> [String] {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecReturnAttributes as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitAll
    ]
    
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    var historyAccounts: [(account: String, date: Date)] = []
    
    if status == errSecSuccess, let items = result as? [[String: Any]] {
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               account.hasPrefix(historyPrefix + key + ":") {
                // Extract timestamp from account string
                let timestampStr = String(account.dropFirst((historyPrefix + key + ":").count))
                if let date = getDateFormatter().date(from: timestampStr) {
                    historyAccounts.append((account: account, date: date))
                }
            }
        }
    }
    
    // Sort by date descending (newest first)
    historyAccounts.sort { $0.date > $1.date }
    
    return historyAccounts.map { $0.account }
}

func showHistory(key: String) {
    let historyItems = getHistoryForKey(key)
    
    if historyItems.isEmpty {
        print("No history found for key '\(key)'")
    } else {
        print("History for '\(key)':")
        for (index, account) in historyItems.enumerated() {
            let timestampStr = String(account.dropFirst((historyPrefix + key + ":").count))
            if let date = getDateFormatter().date(from: timestampStr) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                print("  \(index): \(formatter.string(from: date))")
            }
        }
        print("\nUse 'envpocket get \(key) --version <index> <output_file>' to retrieve a specific version")
    }
}

func listKeysInKeychain() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecReturnAttributes as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitAll
    ]
    
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    if status == errSecSuccess, let items = result as? [[String: Any]] {
        var keyInfo: [String: (current: Date?, historyCount: Int, filePath: String?)] = [:]
        
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String {
                if account.hasPrefix(prefix) && !account.hasPrefix(historyPrefix) {
                    let key = String(account.dropFirst(prefix.count))
                    // Try to extract date from comment
                    var modDate: Date? = nil
                    if let comment = item[kSecAttrComment as String] as? String,
                       comment.hasPrefix("Last modified: ") {
                        let dateStr = String(comment.dropFirst("Last modified: ".count))
                        modDate = getDateFormatter().date(from: dateStr)
                    }
                    
                    // Extract file path from label
                    let filePath = item[kSecAttrLabel as String] as? String
                    
                    if keyInfo[key] == nil {
                        keyInfo[key] = (current: modDate, historyCount: 0, filePath: filePath)
                    } else {
                        keyInfo[key]?.current = modDate
                        keyInfo[key]?.filePath = filePath
                    }
                } else if account.hasPrefix(historyPrefix) {
                    // Extract key from history entry
                    let withoutPrefix = String(account.dropFirst(historyPrefix.count))
                    if let colonIndex = withoutPrefix.firstIndex(of: ":") {
                        let key = String(withoutPrefix[..<colonIndex])
                        if keyInfo[key] == nil {
                            keyInfo[key] = (current: nil, historyCount: 1, filePath: nil)
                        } else {
                            keyInfo[key]?.historyCount += 1
                        }
                    }
                }
            }
        }
        
        if keyInfo.isEmpty {
            print("No envpocket entries found.")
        } else {
            print("EnvPocket entries:")
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            for (key, info) in keyInfo.sorted(by: { $0.key < $1.key }) {
                var line = "  • \(key)"
                
                // Add file path if available
                if let filePath = info.filePath {
                    // Decode URL encoding and show a more readable path
                    let decodedPath = filePath.removingPercentEncoding ?? filePath
                    line += " (\(decodedPath))"
                }
                
                if let modDate = info.current {
                    line += " [modified: \(formatter.string(from: modDate))]"
                }
                
                if info.historyCount > 0 {
                    line += " [\(info.historyCount) version\(info.historyCount == 1 ? "" : "s") in history]"
                }
                
                print(line)
            }
            print("\nUse 'envpocket history <key>' to see version history")
        }
    } else if status == errSecItemNotFound {
        print("No envpocket entries found.")
    } else {
        print("Error listing Keychain items: \(status)")
        exit(1)
    }
}

func main() {
    let args = CommandLine.arguments
    guard args.count >= 2, let command = Command(rawValue: args[1]) else {
        usage()
        exit(1)
    }
    
    switch command {
    case .save:
        guard args.count == 4 else { usage(); exit(1) }
        saveFileToKeychain(key: args[2], filePath: args[3])
        
    case .get:
        if args.count == 3 {
            // Get with default output: envpocket get <key>
            getFileFromKeychain(key: args[2])
        } else if args.count == 4 {
            // Get with specified output: envpocket get <key> <output_file>
            getFileFromKeychain(key: args[2], outputPath: args[3])
        } else if args.count == 5 && args[3] == "--version" {
            // Get version with default output: envpocket get <key> --version <index>
            if let versionIndex = Int(args[4]) {
                getFileFromKeychain(key: args[2], versionIndex: versionIndex)
            } else {
                print("Error: Invalid version index")
                exit(1)
            }
        } else if args.count == 6 && args[3] == "--version" {
            // Get version with specified output: envpocket get <key> --version <index> <output_file>
            if let versionIndex = Int(args[4]) {
                getFileFromKeychain(key: args[2], outputPath: args[5], versionIndex: versionIndex)
            } else {
                print("Error: Invalid version index")
                exit(1)
            }
        } else {
            usage()
            exit(1)
        }
        
    case .delete:
        guard args.count == 3 else { usage(); exit(1) }
        deleteFileFromKeychain(key: args[2])
        
    case .list:
        listKeysInKeychain()
        
    case .history:
        guard args.count == 3 else { usage(); exit(1) }
        showHistory(key: args[2])
    }
}

main()