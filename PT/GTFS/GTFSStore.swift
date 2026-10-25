//
//  GTFSStore.swift
//  PT
//
//  Created by Kevin Chen on 25/10/2026.
//

import Foundation

nonisolated enum GTFSStoreError: Error {
    case missingBundledDatabase
}

/// Keeps a writable copy of the bundled database in Application Support and
/// hands back its path. The app bundle is read-only, so opening the database
/// from there is what causes problems like SQLite error 14.
nonisolated enum GTFSStore {
    private static let fileName = "gtfs.sqlite"
    private static let fingerprintKey = "gtfs.installedFingerprint"

    /// Path of the database in Application Support. Copies it from the app
    /// bundle on first launch, and again whenever the bundled file changes
    /// (new app version, or you rebuilt with a new gtfs.sqlite).
    static func installedDatabasePath() throws -> String {
        let fm = FileManager.default

        guard let bundled = Bundle.main.url(forResource: "gtfs", withExtension: "sqlite") else {
            throw GTFSStoreError.missingBundledDatabase
        }

        let supportDir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true  // Application Support doesn't exist until you create it
        )
        let destination = supportDir.appendingPathComponent(fileName)

        // Identify the bundled file by size + modification date.
        let attrs = try fm.attributesOfItem(atPath: bundled.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let fingerprint = "\(size)-\(modified)"

        let defaults = UserDefaults.standard
        if fm.fileExists(atPath: destination.path),
           defaults.string(forKey: fingerprintKey) == fingerprint {
            return destination.path  // already up to date
        }

        // Copy to a temporary name first so a crash mid-copy can't leave a
        // half-written database at the real path.
        let temp = supportDir.appendingPathComponent(fileName + ".tmp")
        try? fm.removeItem(at: temp)
        try fm.copyItem(at: bundled, to: temp)
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: temp.path)

        // Remove leftovers from a previous copy before swapping in the new one.
        for suffix in ["-wal", "-shm"] {
            try? fm.removeItem(atPath: destination.path + suffix)
        }

        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: temp)
        } else {
            try fm.moveItem(at: temp, to: destination)
        }

        // It can be regenerated from the bundle, so keep it out of backups.
        var dest = destination
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dest.setResourceValues(values)

        defaults.set(fingerprint, forKey: fingerprintKey)
        return destination.path
    }
}
