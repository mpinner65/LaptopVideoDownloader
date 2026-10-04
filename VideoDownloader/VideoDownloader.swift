import Foundation
import Combine

@MainActor
final class VideoDownloader:
    ObservableObject {

    // MARK: - Download State

    @Published var isDownloading =
        false

    @Published var progress:
        Double = 0

    @Published var status =
        "Ready"

    @Published var output =
        ""

    // MARK: - Metadata State

    @Published var metadata:
        VideoMetadata?

    @Published var isLoadingMetadata =
        false

    @Published var metadataError:
        String?

    // MARK: - Completed Download

    @Published private(set)
    var completedHistoryItem:
        DownloadHistoryItem?

    // MARK: - Process

    private var process:
        Process?

    private var cancellationRequested =
        false

    private var metadataRequestID = UUID()
    private var metadataSourceURL: String?

    func clearMetadata() {
        metadataRequestID = UUID()
        metadataSourceURL = nil
        metadata = nil
        metadataError = nil
        isLoadingMetadata = false
    }

    // MARK: - Tool Paths

    private var ytDLPPath: String? {

        ToolManager.findExecutable(
            named: "yt-dlp"
        )
    }

    private var ffmpegPath: String? {

        ToolManager.findExecutable(
            named: "ffmpeg"
        )
    }

    // MARK: - Load Metadata

    func loadMetadata(
        for url: String
    ) {
        clearMetadata()
        let requestID = metadataRequestID

        let trimmedURL =
            url.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedURL.isEmpty else {

            metadata = nil
            metadataError = nil
            isLoadingMetadata = false

            return
        }

        guard
            isValidURL(
                trimmedURL
            )
        else {

            metadata = nil
            metadataError =
                "Enter a valid video URL."

            isLoadingMetadata =
                false

            return
        }

        guard
            let executablePath =
                ytDLPPath
        else {

            metadata = nil

            metadataError =
                """
                yt-dlp could not be found.

                Install it with Homebrew or add it to the app's Tools folder.
                """

            isLoadingMetadata =
                false

            return
        }

        metadata = nil
        metadataError = nil
        isLoadingMetadata = true

        Task.detached {

            let result =
                Self.fetchMetadataData(
                    url: trimmedURL,
                    executablePath:
                        executablePath
                )

            await MainActor.run {
                guard self.metadataRequestID == requestID else { return }

                self.isLoadingMetadata =
                    false

                switch result {

                case .success(
                    let data
                ):

                    do {

                        let decoded =
                            try JSONDecoder()
                                .decode(
                                    VideoMetadata.self,
                                    from: data
                                )

                        self.metadata = decoded
                        self.metadataSourceURL = trimmedURL

                        self.metadataError =
                            nil

                    } catch {

                        self.metadata =
                            nil

                        self.metadataError =
                            "Could not read video information."
                    }

                case .failure(
                    let message
                ):

                    self.metadata =
                        nil

                    self.metadataError =
                        message
                }
            }
        }
    }

    // MARK: - Fetch Metadata

    nonisolated
    private static func fetchMetadataData(
        url: String,
        executablePath: String
    ) -> MetadataDataResult {

        guard
            FileManager.default
                .isExecutableFile(
                    atPath:
                        executablePath
                )
        else {

            return .failure(
                "yt-dlp exists but is not executable."
            )
        }

        let process =
            Process()

        let outputPipe =
            Pipe()

        // A file keeps verbose stderr from filling a pipe while stdout is read.
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoDownloader-metadata-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: errorURL.path, contents: nil),
              let errorHandle = try? FileHandle(forWritingTo: errorURL) else {
            return .failure("Could not create a temporary metadata log.")
        }
        defer {
            try? errorHandle.close()
            try? FileManager.default.removeItem(at: errorURL)
        }

        process.executableURL =
            URL(
                fileURLWithPath:
                    executablePath
            )

        process.arguments = [
            "--ignore-config",
            "--dump-single-json",
            "--no-playlist",
            "--",
            url
        ]

        process.standardOutput =
            outputPipe

        process.standardError = errorHandle
        process.standardInput = FileHandle.nullDevice

        do {

            try process.run()

            let outputData =
                outputPipe
                    .fileHandleForReading
                    .readDataToEndOfFile()

            process.waitUntilExit()
            let errorData = (try? Data(contentsOf: errorURL)) ?? Data()

            guard
                process
                    .terminationStatus == 0
            else {

                let errorText =
                    String(
                        data: errorData,
                        encoding: .utf8
                    )
                    ?? "Unable to read video information."

                return .failure(
                    errorText
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                )
            }

            return .success(
                outputData
            )

        } catch {

            return .failure(
                "Could not start yt-dlp: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Download

    func download(
        url: String,
        formatOption:
            VideoFormatOption,
        destination: URL
    ) {
        guard !isDownloading else { return }

        let trimmedURL =
            url.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedURL.isEmpty else {

            status =
                "Enter a video URL."

            return
        }

        guard
            isValidURL(
                trimmedURL
            )
        else {

            status =
                "Enter a valid video URL."

            return
        }

        guard
            let executablePath =
                ytDLPPath
        else {

            status =
                "yt-dlp could not be found."

            return
        }

        guard
            let ffmpegExecutablePath =
                ffmpegPath
        else {

            status =
                "FFmpeg could not be found."

            return
        }

        // yt-dlp expects either an ffmpeg binary
        // or its containing directory.
        let ffmpegDirectory =
            URL(
                fileURLWithPath:
                    ffmpegExecutablePath
            )
            .deletingLastPathComponent()
            .path

        // MARK: Reset State

        cancellationRequested =
            false

        completedHistoryItem =
            nil

        isDownloading =
            true

        progress =
            0

        status =
            "Starting download…"

        output =
            ""

        // Capture actor-isolated values before
        // entering Task.detached.

        let format =
            formatOption.ytDLPFormat

        let formatTitle =
            formatOption.title

        let isMP4 = formatOption == .mp4

        let isAudioOnly =
            formatOption.isAudioOnly

        let videoTitle =
            (metadataSourceURL == trimmedURL ? metadata?.title : nil)
            ?? "Downloaded Video"

        let thumbnail =
            metadataSourceURL == trimmedURL ? metadata?.thumbnail : nil

        let destinationPath =
            destination
                .appendingPathComponent(
                    "%(title)s.%(ext)s"
                )
                .path

        // yt-dlp writes the final merged
        // filepath into this temporary file.

        let finalPathFile =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "VideoDownloader-\(UUID().uuidString).txt"
                )

        let finalPathFilePath =
            finalPathFile.path

        Task.detached {
            [weak self] in

            guard let self else {
                return
            }

            let process =
                Process()

            let pipe =
                Pipe()

            process.executableURL =
                URL(
                    fileURLWithPath:
                        executablePath
                )

            var arguments = [

                "--ignore-config",

                "--newline",

                "--progress",

                "--no-playlist",

                "--ffmpeg-location",
                ffmpegDirectory,

                "--print-to-file",
                "after_move:filepath",
                finalPathFilePath,

                "-f",
                format,

                "-o",
                destinationPath
            ]

            if isAudioOnly {

                arguments += [
                    "-x",
                    "--audio-format",
                    "mp3"
                ]

            } else {

                arguments += [
                    "--merge-output-format",
                    "mp4"
                ]
            }

            if isMP4 {
                arguments += ["--recode-video", "mp4"]
            }

            arguments += ["--", trimmedURL]

            process.arguments =
                arguments

            process.standardOutput =
                pipe

            process.standardError =
                pipe

            process.standardInput = FileHandle.nullDevice

            do {
                // Start and register on the same actor as cancel(), so an early
                // cancellation cannot slip between registration and launch.
                let started = try await MainActor.run {
                    guard !self.cancellationRequested else {
                        self.isDownloading = false
                        self.status = "Download cancelled"
                        return false
                    }
                    try process.run()
                    self.process = process
                    return true
                }
                guard started else { return }

                // Drain output in order before reporting completion. Preserve
                // partial UTF-8 and progress lines across pipe reads.
                var pending = Data()
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    pending.append(data)
                    while let newline = pending.firstIndex(of: 10) {
                        let line = String(decoding: pending[...newline], as: UTF8.self)
                        pending.removeSubrange(...newline)
                        await MainActor.run {
                            self.output += line
                            self.parseProgress(line)
                        }
                    }
                }
                if !pending.isEmpty {
                    let remainder = String(decoding: pending, as: UTF8.self)
                    await MainActor.run { self.output += remainder }
                }
                process.waitUntilExit()

                let terminationStatus =
                    process
                        .terminationStatus

                let finalFileURL =
                    Self.readFinalFileURL(
                        from:
                            finalPathFilePath
                    )

                try? FileManager.default
                    .removeItem(
                        at:
                            finalPathFile
                    )

                await MainActor.run {

                    self.process =
                        nil

                    self.isDownloading =
                        false

                    if self
                        .cancellationRequested {

                        self.status =
                            "Download cancelled"

                        self.progress =
                            0

                        return
                    }

                    if terminationStatus == 0 {

                        self.progress =
                            1

                        self.status =
                            "Download complete"

                        if let finalFileURL {

                            self.completedHistoryItem =
                                DownloadHistoryItem(
                                    title:
                                        videoTitle,

                                    thumbnailURLString:
                                        thumbnail,

                                    sourceURL:
                                        trimmedURL,

                                    filePath:
                                        finalFileURL.path,

                                    formatTitle:
                                        formatTitle
                                )
                        }

                    } else {

                        self.status =
                            "Download failed"
                    }
                }

            } catch {

                try? FileManager.default
                    .removeItem(
                        at:
                            finalPathFile
                    )

                await MainActor.run {

                    self.process =
                        nil

                    self.isDownloading =
                        false

                    if self
                        .cancellationRequested {

                        self.status =
                            "Download cancelled"

                    } else {

                        self.status =
                            "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Read Final Path

    nonisolated
    private static func readFinalFileURL(
        from path: String
    ) -> URL? {

        guard
            let contents =
                try? String(
                    contentsOfFile:
                        path,
                    encoding: .utf8
                )
        else {
            return nil
        }

        let lines =
            contents
                .components(
                    separatedBy:
                        .newlines
                )
                .map {

                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }
                .filter {

                    !$0.isEmpty
                }

        guard
            let finalPath =
                lines.last
        else {
            return nil
        }

        return URL(
            fileURLWithPath:
                finalPath
        )
    }

    // MARK: - Cancel

    func cancel() {
        guard isDownloading else { return }
        cancellationRequested = true
        if let process, process.isRunning {
            process.terminate()
        }
        // Keep the download active until the worker has actually stopped.
        status = "Cancelling…"
    }

    // MARK: - URL Validation

    private func isValidURL(
        _ value: String
    ) -> Bool {

        guard
            let url =
                URL(
                    string: value
                ),

            let scheme =
                url.scheme?
                    .lowercased(),
            let host = url.host,
            !host.isEmpty
        else {
            return false
        }

        return
            scheme == "http"
            || scheme == "https"
    }

    // MARK: - Progress

    private func parseProgress(
        _ text: String
    ) {
        guard !cancellationRequested else { return }

        let pattern =
            #"(\d+(?:\.\d+)?)%"#

        guard
            let regex =
                try? NSRegularExpression(
                    pattern: pattern
                ),

            let match =
                regex.firstMatch(
                    in: text,
                    range:
                        NSRange(
                            text.startIndex...,
                            in: text
                        )
                ),

            let range =
                Range(
                    match.range(
                        at: 1
                    ),
                    in: text
                ),

            let percentage =
                Double(
                    text[range]
                )
        else {
            return
        }

        let clamped =
            min(
                max(
                    percentage,
                    0
                ),
                100
            )

        progress =
            clamped / 100

        status =
            "Downloading… \(Int(clamped))%"
    }
}

// MARK: - Metadata Result

private enum MetadataDataResult:
    Sendable {

    case success(Data)

    case failure(String)
}
