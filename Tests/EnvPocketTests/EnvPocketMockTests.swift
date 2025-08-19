//
//  EnvPocketMockTests.swift
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
@testable import EnvPocket

final class EnvPocketMockTests: XCTestCase {
    
    var mockKeychain: MockKeychain!
    var envPocket: EnvPocket!
    let testContent = "TEST_VAR=value\nANOTHER_VAR=secret123\n"
    var testFilePath: String!
    
    override func setUp() {
        super.setUp()
        
        // Create mock keychain and EnvPocket instance
        mockKeychain = MockKeychain()
        envPocket = EnvPocket(keychain: mockKeychain)
        
        // Create test file
        let tempDir = FileManager.default.temporaryDirectory
        testFilePath = tempDir.appendingPathComponent("test-\(UUID().uuidString).env").path
        try? testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
    }
    
    override func tearDown() {
        // Clean up test file
        try? FileManager.default.removeItem(atPath: testFilePath)
        
        // Clear mock keychain
        mockKeychain.clear()
        
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func testSaveFile() {
        let result = envPocket.saveFile(key: "test-key", filePath: testFilePath)
        XCTAssertTrue(result)
        
        // Verify the file was saved to mock keychain
        let (data, _, status) = mockKeychain.load(account: "envpocket:test-key")
        XCTAssertEqual(status, errSecSuccess)
        XCTAssertNotNil(data)
        XCTAssertEqual(String(data: data!, encoding: .utf8), testContent)
    }
    
    func testSaveOverwriteCreatesHistory() {
        // First save
        _ = envPocket.saveFile(key: "test-key", filePath: testFilePath)
        
        // Modify file
        let newContent = "UPDATED=true\n"
        try? newContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        // Second save (should create history)
        Thread.sleep(forTimeInterval: 0.1) // Ensure different timestamp
        let result = envPocket.saveFile(key: "test-key", filePath: testFilePath)
        XCTAssertTrue(result)
        
        // Check that history was created
        let (items, _) = mockKeychain.list()
        let historyItems = items.filter { item in
            if let account = item[kSecAttrAccount as String] as? String {
                return account.hasPrefix("envpocket-history:test-key:")
            }
            return false
        }
        XCTAssertEqual(historyItems.count, 1)
    }
    
    // MARK: - Get Tests
    
    func testGetFile() {
        // Save file first
        _ = envPocket.saveFile(key: "test-key", filePath: testFilePath)
        
        // Get file to new location
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("output-\(UUID().uuidString).env").path
        defer { try? FileManager.default.removeItem(atPath: outputPath) }
        
        let result = envPocket.getFile(key: "test-key", outputPath: outputPath)
        XCTAssertTrue(result)
        
        // Verify content
        let retrievedContent = try? String(contentsOfFile: outputPath)
        XCTAssertEqual(retrievedContent, testContent)
    }
    
    func testGetNonExistentKey() {
        let result = envPocket.getFile(key: "nonexistent", outputPath: "-")
        XCTAssertFalse(result)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteSingleKey() {
        // Save file first
        _ = envPocket.saveFile(key: "test-key", filePath: testFilePath)
        
        // Delete with force (to skip confirmation)
        let result = envPocket.deleteFile(key: "test-key", force: true)
        XCTAssertTrue(result)
        
        // Verify deletion
        let (_, _, status) = mockKeychain.load(account: "envpocket:test-key")
        XCTAssertEqual(status, errSecItemNotFound)
    }
    
    func testDeleteWithWildcard() {
        // Save multiple files
        _ = envPocket.saveFile(key: "test-1", filePath: testFilePath)
        _ = envPocket.saveFile(key: "test-2", filePath: testFilePath)
        _ = envPocket.saveFile(key: "prod-1", filePath: testFilePath)
        
        // Delete all test-* keys
        let result = envPocket.deleteFile(key: "test-*", force: true)
        XCTAssertTrue(result)
        
        // Verify test keys are deleted
        let (_, _, status1) = mockKeychain.load(account: "envpocket:test-1")
        XCTAssertEqual(status1, errSecItemNotFound)
        
        let (_, _, status2) = mockKeychain.load(account: "envpocket:test-2")
        XCTAssertEqual(status2, errSecItemNotFound)
        
        // Verify prod key still exists
        let (_, _, status3) = mockKeychain.load(account: "envpocket:prod-1")
        XCTAssertEqual(status3, errSecSuccess)
    }
    
    func testDeleteWithQuestionMark() {
        // Save multiple files
        _ = envPocket.saveFile(key: "test-1", filePath: testFilePath)
        _ = envPocket.saveFile(key: "test-2", filePath: testFilePath)
        _ = envPocket.saveFile(key: "test-10", filePath: testFilePath)
        
        // Delete test-? (single character wildcard)
        let result = envPocket.deleteFile(key: "test-?", force: true)
        XCTAssertTrue(result)
        
        // Verify single digit keys are deleted
        let (_, _, status1) = mockKeychain.load(account: "envpocket:test-1")
        XCTAssertEqual(status1, errSecItemNotFound)
        
        let (_, _, status2) = mockKeychain.load(account: "envpocket:test-2")
        XCTAssertEqual(status2, errSecItemNotFound)
        
        // Verify double digit key still exists
        let (_, _, status3) = mockKeychain.load(account: "envpocket:test-10")
        XCTAssertEqual(status3, errSecSuccess)
    }
    
    // MARK: - List Tests
    
    func testListKeys() {
        // Save multiple files
        _ = envPocket.saveFile(key: "key-1", filePath: testFilePath)
        _ = envPocket.saveFile(key: "key-2", filePath: testFilePath)
        
        // Capture output (this is tricky with print statements)
        // For now, just verify the keychain contains the expected items
        let (items, _) = mockKeychain.list()
        let currentKeys = items.filter { item in
            if let account = item[kSecAttrAccount as String] as? String {
                return account.hasPrefix("envpocket:") && !account.hasPrefix("envpocket-history:")
            }
            return false
        }
        XCTAssertEqual(currentKeys.count, 2)
    }
    
    // MARK: - Pattern Matching Tests
    
    func testMatchKeysWithAsterisk() {
        _ = envPocket.saveFile(key: "dev-api", filePath: testFilePath)
        _ = envPocket.saveFile(key: "dev-web", filePath: testFilePath)
        _ = envPocket.saveFile(key: "prod-api", filePath: testFilePath)
        
        let matches = envPocket.matchKeys(pattern: "dev-*")
        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches.contains("dev-api"))
        XCTAssertTrue(matches.contains("dev-web"))
        XCTAssertFalse(matches.contains("prod-api"))
    }
    
    func testMatchKeysWithQuestionMark() {
        _ = envPocket.saveFile(key: "v1", filePath: testFilePath)
        _ = envPocket.saveFile(key: "v2", filePath: testFilePath)
        _ = envPocket.saveFile(key: "v10", filePath: testFilePath)
        
        let matches = envPocket.matchKeys(pattern: "v?")
        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches.contains("v1"))
        XCTAssertTrue(matches.contains("v2"))
        XCTAssertFalse(matches.contains("v10"))
    }
    
    func testMatchKeysWithComplexPattern() {
        _ = envPocket.saveFile(key: "app-dev-1", filePath: testFilePath)
        _ = envPocket.saveFile(key: "app-dev-2", filePath: testFilePath)
        _ = envPocket.saveFile(key: "app-prod-1", filePath: testFilePath)
        _ = envPocket.saveFile(key: "db-dev-1", filePath: testFilePath)
        
        let matches = envPocket.matchKeys(pattern: "app-*-?")
        XCTAssertEqual(matches.count, 3)
        XCTAssertTrue(matches.contains("app-dev-1"))
        XCTAssertTrue(matches.contains("app-dev-2"))
        XCTAssertTrue(matches.contains("app-prod-1"))
        XCTAssertFalse(matches.contains("db-dev-1"))
    }
}