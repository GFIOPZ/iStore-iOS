import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

// MARK: - In-memory cache

@MainActor
private final class AppIconMemoryCache {
    static let shared = AppIconMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        // Keep frequently visible icons immediately available.
        cache.countLimit = 180
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let width = image.cgImage?.width ?? Int(image.size.width)
        let height = image.cgImage?.height ?? Int(image.size.height)
        let byteCost = max(width * height * 4, 1)

        cache.setObject(
            image,
            forKey: url as NSURL,
            cost: byteCost
        )
    }
}

// MARK: - Persistent disk cache

/// Persists processed icon thumbnails on disk.
///
/// This is the important part for tab switching: LazyVStack cells can disappear
/// when the user changes tabs, so an in-memory @State image is not enough.
/// Once an icon has successfully loaded, this cache keeps its processed PNG in
/// the app's Caches directory. Returning to the Applications tab therefore
/// restores the image locally instead of downloading it again.
///
/// The cache key includes the complete icon URL. If the admin panel changes the
/// icon URL, the new URL naturally gets a new cache entry.
private actor AppIconDiskCache {
    static let shared = AppIconDiskCache()

    private let directory: URL
    private let fileManager = FileManager.default

    private init() {
        let base = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first!

        directory = base.appendingPathComponent(
            "NOVAStoreIconCache",
            isDirectory: true
        )

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func data(for url: URL) -> Data? {
        let file = fileURL(for: url)

        guard fileManager.fileExists(atPath: file.path) else {
            return nil
        }

        return try? Data(contentsOf: file)
    }

    func insert(_ data: Data, for url: URL) {
        let file = fileURL(for: url)

        do {
            try data.write(
                to: file,
                options: [.atomic]
            )
        } catch {
            // Disk cache is optional. A write failure must never break the UI.
        }
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(
            data: Data(url.absoluteString.utf8)
        )

        let key = digest
            .map { String(format: "%02x", $0) }
            .joined()

        return directory.appendingPathComponent(
            "\(key).png",
            isDirectory: false
        )
    }
}

// MARK: - Network loader

private actor AppIconDataLoader {
    static let shared = AppIconDataLoader()

    private var inFlight: [URL: Task<Data?, Never>] = [:]
    private let maximumResponseBytes = 6 * 1_024 * 1_024

    func data(for url: URL) async -> Data? {
        if let existing = inFlight[url] {
            return await existing.value
        }

        let responseByteLimit = maximumResponseBytes

        let task: Task<Data?, Never> = Task.detached(
            priority: .utility
        ) { () -> Data? in

            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 12
            request.httpShouldHandleCookies = false

            guard
                let (bytes, response) =
                    try? await URLSession.shared.bytes(for: request),
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                httpResponse.expectedContentLength <= Int64(responseByteLimit) ||
                httpResponse.expectedContentLength == -1
            else {
                return nil
            }

            var data = Data()

            data.reserveCapacity(
                Int(
                    min(
                        max(httpResponse.expectedContentLength, 0),
                        Int64(responseByteLimit)
                    )
                )
            )

            do {
                for try await byte in bytes {
                    guard data.count < responseByteLimit else {
                        return nil
                    }

                    data.append(byte)
                }
            } catch {
                return nil
            }

            return data.isEmpty ? nil : data
        }

        inFlight[url] = task

        let result = await task.value

        inFlight[url] = nil

        return result
    }
}

// MARK: - Thumbnail processor

private enum AppIconThumbnail {
    static func data(
        from sourceData: Data,
        maximumPixelSize: Int
    ) -> Data? {

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard
            let source = CGImageSourceCreateWithData(
                sourceData as CFData,
                sourceOptions
            )
        else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]

        guard
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            )
        else {
            return nil
        }

        let output = NSMutableData()

        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            nil
        )

        return CGImageDestinationFinalize(destination)
            ? output as Data
            : nil
    }
}

// MARK: - Cached App Icon

struct CachedAppIcon: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.forgeTheme) private var T
    @State private var image: UIImage?

    init(
        url: URL?,
        size: CGFloat = 44,
        cornerRadius: CGFloat = 11
    ) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "app.fill")
                    .font(
                        .system(
                            size: size * 0.34,
                            weight: .medium
                        )
                    )
                    .foregroundColor(T.accent2)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .frame(width: size, height: size)
        .background(
            Color.white.opacity(0.055),
            in: RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.12),
                lineWidth: 0.6
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }

        // 1. RAM — instant.
        if let cached = AppIconMemoryCache.shared.image(for: url) {
            image = cached
            return
        }

        // 2. Disk — no network request after the icon has already been
        //    processed once.
        if let diskData = await AppIconDiskCache.shared.data(for: url),
           let cached = UIImage(data: diskData) {

            guard !Task.isCancelled else { return }

            AppIconMemoryCache.shared.insert(
                cached,
                for: url
            )

            image = cached
            return
        }

        // 3. Network — only for a genuinely new icon.
        guard
            !Task.isCancelled,
            let sourceData =
                await AppIconDataLoader.shared.data(for: url)
        else {
            return
        }

        let thumbnailData =
            await Task.detached(priority: .utility) {
                AppIconThumbnail.data(
                    from: sourceData,
                    maximumPixelSize: 128
                )
            }.value

        guard
            !Task.isCancelled,
            let thumbnailData,
            let decoded = UIImage(data: thumbnailData)
        else {
            return
        }

        // Save the processed thumbnail, not the original potentially huge
        // artwork. This keeps the persistent cache small and fast.
        await AppIconDiskCache.shared.insert(
            thumbnailData,
            for: url
        )

        AppIconMemoryCache.shared.insert(
            decoded,
            for: url
        )

        image = decoded
    }
}
