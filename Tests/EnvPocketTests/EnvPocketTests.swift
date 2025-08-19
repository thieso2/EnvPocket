//
//  EnvPocketTests.swift
//  EnvPocketTests
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

import XCTest
import Foundation
import Security

final class EnvPocketTests: XCTestCase {
    
    // Test data - using UUID to ensure unique test keys
    let testPrefix = "test-\(UUID().uuidString.prefix(8))"
    var testKey: String { "\(testPrefix)-env-file" }
    let testContent = "TEST_VAR=value\nANOTHER_VAR=secret123\n"
    var testFilePath: String { FileManager.default.temporaryDirectory.appendingPathComponent("test-\(testPrefix).env").path }
    
    override func setUp() {
        super.setUp()
        // Create test file with unique name for this test instance
        try? testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
    }
    
    override func tearDown() {
        // Clean up test file
        try? FileManager.default.removeItem(atPath: testFilePath)
        // Clean up any remaining test keys
        try? cleanupAllTestKeys()
        super.tearDown()
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
    
    func testSaveFile() throws {
        defer { try? cleanupTestKeys() }
        
        let result = try runEnvPocket(["save", testKey, testFilePath])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("File saved to Keychain"))
        XCTAssertTrue(result.output.contains("under key '\(testKey)'"))
    }
    
    func testSaveOverwrite() throws {
        defer { try? cleanupTestKeys() }
        
        // First save
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Wait a moment to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.1)
        
        // Second save (overwrite)
        let result = try runEnvPocket(["save", testKey, testFilePath])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("Previous version backed up to history"))
    }
    
    func testSaveNonExistentFile() throws {
        defer { try? cleanupTestKeys() }
        
        let result = try runEnvPocket(["save", testKey, "/nonexistent/file.env"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.output.contains("Error: Could not read file"))
    }
    
    // MARK: - Get/Retrieve Command Tests
    
    func testGetFile() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Get file with explicit output path
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("output-\(testPrefix).env").path
        defer { try? FileManager.default.removeItem(atPath: outputPath) }
        
        let result = try runEnvPocket(["get", testKey, outputPath])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("File retrieved and saved to"))
        
        // Verify content
        let retrievedContent = try String(contentsOfFile: outputPath)
        XCTAssertEqual(retrievedContent, testContent)
    }
    
    func testGetFileToStdout() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Get file to stdout
        let result = try runEnvPocket(["get", testKey, "-"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.output, testContent)
    }
    
    func testGetNonExistentKey() throws {
        let nonExistentKey = "\(testPrefix)-nonexistent"
        let result = try runEnvPocket(["get", nonExistentKey, "-"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.output.contains("Error retrieving from Keychain"))
    }
    
    // MARK: - Delete Command Tests
    
    func testDeleteKey() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file first
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        // Delete key
        let result = try runEnvPocket(["delete", testKey])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("Deleted key '\(testKey)' from Keychain"))
        
        // Verify key is deleted
        let getResult = try runEnvPocket(["get", testKey, "-"])
        XCTAssertEqual(getResult.exitCode, 1)
    }
    
    // MARK: - List Command Tests
    
    func testListEmpty() throws {
        defer { try? cleanupTestKeys() }
        
        let result = try runEnvPocket(["list"])
        XCTAssertEqual(result.exitCode, 0)
        // Note: May show other envpocket entries, so we just check it doesn't crash
    }
    
    func testListKeys() throws {
        defer { try? cleanupTestKeys() }
        
        let key1 = "\(testPrefix)-key-1"
        let key2 = "\(testPrefix)-key-2"
        
        // Save multiple files
        _ = try runEnvPocket(["save", key1, testFilePath])
        _ = try runEnvPocket(["save", key2, testFilePath])
        
        let result = try runEnvPocket(["list"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains(key1))
        XCTAssertTrue(result.output.contains(key2))
    }
    
    // MARK: - History Command Tests
    
    func testShowHistory() throws {
        defer { try? cleanupTestKeys() }
        
        // Save file three times to create history
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = try runEnvPocket(["save", testKey, testFilePath])
        Thread.sleep(forTimeInterval: 0.1)
        _ = try runEnvPocket(["save", testKey, testFilePath])
        
        let result = try runEnvPocket(["history", testKey])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("History for '\(testKey)'"))
        XCTAssertTrue(result.output.contains("0:"))
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testInvalidCommand() throws {
        let result = try runEnvPocket(["invalid"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.output.contains("Usage:"))
    }
    
    func testMissingArguments() throws {
        let result = try runEnvPocket(["save"])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.output.contains("Usage:"))
    }
}