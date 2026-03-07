//
//  BugReportService.swift
//  Smart Sort
//
//  Created by Albert Huang on 3/5/26.
//

import Foundation
import UIKit
import Supabase

/// Record inserted into the `bug_reports` table
struct BugReportRecord: Encodable {
    let user_id: UUID
    let title: String
    let description: String
    let log_path: String?
    let device_info: DeviceInfo
    let app_version: String
}

/// Device information stored as JSONB
struct DeviceInfo: Encodable {
    let model: String
    let system_name: String
    let system_version: String
}

@MainActor
class BugReportService {
    static let shared = BugReportService()

    private let client = SupabaseManager.shared.client

    private init() {}

    private func insertRecord(
        _ record: BugReportRecord,
        logPath: String?
    ) async throws {
        do {
            try await client
                .from("bug_reports")
                .insert(record)
                .execute()
        } catch {
            LogManager.shared.log(
                "Bug report insert failed: \(error)",
                level: .error,
                category: "BugReport"
            )
            if let logPath {
                do {
                    _ = try await client.storage
                        .from("bug-report-logs")
                        .remove(paths: [logPath])
                } catch {
                    LogManager.shared.log(
                        "Failed to clean up orphaned bug report log \(logPath): \(error)",
                        level: .warning,
                        category: "BugReport"
                    )
                }
            }
            throw error
        }

        LogManager.shared.log("Bug report submitted successfully", level: .info, category: "BugReport")
    }
    
    /// Submit a bug report with an optional log attachment
    func submitReport(
        title: String,
        description: String,
        attachLog: Bool
    ) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw NSError(
                domain: "BugReportService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }

        LogManager.shared.log("Submitting bug report: \(title)", level: .info, category: "BugReport")

        let device = UIDevice.current
        let deviceInfo = DeviceInfo(
            model: device.model,
            system_name: device.systemName,
            system_version: device.systemVersion
        )

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        var logPath: String? = nil

        if attachLog {
            guard let logData = LogManager.shared.getLogData(), !logData.isEmpty else {
                let filePath = LogManager.shared.getLogFileURL()?.path ?? "missing"
                LogManager.shared.log(
                    "No local app.log data available; continuing without attachment. log_path=\(filePath)",
                    level: .warning,
                    category: "BugReport"
                )
                logPath = nil
                let record = BugReportRecord(
                    user_id: userId,
                    title: title,
                    description: description,
                    log_path: logPath,
                    device_info: deviceInfo,
                    app_version: appVersion
                )
                try await insertRecord(record, logPath: logPath)
                return
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filePath = "\(userId.uuidString.lowercased())/\(timestamp).log"

            let fileOptions = FileOptions(
                cacheControl: "3600",
                contentType: "text/plain",
                upsert: false
            )

            do {
                _ = try await client.storage
                    .from("bug-report-logs")
                    .upload(
                        filePath,
                        data: logData,
                        options: fileOptions
                    )

                logPath = filePath
                LogManager.shared.log("Log file uploaded: \(filePath)", level: .info, category: "BugReport")
            } catch {
                LogManager.shared.log(
                    "Log upload failed; continuing without attachment: \(error)",
                    level: .warning,
                    category: "BugReport"
                )
                logPath = nil
            }
        } else {
            LogManager.shared.log(
                "Bug report submitted without log attachment by user choice",
                level: .info,
                category: "BugReport"
            )
        }

        let record = BugReportRecord(
            user_id: userId,
            title: title,
            description: description,
            log_path: logPath,
            device_info: deviceInfo,
            app_version: appVersion
        )
        try await insertRecord(record, logPath: logPath)
    }
}
