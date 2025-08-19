//
//  main.swift
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

enum Command: String {
    case save, get, delete, list, history
}

func usage() {
    print("""
    Usage:
      envpocket save <key> <file>
      envpocket get <key> [<output_file>]
      envpocket get <key> --version <version_index> [<output_file>]
      envpocket delete <key> [-f]
      envpocket delete <pattern> [-f]
      envpocket list
      envpocket history <key>
    
    Notes:
      - For 'delete': supports wildcards (* and ?). Use -f to skip confirmation
      - For 'get': if output_file is omitted, uses the original filename
      - Use '-' as output_file to write to stdout
    """)
}

func main() {
    let args = CommandLine.arguments
    guard args.count >= 2, let command = Command(rawValue: args[1]) else {
        usage()
        exit(1)
    }
    
    let envPocket = EnvPocket()
    
    switch command {
    case .save:
        guard args.count == 4 else { usage(); exit(1) }
        if !envPocket.saveFile(key: args[2], filePath: args[3]) {
            exit(1)
        }
        
    case .get:
        if args.count == 3 {
            // Get with default output: envpocket get <key>
            if !envPocket.getFile(key: args[2]) {
                exit(1)
            }
        } else if args.count == 4 {
            // Get with specified output: envpocket get <key> <output_file>
            if !envPocket.getFile(key: args[2], outputPath: args[3]) {
                exit(1)
            }
        } else if args.count == 5 && args[3] == "--version" {
            // Get version with default output: envpocket get <key> --version <index>
            if let versionIndex = Int(args[4]) {
                if !envPocket.getFile(key: args[2], versionIndex: versionIndex) {
                    exit(1)
                }
            } else {
                print("Error: Invalid version index")
                exit(1)
            }
        } else if args.count == 6 && args[3] == "--version" {
            // Get version with specified output: envpocket get <key> --version <index> <output_file>
            if let versionIndex = Int(args[4]) {
                if !envPocket.getFile(key: args[2], outputPath: args[5], versionIndex: versionIndex) {
                    exit(1)
                }
            } else {
                print("Error: Invalid version index")
                exit(1)
            }
        } else {
            usage()
            exit(1)
        }
        
    case .delete:
        if args.count == 3 {
            // Delete without force: envpocket delete <key>
            if !envPocket.deleteFile(key: args[2], force: false) {
                exit(1)
            }
        } else if args.count == 4 && args[3] == "-f" {
            // Delete with force: envpocket delete <key> -f
            if !envPocket.deleteFile(key: args[2], force: true) {
                exit(1)
            }
        } else if args.count == 4 && args[2] == "-f" {
            // Alternative syntax: envpocket delete -f <key>
            if !envPocket.deleteFile(key: args[3], force: true) {
                exit(1)
            }
        } else {
            usage()
            exit(1)
        }
        
    case .list:
        envPocket.listKeys()
        
    case .history:
        guard args.count == 3 else { usage(); exit(1) }
        envPocket.showHistory(key: args[2])
    }
}

main()