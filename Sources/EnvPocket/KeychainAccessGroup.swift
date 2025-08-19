//
//  KeychainAccessGroup.swift
//  EnvPocket
//
//  Implements keychain access group for additional isolation
//

import Foundation
import Security

extension RealKeychain {
    // Define a unique access group for envpocket
    // This requires code signing with a Team ID
    static let accessGroup = "TEAMID.com.yourcompany.envpocket.keychain"
    
    // Add access group to all keychain queries
    func addAccessGroup(to query: inout [String: Any]) {
        #if !DEBUG
        // Only use access groups in release builds with proper signing
        if let teamID = getTeamIdentifier() {
            query[kSecAttrAccessGroup as String] = "\(teamID).com.yourcompany.envpocket.keychain"
        }
        #endif
    }
    
    private func getTeamIdentifier() -> String? {
        // Get the team identifier from the code signature
        var code: SecCode?
        if SecCodeCopySelf([], &code) == errSecSuccess,
           let code = code {
            var info: CFDictionary?
            if SecCodeCopySigningInformation(code, [], &info) == errSecSuccess,
               let info = info as? [String: Any],
               let identifier = info[kSecCodeInfoIdentifier as String] as? String {
                // Extract team ID from identifier (format: TEAMID.bundleid)
                let components = identifier.split(separator: ".")
                if components.count > 1 {
                    return String(components[0])
                }
            }
        }
        return nil
    }
}