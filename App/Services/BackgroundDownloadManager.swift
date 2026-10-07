import Foundation
import SwiftUI
import Combine
import AudioToolbox
import UserNotifications
import UIKit

public enum DownloadStatus: Equatable, Sendable {
    case queued
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case completed(fileURL: URL)
    case failed(String)
}

public struct ActiveDownload: Identifiable, Sendable {
    public let id: String
    public let appName: String
    public let iconURL: URL?
    public var status: DownloadStatus
    public var progress: Double {
        switch status {
        case .downloading(let p, _, _): return p
        case .completed: return 1.0
        default: return 0.0
        }
    }
}

@MainActor
public final class BackgroundDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = BackgroundDownloadManager()

    @Published public private(set) var activeDownloads: [String: ActiveDownload] = [:]
    @Published public var latestCompletedFile: URL?

    private var urlSession: URLSession!
    private var tasksToAppIds: [Int: String] = [:]
    private var completionHandlers: [String: (Result<URL, Error>) -> Void] = [:]
    private var lastNotifiedProgress: [String: Int] = [:]
    private var cachedIconPaths: [String: URL] = [:]
    private var backgroundTaskIDs: [String: UIBackgroundTaskIdentifier] = [:]

    override private init() {
        super.init()
        
        // Ensure downloads directory exists immediately
        _ = ensureDownloadsDirectoryExists()

        // Use standard default session with extended timeout to prevent nsurlsessiond -3000 sandbox issues
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 3600
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        requestNotificationPermission()
    }

    private func ensureDownloadsDirectoryExists() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    public func startDownload(
        url: URL,
        appId: String,
        appName: String,
        iconURL: URL? = nil,
        completion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        requestNotificationPermission()
        cancelDownload(appId: appId)

        if let completion = completion {
            completionHandlers[appId] = completion
        }

        // Begin background task to keep process running if user exits app
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "iStore_dl_\(appId)") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTask(for: appId)
            }
        }
        backgroundTaskIDs[appId] = bgTask

        let download = ActiveDownload(
            id: appId,
            appName: appName,
            iconURL: iconURL,
            status: .downloading(progress: 0.01, bytesWritten: 0, totalBytes: 0)
        )
        activeDownloads[appId] = download
        lastNotifiedProgress[appId] = 0

        // Ensure downloads directory is ready
        _ = ensureDownloadsDirectoryExists()

        // Cache icon locally for lock screen notifications
        if let iconURL = iconURL {
            fetchAndCacheIcon(from: iconURL, for: appId)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1200
        let task = urlSession.downloadTask(with: request)
        tasksToAppIds[task.taskIdentifier] = appId
        task.resume()

        HapticFeedback.light()
        sendProgressNotification(for: appId, appName: appName, percentage: 1, bytesWritten: 0, totalBytes: 0)
    }

    private func endBackgroundTask(for appId: String) {
        if let bgTask = backgroundTaskIDs.removeValue(forKey: appId), bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
        }
    }

    public func cancelDownload(appId: String) {
        for (taskId, id) in tasksToAppIds where id == appId {
            urlSession.getAllTasks { tasks in
                tasks.first(where: { $0.taskIdentifier == taskId })?.cancel()
            }
            tasksToAppIds.removeValue(forKey: taskId)
        }
        activeDownloads.removeValue(forKey: appId)
        completionHandlers.removeValue(forKey: appId)
        lastNotifiedProgress.removeValue(forKey: appId)
        endBackgroundTask(for: appId)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["dl_\(appId)"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dl_\(appId)"])
    }

    private func fetchAndCacheIcon(from url: URL, for appId: String) {
        Task.detached(priority: .background) {
            guard let data = try? Data(contentsOf: url) else { return }
            let tempDir = FileManager.default.temporaryDirectory
            let iconFile = tempDir.appendingPathComponent("icon_\(appId).png")
            try? data.write(to: iconFile, options: .atomic)
            await MainActor.run {
                BackgroundDownloadManager.shared.cachedIconPaths[appId] = iconFile
            }
        }
    }

    private func getOrCacheStoreLogo() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let logoFile = tempDir.appendingPathComponent("nova_store_logo.png")
        if FileManager.default.fileExists(atPath: logoFile.path) {
            return logoFile
        }
        if let image = UIImage(named: "NOVAStoreLogo") ?? UIImage(named: "AppIcon") {
            if let data = image.pngData() {
                try? data.write(to: logoFile, options: .atomic)
                return logoFile
            }
        }
        return nil
    }

    // MARK: - Notifications

    private func makeProgressBarString(progress: Double) -> String {
        let totalBlocks = 12
        let filled = max(0, min(totalBlocks, Int(progress * Double(totalBlocks))))
        let empty = totalBlocks - filled
        return String(repeating: "▰", count: filled) + String(repeating: "▱", count: empty)
    }

    private func sendProgressNotification(
        for appId: String,
        appName: String,
        percentage: Int,
        bytesWritten: Int64,
        totalBytes: Int64
    ) {
        let content = UNMutableNotificationContent()
        content.title = appName
        content.subtitle = "NOVA STORE • جارٍ التحميل (\(percentage)%)"
        
        let bar = makeProgressBarString(progress: Double(percentage) / 100.0)
        
        if totalBytes > 0 {
            let writtenStr = ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            content.body = "\u{200E}\(bar)  \(percentage)%\nتم تحميل \(writtenStr) من \(totalStr)"
        } else {
            content.body = "\u{200E}\(bar)  \(percentage)%\nجارٍ الاتصال واستلام البيانات..."
        }

        let iconPath = cachedIconPaths[appId] ?? getOrCacheStoreLogo()
        if let iconPath = iconPath,
           FileManager.default.fileExists(atPath: iconPath.path),
           let attachment = try? UNNotificationAttachment(identifier: "icon_\(appId)_\(percentage)", url: iconPath, options: nil) {
            content.attachments = [attachment]
        }

        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "dl_\(appId)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sendCompletionNotification(for appId: String, appName: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["dl_\(appId)"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dl_\(appId)"])

        let content = UNMutableNotificationContent()
        content.title = appName
        content.subtitle = "NOVA STORE • اكتمل التحميل"
        content.body = "تم تنزيل التطبيق بنجاح وهو الآن جاهز للتوقيع والتثبيت."
        content.sound = .default

        let iconPath = cachedIconPaths[appId] ?? getOrCacheStoreLogo()
        if let iconPath = iconPath,
           FileManager.default.fileExists(atPath: iconPath.path),
           let attachment = try? UNNotificationAttachment(identifier: "icon_done_\(appId)", url: iconPath, options: nil) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "dl_done_\(appId)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - URLSessionDownloadDelegate

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId] else { return }

            let progress: Double
            if totalBytesExpectedToWrite > 0 {
                progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0.0), 1.0)
            } else {
                progress = 0.0
            }

            self.activeDownloads[appId]?.status = .downloading(
                progress: progress,
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )

            let percentage = Int(progress * 100)
            let lastNotified = self.lastNotifiedProgress[appId] ?? -1
            if percentage >= lastNotified + 5 || percentage == 100 {
                self.lastNotifiedProgress[appId] = percentage
                let appName = self.activeDownloads[appId]?.appName ?? "App"
                self.sendProgressNotification(
                    for: appId,
                    appName: appName,
                    percentage: percentage,
                    bytesWritten: totalBytesWritten,
                    totalBytes: totalBytesExpectedToWrite
                )
            }
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier

        // Prepare destination directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsDir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true, attributes: nil)

        let safeUUID = UUID().uuidString.prefix(6)
        let finalFileName = "app_\(taskId)_\(safeUUID).ipa"
        let destURL = downloadsDir.appendingPathComponent(finalFileName)

        var saveError: Error?
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }
            // First attempt: direct moveItem
            do {
                try FileManager.default.moveItem(at: location, to: destURL)
            } catch {
                // Second attempt: copyItem
                do {
                    try FileManager.default.copyItem(at: location, to: destURL)
                } catch {
                    // Third attempt: binary stream write
                    let data = try Data(contentsOf: location)
                    try data.write(to: destURL, options: .atomic)
                }
            }
        } catch {
            saveError = error
        }

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId] else { return }
            let item = self.activeDownloads[appId]
            let appName = item?.appName ?? "App"

            if let saveError = saveError {
                self.activeDownloads[appId]?.status = .failed("تعذر حفظ الملف: \(saveError.localizedDescription)")
                self.completionHandlers[appId]?(.failure(saveError))
                self.endBackgroundTask(for: appId)
                return
            }

            // Rename to clean app name if possible
            let safeName = appName
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let namedURL = downloadsDir.appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(4)).ipa")

            let finalURL: URL
            do {
                if FileManager.default.fileExists(atPath: namedURL.path) {
                    try? FileManager.default.removeItem(at: namedURL)
                }
                try FileManager.default.moveItem(at: destURL, to: namedURL)
                finalURL = namedURL
            } catch {
                finalURL = destURL
            }

            self.activeDownloads[appId]?.status = .completed(fileURL: finalURL)
            self.latestCompletedFile = finalURL
            self.completionHandlers[appId]?(.success(finalURL))
            
            HapticFeedback.success()
            self.sendCompletionNotification(for: appId, appName: appName)
            self.endBackgroundTask(for: appId)

            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                self.activeDownloads.removeValue(forKey: appId)
            }

            self.tasksToAppIds.removeValue(forKey: taskId)
            self.completionHandlers.removeValue(forKey: appId)
            self.lastNotifiedProgress.removeValue(forKey: appId)
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        let taskId = task.taskIdentifier

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId] else { return }
            self.activeDownloads[appId]?.status = .failed(error.localizedDescription)
            self.completionHandlers[appId]?(.failure(error))
            self.endBackgroundTask(for: appId)
            self.tasksToAppIds.removeValue(forKey: taskId)
            self.completionHandlers.removeValue(forKey: appId)
            self.lastNotifiedProgress.removeValue(forKey: appId)
        }
    }
}

private enum HapticFeedback {
    @MainActor static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
