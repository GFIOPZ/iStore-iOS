import Foundation
import SwiftUI
import Combine
import AudioToolbox
import UserNotifications

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

    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.istore.backgroundDownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        requestNotificationPermission()
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

        let download = ActiveDownload(
            id: appId,
            appName: appName,
            iconURL: iconURL,
            status: .downloading(progress: 0.01, bytesWritten: 0, totalBytes: 0)
        )
        activeDownloads[appId] = download
        lastNotifiedProgress[appId] = 0

        // Cache icon locally for lock screen notifications
        if let iconURL = iconURL {
            fetchAndCacheIcon(from: iconURL, for: appId)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 600
        let task = urlSession.downloadTask(with: request)
        tasksToAppIds[task.taskIdentifier] = appId
        task.resume()

        HapticFeedback.light()
        sendProgressNotification(for: appId, appName: appName, percentage: 1, bytesWritten: 0, totalBytes: 0)
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

    // MARK: - Notifications

    private func makeProgressBarString(progress: Double) -> String {
        let totalBlocks = 10
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
        content.title = "\(appName) • \(percentage)%"
        
        let bar = makeProgressBarString(progress: Double(percentage) / 100.0)
        if totalBytes > 0 {
            let writtenStr = ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            content.body = "[ \(bar) ] \(percentage)% • \(writtenStr) من \(totalStr)"
        } else {
            content.body = "[ \(bar) ] \(percentage)% • جارٍ التنزيل في الخلفية..."
        }

        if let iconPath = cachedIconPaths[appId],
           FileManager.default.fileExists(atPath: iconPath.path),
           let attachment = try? UNNotificationAttachment(identifier: "icon_\(appId)", url: iconPath, options: nil) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "dl_\(appId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func sendCompletionNotification(for appId: String, appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "✅ اكتمل التحميل • \(appName)"
        content.body = "اكتمل التحميل! جارٍ تجهيز رسالة التثبيت..."
        content.sound = .default

        if let iconPath = cachedIconPaths[appId],
           FileManager.default.fileExists(atPath: iconPath.path),
           let attachment = try? UNNotificationAttachment(identifier: "icon_\(appId)", url: iconPath, options: nil) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "dl_\(appId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0.0

        let percentage = Int(progress * 100)

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId],
                  var item = self.activeDownloads[appId] else { return }

            item.status = .downloading(
                progress: max(0.01, min(progress, 0.99)),
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
            self.activeDownloads[appId] = item

            let last = self.lastNotifiedProgress[appId] ?? 0
            if percentage >= last + 5 || (percentage > 0 && last == 0) {
                self.lastNotifiedProgress[appId] = percentage
                self.sendProgressNotification(
                    for: appId,
                    appName: item.appName,
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

        // Synchronously save the temporary file before exiting this delegate method
        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let stagingFileName = "staging_\(taskId)_\(UUID().uuidString.prefix(6)).ipa"
        let stagingURL = downloadsDir.appendingPathComponent(stagingFileName)

        var copyError: Error?
        do {
            if FileManager.default.fileExists(atPath: stagingURL.path) {
                try FileManager.default.removeItem(at: stagingURL)
            }
            try FileManager.default.copyItem(at: location, to: stagingURL)
        } catch {
            copyError = error
        }

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId] else { return }
            let item = self.activeDownloads[appId]
            let appName = item?.appName ?? "App"

            if let copyError = copyError {
                self.activeDownloads[appId]?.status = .failed("تعذر حفظ الملف: \(copyError.localizedDescription)")
                self.completionHandlers[appId]?(.failure(copyError))
                return
            }

            let safeName = appName
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
            let destURL = downloadsDir.appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(4)).ipa")

            let finalURL: URL
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: stagingURL, to: destURL)
                finalURL = destURL
            } catch {
                finalURL = stagingURL
            }

            self.activeDownloads[appId]?.status = .completed(fileURL: finalURL)
            self.latestCompletedFile = finalURL
            self.completionHandlers[appId]?(.success(finalURL))
            
            HapticFeedback.success()
            self.sendCompletionNotification(for: appId, appName: appName)

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
