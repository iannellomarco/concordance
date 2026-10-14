import CryptoKit
import Foundation
import Observation

/// Downloads EverPaper/embeddinggemma-2-coreai (text and, optionally, image encoder; never the audio encoder) into
/// Application Support, resuming across launches, and verifies every file against the repository's CHECKSUMS.sha256.
@MainActor @Observable
public final class ModelInstaller {
    public enum Phase: Equatable, Sendable {
        case idle, listing, downloading, verifying, installed
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var receivedBytes: Int64 = 0
    public private(set) var totalBytes: Int64 = 0
    public private(set) var currentFile = ""
    /// Bytes per second, smoothed.
    public private(set) var speed: Double = 0

    public static let repo = "EverPaper/embeddinggemma-2-coreai"
    public let destination: URL
    @ObservationIgnored private var lastSample: (date: Date, bytes: Int64)?

    public init(destination: URL = Paths.installedModel) {
        self.destination = destination
    }

    public var fraction: Double { totalBytes > 0 ? Double(receivedBytes) / Double(totalBytes) : 0 }

    struct RemoteFile {
        var path: String   // "model/…"
        var size: Int64
    }

    /// `only` limits the download to matching repository paths (used to test the installer on small files).
    public func install(includeVision: Bool = true, only: ((String) -> Bool)? = nil) async {
        guard phase != .downloading, phase != .verifying else { return }
        do {
            phase = .listing
            var files = try await listFiles(includeVision: includeVision)
            if let only { files = files.filter { only($0.path) } }
            totalBytes = files.reduce(0) { $0 + $1.size }
            receivedBytes = 0
            phase = .downloading

            let fm = FileManager.default
            let staging = destination.deletingLastPathComponent()
                .appendingPathComponent(destination.lastPathComponent + ".partial")
            var completed: Int64 = 0
            for file in files {
                let target = staging.appendingPathComponent(String(file.path.dropFirst("model/".count)))
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let size = (try? fm.attributesOfItem(atPath: target.path))?[.size] as? Int64, size == file.size {
                    completed += file.size   // already downloaded by an earlier launch
                    receivedBytes = completed
                    continue
                }
                currentFile = (file.path as NSString).lastPathComponent
                let base = completed
                try await FileDownload.run(from: Self.resolveURL(file.path), to: target) { [weak self] written in
                    Task { @MainActor in self?.progress(base + written) }
                }
                completed += file.size
                progress(completed)
            }

            phase = .verifying
            currentFile = ""
            let sums = try await checksums()
            for file in files {
                let target = staging.appendingPathComponent(String(file.path.dropFirst("model/".count)))
                guard let expected = sums[file.path] else { continue }
                let actual = try await Task.detached(priority: .userInitiated) { try Self.sha256(of: target) }.value
                guard actual == expected else {
                    try? fm.removeItem(at: target)
                    throw InstallError("\(file.path) is damaged (checksum mismatch); it will be downloaded again.")
                }
            }

            try? fm.removeItem(at: destination)   // a stale folder or a dangling symlink
            try fm.moveItem(at: staging, to: destination)
            phase = .installed
        } catch {
            phase = .failed((error as? InstallError)?.message ?? error.localizedDescription)
        }
    }

    private func progress(_ bytes: Int64) {
        receivedBytes = max(receivedBytes, bytes)
        let now = Date()
        if let last = lastSample, now.timeIntervalSince(last.date) >= 0.5 {
            let instant = Double(receivedBytes - last.bytes) / now.timeIntervalSince(last.date)
            speed = speed == 0 ? instant : speed * 0.7 + instant * 0.3
            lastSample = (now, receivedBytes)
        } else if lastSample == nil {
            lastSample = (now, receivedBytes)
        }
    }

    // MARK: - Hugging Face

    static func resolveURL(_ path: String) -> URL {
        URL(string: "https://huggingface.co/\(repo)/resolve/main/\(path)")!
    }

    private func listFiles(includeVision: Bool) async throws -> [RemoteFile] {
        let url = URL(string: "https://huggingface.co/api/models/\(Self.repo)/tree/main/model?recursive=true")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw InstallError("Unexpected answer from Hugging Face.")
        }
        return entries.compactMap { entry -> RemoteFile? in
            guard entry["type"] as? String == "file", let path = entry["path"] as? String,
                  !path.lowercased().contains("audio"),
                  includeVision || !path.contains("vision") else { return nil }
            let lfs = (entry["lfs"] as? [String: Any])?["size"] as? Int64
            return RemoteFile(path: path, size: lfs ?? (entry["size"] as? Int64) ?? 0)
        }
    }

    private func checksums() async throws -> [String: String] {
        let (data, _) = try await URLSession.shared.data(from: Self.resolveURL("CHECKSUMS.sha256"))
        var result: [String: String] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }
            result[parts[1].trimmingCharacters(in: .whitespaces)] = String(parts[0])
        }
        return result
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    struct InstallError: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
}

/// One URLSession download with byte progress, moved to `destination` when complete.
private final class FileDownload: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let onProgress: (Int64) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var moveError: Error?

    private init(destination: URL, onProgress: @escaping (Int64) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    static func run(from url: URL, to destination: URL, onProgress: @escaping (Int64) -> Void) async throws {
        let download = FileDownload(destination: destination, onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: download, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { continuation in
            download.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onProgress(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temporary file is deleted when this method returns, so move it now.
        if let status = (downloadTask.response as? HTTPURLResponse)?.statusCode, status != 200 {
            moveError = ModelInstaller.InstallError("Download failed (HTTP \(status)).")
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            moveError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error ?? moveError { continuation?.resume(throwing: error) } else { continuation?.resume() }
        continuation = nil
    }
}
