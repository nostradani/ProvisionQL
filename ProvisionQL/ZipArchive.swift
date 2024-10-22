//
//  ZipArchive.swift
//  ProvisionQL
//
//  Created by Daniel Muhra on 22.10.24.
//  Copyright © 2024 Evgeny Aleksandrov. All rights reserved.
//

import Foundation
import ZIPFoundation

@objc public class ZipArchive: NSObject {
    
    let archive: Archive
    
    @objc public init(fileURL: URL) throws {
        self.archive = try Archive(url: fileURL, accessMode: .read)
    }
    
    @discardableResult
    @objc public func unzipFile(pattern: String, to targetDir: URL) -> Bool {
        guard let entry = self.findEntry(forPattern: pattern) else {
            return false
        }
        
        guard let _ = try? self.archive.extract(entry, to: targetDir, skipCRC32: true) else {
            return false
        }
        
        return true
    }
    
    @objc public func unzipFile(pattern: String) -> Data? {
        guard let entry = self.findEntry(forPattern: pattern) else {
            return nil
        }
        
        var result = Data()
        do {
            // Extract the entry, appending data to result
            _ = try self.archive.extract(entry) { data in
                result.append(data) // Append each chunk of data
            }
        } catch {
            return nil
        }
        
        return result
    }
    
    private func findEntry(forPattern pattern: String) -> Entry? {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
        
        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$") else {
            return nil
        }
        
        // Search for the first entry that fully matches the regex pattern
        return archive.first(where: { entry in
            let path = entry.path as NSString
            let range = NSRange(location: 0, length: path.length)
            return regex.firstMatch(in: entry.path, options: [], range: range) != nil
        })
    }
}
