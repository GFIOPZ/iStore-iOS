import Foundation
import SwiftUI
import Combine
import AudioToolbox

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

    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.novastore.backgroundDownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    public func startDownload(
        url: URL,
        appId: String,
        appName: String,
        iconURL: URL? = nil,
        completion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        // Cancel existing task for this app if any
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

        var request = URLRequest(url: url)
        request.timeoutInterval = 600
        let task = urlSession.downloadTask(with: request)
        tasksToAppIds[task.taskIdentifier] = appId
        task.resume()

        HapticFeedback.light()
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

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId],
                  var item = self.activeDownloads[appId] else { return }

            item.status = .downloading(
                progress: max(0.01, min(progress, 0.99)),
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
            self.activeDownloads[appId] = item
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier

        Task { @MainActor in
            guard let appId = self.tasksToAppIds[taskId] else { return }
            let item = self.activeDownloads[appId]
            let appName = item?.appName ?? "App"

            let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

            let safeName = appName.replacingOccurrences(of: " ", with: "-")
            let destURL = downloadsDir.appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(6)).ipa")

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: location, to: destURL)

                self.activeDownloads[appId]?.status = .completed(fileURL: destURL)
                self.latestCompletedFile = destURL
                self.completionHandlers[appId]?(.success(destURL))
                
                HapticFeedback.success()

                // Remove after 3 seconds from overlay
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    self.activeDownloads.removeValue(forKey: appId)
                }
            } catch {
                self.activeDownloads[appId]?.status = .failed(error.localizedDescription)
                self.completionHandlers[appId]?(.failure(error))
            }

            self.tasksToAppIds.removeValue(forKey: taskId)
            self.completionHandlers.removeValue(forKey: appId)
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
