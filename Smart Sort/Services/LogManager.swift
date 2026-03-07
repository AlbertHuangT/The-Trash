//
//  LogManager.swift
//  Smart Sort
//
//  Created by Albert Huang on 3/5/26.
//

import Foundation
import os

/// Log severity
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// Global log manager that writes to both os.Logger and a rolling local log file
final class LogManager: @unchecked Sendable {
    static let shared = LogManager()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.smartsort.logmanager", qos: .utility)
    private let queueKey = DispatchSpecificKey<Void>()
    private let maxFileSize: UInt64 = 2 * 1024 * 1024 // 2 MB
    private let maxAge: TimeInterval = 7 * 24 * 3600   // 7 days
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("app.log")
        self.queue.setSpecific(key: queueKey, value: ())

        // Remove logs older than 7 days on launch
        queue.async { [weak self] in
            self?.cleanupIfNeeded()
        }
    }

    // MARK: - Public API

    /// Write a single log line
    func log(_ message: String, level: LogLevel = .info, category: String = "App") {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)\n"

        // 1. Forward to the system console
        let osLog = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.Albert.Smart-Sort",
            category: category
        )
        switch level {
        case .debug:   osLog.debug("\(message, privacy: .public)")
        case .info:    osLog.info("\(message, privacy: .public)")
        case .warning: osLog.warning("\(message, privacy: .public)")
        case .error:   osLog.error("\(message, privacy: .public)")
        }

        // 2. Append to the local file
        queue.async { [weak self] in
            self?.appendToFile(line)
        }
    }

    /// Get the log file URL, or nil if the file does not exist
    func getLogFileURL() -> URL? {
        synchronizedLogAccess {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            return fileURL
        }
    }

    /// Read the raw log file data
    func getLogData() -> Data? {
        synchronizedLogAccess {
            try? Data(contentsOf: fileURL)
        }
    }

    // MARK: - Private

    private func appendToFile(_ line: String) {
        let fm = FileManager.default

        // Create the file on first write
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }

        // Truncate once the file grows too large
        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? UInt64,
           size > maxFileSize {
            truncateFile()
        }

        // Append the new line
        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }

    /// Truncate the log file, keeping the newest half from a whole-line boundary
    private func truncateFile() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let keepFrom = data.count / 2
        let trimmed = data.subdata(in: keepFrom..<data.count)
        if let newlineIndex = trimmed.firstIndex(of: UInt8(ascii: "\n")) {
            let clean = trimmed.subdata(in: trimmed.index(after: newlineIndex)..<trimmed.endIndex)
            try? clean.write(to: fileURL)
        } else {
            try? trimmed.write(to: fileURL)
        }
    }

    /// Delete the log file if it has not been modified for more than 7 days
    private func cleanupIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path),
              let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else { return }

        if Date().timeIntervalSince(modDate) > maxAge {
            try? fm.removeItem(at: fileURL)
        }
    }

    private func synchronizedLogAccess<T>(_ operation: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return operation()
        }
        return queue.sync(execute: operation)
    }
}
