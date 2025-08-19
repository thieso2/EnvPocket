import Testing
import Foundation
import Security

@Suite("EnvPocket Tests")
final class EnvPocketTests {
    
    // Test data - using UUID to ensure unique test keys
    let testPrefix = "test-\(UUID().uuidString.prefix(8))"
    var testKey: String { "\(testPrefix)-env-file" }
    let testContent = "TEST_VAR=value\nANOTHER_VAR=secret123\n"
    let testFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("test.env").path
    
    init() throws {
        // Create test file
        try testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
    }
    
    deinit {
        // Clean up test file
        try? FileManager.default.removeItem(atPath: testFilePath)
        // Clean up any remaining test keys
        try? cleanupAllTestKeys()
    }
    
    // MARK: - Helper Functions
    
    func runEnvPocket(_ arguments: [String]) throws -> (output: String, exitCode: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: ".build/debug/envpocket")
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return (output, task.terminationStatus)
    }
    
    func cleanupTestKeys() throws {
        // Clean up any test keys from the keychain with our test prefix
        let prefixes = ["envpocket:\(testPrefix)", "envpocket-history:\(testPrefix)"]
        
        for prefix in prefixes {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true
            ]
            
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let items = result as? [[String: Any]] {
                for item in items {
                    if let account = item[kSecAttrAccount as String] as? String,
                       account.hasPrefix(prefix) {
                        let deleteQuery: [String: Any] = [
                            kSecClass as String: kSecClassGenericPassword,
                            kSecAttrAccount as String: account
                        ]
                        SecItemDelete(deleteQuery as CFDictionary)
                    }
                }
            }
        }
    }
    
    func cleanupAllTestKeys() throws {
        // More aggressive cleanup - remove all test-prefixed keys
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String,
                   (account.contains("test-") && (account.hasPrefix("envpocket:") || account.hasPrefix("envpocket-history:"))) {
                    let deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrAccount as String: account
                    ]
                    SecItemDelete(deleteQuery as CFDictionary)
                }
            }
        }
    }
    
    // MARK: - Store/Save Command Tests
    
    @Test("Save file to keychain")
    func testSaveFile() throws {
        defer { try? cleanupTestKeys() }
        
        let result = try runEnvPocket(["save", testKey, testFilePath])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("File saved to Keychain"))
        #expect(result.output.contains("under key '\(testKey)'"))
    }
    
    @Test("Save overwrites existing key and creates history")
    func testSaveOverwrite() throws {
        defer { try? cleanupTestKeys() }
        
        // First save
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Wait a moment to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.1)
        
        // Second save (overwrite)
        let result = try runEnvPocket(["save", testKey, testFilePath])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("Previous version backed up to history"))
    }
    
    @Test("Save non-existent file fails")
    func testSaveNonExistentFile() throws {
        defer { try? cleanupTestKeys() }
        
        let result = try runEnvPocket(["save", testKey, "/nonexistent/file.env"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("Error: Could not read file"))
    }
    
    // MARK: - Get/Retrieve Command Tests
    
    @Test("Get file from keychain")
    func testGetFile() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Get file with explicit output path
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("output-\(testPrefix).env").path
        defer { try? FileManager.default.removeItem(atPath: outputPath) }
        
        let result = try runEnvPocket(["get", testKey, outputPath])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("File retrieved and saved to"))
        
        // Verify content
        let retrievedContent = try String(contentsOfFile: outputPath)
        #expect(retrievedContent == testContent)
    }
    
    @Test("Get file to stdout")
    func testGetFileToStdout() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Get file to stdout
        let result = try runEnvPocket(["get", testKey, "-"])
        #expect(result.exitCode == 0)
        #expect(result.output == testContent)
    }
    
    @Test("Get file with default output name")
    func testGetFileDefaultOutput() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Get file without specifying output (should use original filename)
        let currentDir = FileManager.default.currentDirectoryPath
        let expectedOutput = URL(fileURLWithPath: currentDir).appendingPathComponent("test.env").path
        defer { try? FileManager.default.removeItem(atPath: expectedOutput) }
        
        let result = try runEnvPocket(["get", testKey])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("test.env"))
    }
    
    @Test("Get non-existent key fails")
    func testGetNonExistentKey() throws {
        let nonExistentKey = "\(testPrefix)-nonexistent"
        let result = try runEnvPocket(["get", nonExistentKey, "-"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("Error retrieving from Keychain"))
    }
    
    @Test("Get specific version from history")
    func testGetHistoricalVersion() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file twice to create history
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        
        // Modify file content
        let modifiedContent = "MODIFIED=true\n"
        let modifiedPath = FileManager.default.temporaryDirectory.appendingPathComponent("modified-\(testPrefix).env").path
        try modifiedContent.write(toFile: modifiedPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: modifiedPath) }
        
        _ = try runEnvPocket(["save", testKey, modifiedPath])
        
        // Get historical version (index 0 = most recent history)
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("historical-\(testPrefix).env").path
        defer { try? FileManager.default.removeItem(atPath: outputPath) }
        
        let result = try runEnvPocket(["get", testKey, "--version", "0", outputPath])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("Retrieved historical version"))
        
        // Verify we got the original content
        let retrievedContent = try String(contentsOfFile: outputPath)
        #expect(retrievedContent == testContent)
    }
    
    // MARK: - Delete Command Tests
    
    @Test("Delete key from keychain")
    func testDeleteKey() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Delete key
        let result = try runEnvPocket(["delete", testKey])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("Deleted key '\(testKey)' from Keychain"))
        
        // Verify key is deleted
        let getResult = try runEnvPocket(["get", testKey, "-"])
        #expect(getResult.exitCode == 1)
    }
    
    @Test("Delete key with history")
    func testDeleteKeyWithHistory() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file twice to create history
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Delete key
        let result = try runEnvPocket(["delete", testKey])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("Also deleted 1 history"))
    }
    
    @Test("Delete non-existent key fails")
    func testDeleteNonExistentKey() throws {
        let nonExistentKey = "\(testPrefix)-nonexistent-delete"
        let result = try runEnvPocket(["delete", nonExistentKey])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("Error deleting from Keychain"))
    }
    
    // MARK: - List Command Tests
    
    @Test("List empty keychain")
    func testListEmpty() throws {
        defer { try? cleanupTestKeys() }
        
        let result = try runEnvPocket(["list"])
        #expect(result.exitCode == 0)
        // Note: May show other envpocket entries, so we just check it doesn't crash
    }
    
    @Test("List keys in keychain")
    func testListKeys() throws {
        defer { try? cleanupTestKeys() }
        
        let key1 = "\(testPrefix)-key-1"
        let key2 = "\(testPrefix)-key-2"
        
        // Save multiple files
        _ = try runEnvPocket(["save", key1, testFilePath])
        _ = try runEnvPocket(["save", key2, testFilePath])
        
        let result = try runEnvPocket(["list"])
        #expect(result.exitCode == 0)
        #expect(result.output.contains(key1))
        #expect(result.output.contains(key2))
        #expect(result.output.contains("test.env"))
    }
    
    @Test("List shows history count")
    func testListShowsHistory() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file twice to create history
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        let result = try runEnvPocket(["list"])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("1 version in history"))
    }
    
    // MARK: - History Command Tests
    
    @Test("Show history for key")
    func testShowHistory() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file three times to create history
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        let result = try runEnvPocket(["history", testKey])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("History for '\(testKey)'"))
        #expect(result.output.contains("0:"))
        #expect(result.output.contains("1:"))
    }
    
    @Test("Show history for non-existent key")
    func testShowHistoryNonExistent() throws {
        let nonExistentKey = "\(testPrefix)-nonexistent-history"
        let result = try runEnvPocket(["history", nonExistentKey])
        #expect(result.exitCode == 0)
        #expect(result.output.contains("No history found"))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Invalid command shows usage")
    func testInvalidCommand() throws {
        let result = try runEnvPocket(["invalid"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("Usage:"))
    }
    
    @Test("Missing arguments shows usage")
    func testMissingArguments() throws {
        let result = try runEnvPocket(["save"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("Usage:"))
    }
    
    @Test("Invalid version index")
    func testInvalidVersionIndex() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file once
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Try to get invalid version
        let result = try runEnvPocket(["get", testKey, "--version", "999", "-"])
        #expect(result.exitCode == 1)
        #expect(result.output.contains("Invalid version index"))
    }
    
    @Test("Handle special characters in key")
    func testSpecialCharactersInKey() throws {
        defer { try? cleanupTestKeys() }
        
        let specialKey = "\(testPrefix)-key:with@special#chars"
        let result = try runEnvPocket(["save", specialKey, testFilePath])
        #expect(result.exitCode == 0)
        
        // Verify retrieval
        let getResult = try runEnvPocket(["get", specialKey, "-"])
        #expect(getResult.exitCode == 0)
        #expect(getResult.output == testContent)
    }
    
    @Test("Handle large files")
    func testLargeFile() throws {
        defer { try? cleanupTestKeys() }
        
        let largeKey = "\(testPrefix)-large"
        
        // Create a large file (1MB)
        let largeContent = String(repeating: "A", count: 1024 * 1024)
        let largePath = FileManager.default.temporaryDirectory.appendingPathComponent("large-\(testPrefix).env").path
        try largeContent.write(toFile: largePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: largePath) }
        
        // Save large file
        let saveResult = try runEnvPocket(["save", largeKey, largePath])
        #expect(saveResult.exitCode == 0)
        
        // Retrieve large file
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("large-output-\(testPrefix).env").path
        defer { try? FileManager.default.removeItem(atPath: outputPath) }
        
        let getResult = try runEnvPocket(["get", largeKey, outputPath])
        #expect(getResult.exitCode == 0)
        
        // Verify content
        let retrievedContent = try String(contentsOfFile: outputPath)
        #expect(retrievedContent == largeContent)
    }
    
    @Test("Multiple operations")
    func testMultipleOperations() throws {
        defer { try? cleanupTestKeys() }
        
        // Save multiple keys sequentially to test isolation
        var keys: [String] = []
        for i in 0..<5 {
            let key = "\(testPrefix)-multiple-\(i)"
            keys.append(key)
            let result = try runEnvPocket(["save", key, testFilePath])
            #expect(result.exitCode == 0)
        }
        
        // Verify all keys exist
        let listResult = try runEnvPocket(["list"])
        #expect(listResult.exitCode == 0)
        
        for key in keys {
            #expect(listResult.output.contains(key))
        }
        
        // Clean up all keys
        for key in keys {
            let deleteResult = try runEnvPocket(["delete", key])
            #expect(deleteResult.exitCode == 0)
        }
    }
}

enum TestError: Error {
    case keychainCreationFailed(OSStatus)
    case commandExecutionFailed
}