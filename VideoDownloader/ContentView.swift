import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {

    // MARK: - Services

    @StateObject
    private var toolManager =
        ToolManager()

    @StateObject
    private var downloader =
        VideoDownloader()

    @StateObject
    private var history =
        DownloadHistoryStore()

    // MARK: - Input

    @State
    private var videoURL =
        ""

    @State
    private var selectedFormat:
        VideoFormatOption = .best

    @State
    private var destination =
        FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first!

    // MARK: - Drag and Drop

    @State
    private var isDropTargeted =
        false

    // MARK: - Body

    var body: some View {

        ZStack {

            appBackground
                .ignoresSafeArea()

            ScrollView {

                VStack(
                    spacing: 20
                ) {

                    header

                    toolStatusCard

                    urlCard

                    metadataSection

                    downloadSettingsCard

                    progressCard

                    actionButtons

                    downloadHistorySection
                }
                .padding(28)
                .frame(
                    maxWidth: 760
                )
                .frame(
                    maxWidth: .infinity
                )
            }

            if isDropTargeted {
                dropOverlay
            }
        }
        .onDrop(
            of: [
                UTType.url.identifier,
                UTType.plainText.identifier
            ],
            isTargeted: $isDropTargeted
        ) { providers in

            handleDrop(
                providers
            )
        }
        .frame(
            minWidth: 700,
            minHeight: 650
        )

        // Check yt-dlp + ffmpeg

        .task {

            toolManager.refresh()
        }

        // Load metadata automatically

        .task(
            id: videoURL
        ) {

            let trimmed =
                videoURL
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            guard !trimmed.isEmpty else {
                return
            }

            do {

                try await Task.sleep(
                    nanoseconds:
                        600_000_000
                )

                guard !Task.isCancelled else {
                    return
                }

                downloader.loadMetadata(
                    for: trimmed
                )

            } catch {
                // URL changed before metadata loading.
            }
        }

        // Reset selected format when URL changes

        .onChange(
            of: videoURL
        ) { _, _ in
            downloader.clearMetadata()

            selectedFormat =
                .best
        }

        // Store completed download

        .onChange(
            of:
                downloader
                    .completedHistoryItem?
                    .id
        ) { _, _ in

            guard
                let item =
                    downloader
                        .completedHistoryItem
            else {
                return
            }

            history.add(
                item
            )
        }
    }

    // MARK: - Background

    private var appBackground:
        some View {

        LinearGradient(
            colors: [

                Color(
                    red: 0.035,
                    green: 0.04,
                    blue: 0.055
                ),

                Color(
                    red: 0.055,
                    green: 0.06,
                    blue: 0.08
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var header:
        some View {

        HStack(
            spacing: 14
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color.accentColor
                        .opacity(0.15)
                )
                .frame(
                    width: 58,
                    height: 58
                )

                Image(
                    systemName:
                        "arrow.down.circle.fill"
                )
                .font(
                    .system(
                        size: 31
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Video Downloader"
                )
                .font(
                    .system(
                        size: 28,
                        weight: .bold
                    )
                )

                Text(
                    "Download videos and audio to your Mac"
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
    }

    // MARK: - Tool Status

    private var toolStatusCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Label(
                    "App Status",
                    systemImage:
                        "wrench.and.screwdriver"
                )
                .font(.headline)

                Spacer()

                if toolManager
                    .status
                    .isReady {

                    Label(
                        "Ready",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .font(
                        .caption.bold()
                    )
                    .foregroundStyle(
                        .green
                    )

                } else {

                    Label(
                        "Setup Required",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .caption.bold()
                    )
                    .foregroundStyle(
                        .orange
                    )
                }
            }

            Divider()
                .opacity(0.3)

            toolRow(
                title: "yt-dlp",
                installed:
                    toolManager
                        .status
                        .hasYtDLP,
                path:
                    toolManager
                        .status
                        .ytDLPPath
            )

            toolRow(
                title: "FFmpeg",
                installed:
                    toolManager
                        .status
                        .hasFFmpeg,
                path:
                    toolManager
                        .status
                        .ffmpegPath
            )

            if !toolManager
                .status
                .isReady {

                Divider()
                    .opacity(0.3)

                HStack {

                    Image(
                        systemName:
                            "info.circle"
                    )

                    Text(
                        "Install the missing tools before downloading."
                    )

                    Spacer()

                    Button(
                        "Check Again"
                    ) {

                        toolManager
                            .refresh()
                    }
                    .buttonStyle(
                        .bordered
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .appCard()
    }

    // MARK: - Tool Row

    private func toolRow(
        title: String,
        installed: Bool,
        path: String?
    ) -> some View {

        HStack(spacing: 10) {

            Image(
                systemName:
                    installed
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
            )
            .foregroundColor(
                installed
                ? Color.green
                : Color.red
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(title)
                    .font(
                        .subheadline.weight(
                            .medium
                        )
                    )

                if let path {

                    Text(path)
                        .font(.caption2)
                        .foregroundColor(
                            Color.secondary
                        )
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            Text(
                installed
                ? "Installed"
                : "Not Installed"
            )
            .font(.caption)
            .foregroundColor(
                installed
                ? Color.secondary
                : Color.red
            )
        }
    }
    
    // MARK: - URL Card

    private var urlCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                "Video URL",
                systemImage: "link"
            )
            .font(.headline)

            HStack(
                spacing: 10
            ) {

                TextField(
                    "Paste or drop a video URL…",
                    text: $videoURL
                )
                .textFieldStyle(
                    .plain
                )
                .font(
                    .system(
                        size: 15
                    )
                )
                .padding(
                    .horizontal,
                    14
                )
                .frame(
                    height: 44
                )
                .background(

                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        Color.white
                            .opacity(
                                0.055
                            )
                    )
                )
                .overlay(

                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .stroke(
                        Color.white
                            .opacity(
                                0.08
                            )
                    )
                )
                .onSubmit {

                    downloader
                        .loadMetadata(
                            for: videoURL
                        )
                }

                Button {

                    pasteURL()

                } label: {

                    Label(
                        "Paste",
                        systemImage:
                            "doc.on.clipboard"
                    )
                }
                .buttonStyle(
                    .bordered
                )
            }

            Text(
                "You can also drag a link from your browser onto this window."
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
        .appCard()
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection:
        some View {

        if downloader
            .isLoadingMetadata {

            loadingMetadataCard

        } else if
            let metadata =
                downloader.metadata {

            videoPreviewCard(
                metadata
            )

        } else if
            let error =
                downloader.metadataError {

            metadataErrorCard(
                error
            )
        }
    }

    // MARK: - Loading Metadata

    private var loadingMetadataCard:
        some View {

        HStack(
            spacing: 14
        ) {

            ProgressView()
                .controlSize(
                    .small
                )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Reading video information…"
                )
                .font(.headline)

                Text(
                    "Getting thumbnail, title, duration and available formats"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()
        }
        .appCard()
    }

    // MARK: - Video Preview

    private func videoPreviewCard(
        _ metadata:
            VideoMetadata
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 18
        ) {

            thumbnailView(
                metadata
            )

            VStack(
                alignment: .leading,
                spacing: 9
            ) {

                Text(
                    metadata.title
                )
                .font(
                    .system(
                        size: 19,
                        weight: .semibold
                    )
                )
                .lineLimit(3)
                .textSelection(
                    .enabled
                )

                if
                    let uploader =
                        metadata.uploader,
                    !uploader.isEmpty {

                    Label(
                        uploader,
                        systemImage:
                            "person.circle"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                if
                    !metadata
                        .formattedDuration
                        .isEmpty {

                    Label(
                        metadata
                            .formattedDuration,
                        systemImage:
                            "clock"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer(
                    minLength: 4
                )

                Label(
                    "Ready to download",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )
                .foregroundStyle(
                    .green
                )
            }

            Spacer()
        }
        .appCard()
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailView(
        _ metadata:
            VideoMetadata
    ) -> some View {

        if
            let thumbnailURL =
                metadata.thumbnailURL {

            AsyncImage(
                url: thumbnailURL
            ) { phase in

                switch phase {

                case .empty:

                    ZStack {

                        thumbnailPlaceholder

                        ProgressView()
                    }

                case .success(
                    let image
                ):

                    image
                        .resizable()
                        .scaledToFill()

                case .failure:

                    thumbnailPlaceholder

                @unknown default:

                    thumbnailPlaceholder
                }
            }
            .frame(
                width: 230,
                height: 130
            )
            .clipShape(

                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )

        } else {

            thumbnailPlaceholder
                .frame(
                    width: 230,
                    height: 130
                )
        }
    }

    private var thumbnailPlaceholder:
        some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                Color.white
                    .opacity(
                        0.055
                    )
            )

            Image(
                systemName:
                    "play.rectangle"
            )
            .font(
                .system(
                    size: 32
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Metadata Error

    private func metadataErrorCard(
        _ message: String
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .foregroundStyle(
                .orange
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    "Couldn't load video information"
                )
                .font(
                    .headline
                )

                Text(message)
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(6)
                    .textSelection(
                        .enabled
                    )
            }

            Spacer()
        }
        .appCard()
    }

    // MARK: - Download Settings

    private var downloadSettingsCard:
        some View {

        VStack(
            spacing: 18
        ) {

            HStack {

                Label(
                    "Format",
                    systemImage:
                        "rectangle.stack"
                )
                .font(
                    .headline
                )

                Spacer()

                Picker(
                    "Format",
                    selection:
                        $selectedFormat
                ) {

                    if
                        let metadata =
                            downloader.metadata {

                        ForEach(
                            metadata
                                .availableVideoOptions
                        ) { option in

                            Text(
                                option.title
                            )
                            .tag(
                                option
                            )
                        }

                    } else {

                        Text(
                            "Best Quality"
                        )
                        .tag(
                            VideoFormatOption
                                .best
                        )

                        Text("MP4 Video")
                            .tag(VideoFormatOption.mp4)

                        Text(
                            "Audio Only"
                        )
                        .tag(
                            VideoFormatOption
                                .audioOnly
                        )
                    }
                }
                .labelsHidden()
                .frame(
                    width: 210
                )
            }

            if
                let metadata =
                    downloader.metadata {

                formatInformation(
                    metadata
                )
            }

            Divider()
                .opacity(0.3)

            HStack(
                spacing: 12
            ) {

                Label(
                    "Save to",
                    systemImage:
                        "folder"
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    destination
                        .lastPathComponent
                )
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(1)

                Button(
                    "Choose"
                ) {

                    chooseFolder()
                }
                .buttonStyle(
                    .bordered
                )
            }
        }
        .appCard()
    }

    // MARK: - Format Information

    @ViewBuilder
    private func formatInformation(
        _ metadata:
            VideoMetadata
    ) -> some View {

        switch selectedFormat {

        case .mp4:
            Label("Saves as MP4; conversion may take a little longer", systemImage: "film")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .best:

            HStack {

                Image(
                    systemName:
                        "sparkles.tv"
                )

                Text(
                    "Highest available video + audio"
                )

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

        case .video(
            let height
        ):

            let matchingFormats =
                metadata.formats?
                    .filter {

                        $0.height ==
                            height

                        && $0.vcodec
                            != nil

                        && $0.vcodec
                            != "none"
                    }
                    ?? []

            HStack(
                spacing: 14
            ) {

                Label(
                    "\(height)p",
                    systemImage:
                        "display"
                )

                if
                    let fps =
                        matchingFormats
                            .compactMap(
                                \.fps
                            )
                            .max() {

                    Text(
                        "\(Int(fps)) FPS"
                    )
                }

                if
                    let codec =
                        matchingFormats
                            .compactMap(
                                \.vcodec
                            )
                            .first {

                    Text(
                        shortCodecName(
                            codec
                        )
                    )
                }

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )

        case .audioOnly:

            HStack {

                Image(
                    systemName:
                        "waveform"
                )

                Text(
                    "Audio will be converted to MP3"
                )

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Codec

    private func shortCodecName(
        _ codec: String
    ) -> String {

        let lower =
            codec.lowercased()

        if lower.contains(
            "av01"
        ) {
            return "AV1"
        }

        if lower.contains(
            "vp9"
        ) {
            return "VP9"
        }

        if
            lower.contains(
                "avc1"
            )
            || lower.contains(
                "h264"
            ) {

            return "H.264"
        }

        if
            lower.contains(
                "hev"
            )
            || lower.contains(
                "h265"
            )
            || lower.contains(
                "hvc1"
            ) {

            return "HEVC"
        }

        return codec
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressCard:
        some View {

        if
            downloader
                .isDownloading

            || downloader.progress
                > 0 {

            VStack(
                spacing: 12
            ) {

                ProgressView(
                    value:
                        downloader.progress
                )

                HStack {

                    Text(
                        downloader.status
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    Text(
                        "\(Int(downloader.progress * 100))%"
                    )
                    .font(
                        .system(
                            .subheadline,
                            design:
                                .monospaced
                        )
                    )
                }
            }
            .appCard()
        }
    }

    // MARK: - Action Buttons

    private var actionButtons:
        some View {

        HStack {

            Button {

                NSWorkspace.shared.open(
                    destination
                )

            } label: {

                Label(
                    "Open Folder",
                    systemImage:
                        "folder"
                )
            }
            .buttonStyle(
                .bordered
            )

            Spacer()

            if downloader
                .isDownloading {

                Button(
                    role: .destructive
                ) {

                    downloader.cancel()

                } label: {

                    Label(
                        "Cancel",
                        systemImage:
                            "xmark.circle"
                    )
                }
                .buttonStyle(
                    .bordered
                )

            } else {

                Button {

                    downloader.download(
                        url: videoURL,
                        formatOption:
                            selectedFormat,
                        destination:
                            destination
                    )

                } label: {

                    Label(
                        "Download",
                        systemImage:
                            "arrow.down.circle.fill"
                    )
                    .frame(
                        minWidth: 110
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(
                    .large
                )
                .keyboardShortcut(
                    .return,
                    modifiers: []
                )
                .disabled(
                    videoURL
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty

                    || !toolManager
                        .status
                        .isReady
                )
            }
        }
    }

    // MARK: - Download History

    @ViewBuilder
    private var downloadHistorySection:
        some View {

        if !history
            .items
            .isEmpty {

            VStack(
                alignment: .leading,
                spacing: 16
            ) {

                HStack {

                    Label(
                        "Recent Downloads",
                        systemImage:
                            "clock.arrow.circlepath"
                    )
                    .font(
                        .title3
                            .bold()
                    )

                    Spacer()

                    Text(
                        "\(history.items.count)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Button(
                        "Clear"
                    ) {

                        history.clear()
                    }
                    .buttonStyle(
                        .plain
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Divider()
                    .opacity(0.3)

                let recentItems =
                    Array(
                        history
                            .items
                            .prefix(10)
                    )

                ForEach(
                    recentItems
                ) { item in

                    historyRow(
                        item
                    )

                    if item.id !=
                        recentItems.last?.id {

                        Divider()
                            .opacity(
                                0.22
                            )
                    }
                }
            }
            .appCard()
        }
    }

    // MARK: - History Row

    private func historyRow(
        _ item:
            DownloadHistoryItem
    ) -> some View {

        HStack(
            spacing: 14
        ) {

            historyThumbnail(
                item
            )

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(
                    item.title
                )
                .font(
                    .headline
                )
                .lineLimit(2)

                HStack(
                    spacing: 7
                ) {

                    Text(
                        item.formatTitle
                    )

                    Text("•")

                    Text(
                        item.completedAt,
                        format:
                            .dateTime
                                .day()
                                .month(
                                    .abbreviated
                                )
                                .hour()
                                .minute()
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                if !item.fileExists {

                    Label(
                        "File no longer found",
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .orange
                    )
                }
            }

            Spacer()

            Button {

                NSWorkspace.shared.open(
                    item.fileURL
                )

            } label: {

                Image(
                    systemName:
                        "play.circle"
                )
            }
            .buttonStyle(
                .bordered
            )
            .help(
                "Open File"
            )
            .disabled(
                !item.fileExists
            )

            Button {

                NSWorkspace.shared
                    .activateFileViewerSelecting(
                        [
                            item.fileURL
                        ]
                    )

            } label: {

                Image(
                    systemName:
                        "folder"
                )
            }
            .buttonStyle(
                .bordered
            )
            .help(
                "Show in Finder"
            )
            .disabled(
                !item.fileExists
            )

            Button(
                role: .destructive
            ) {

                history.remove(
                    item
                )

            } label: {

                Image(
                    systemName:
                        "trash"
                )
            }
            .buttonStyle(
                .borderless
            )
            .help(
                "Remove from History"
            )
        }
    }

    // MARK: - History Thumbnail

    @ViewBuilder
    private func historyThumbnail(
        _ item:
            DownloadHistoryItem
    ) -> some View {

        if
            let url =
                item.thumbnailURL {

            AsyncImage(
                url: url
            ) { phase in

                switch phase {

                case .success(
                    let image
                ):

                    image
                        .resizable()
                        .scaledToFill()

                default:

                    historyThumbnailPlaceholder
                }
            }
            .frame(
                width: 96,
                height: 56
            )
            .clipShape(

                RoundedRectangle(
                    cornerRadius: 9,
                    style: .continuous
                )
            )

        } else {

            historyThumbnailPlaceholder
                .frame(
                    width: 96,
                    height: 56
                )
        }
    }

    private var historyThumbnailPlaceholder:
        some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: 9,
                style: .continuous
            )
            .fill(
                Color.white
                    .opacity(
                        0.05
                    )
            )

            Image(
                systemName:
                    "film"
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Drop Overlay

    private var dropOverlay:
        some View {

        ZStack {

            Color.black
                .opacity(0.62)
                .ignoresSafeArea()

            VStack(
                spacing: 14
            ) {

                Image(
                    systemName:
                        "link.badge.plus"
                )
                .font(
                    .system(
                        size: 46,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.accentColor
                )

                Text(
                    "Drop Video URL"
                )
                .font(
                    .system(
                        size: 24,
                        weight: .bold
                    )
                )

                Text(
                    "Release to load the video information"
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .padding(36)
            .background(

                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .fill(
                    Color(
                        red: 0.08,
                        green: 0.09,
                        blue: 0.12
                    )
                )
            )
            .overlay(

                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .stroke(
                    Color.accentColor,
                    lineWidth: 2
                )
            )
        }
    }

    // MARK: - Paste

    private func pasteURL() {

        guard
            let text =
                NSPasteboard
                    .general
                    .string(
                        forType:
                            .string
                    )
        else {
            return
        }

        let trimmed =
            text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        videoURL =
            trimmed

        downloader
            .loadMetadata(
                for: trimmed
            )
    }

    // MARK: - Handle Drop

    private func handleDrop(
        _ providers:
            [NSItemProvider]
    ) -> Bool {

        // Try URL first

        if
            let provider =
                providers.first(
                    where: {

                        $0
                            .hasItemConformingToTypeIdentifier(
                                UTType
                                    .url
                                    .identifier
                            )
                    }
                ) {

            provider.loadItem(
                forTypeIdentifier:
                    UTType
                        .url
                        .identifier,
                options: nil
            ) { item, _ in

                var droppedURL:
                    URL?

                if
                    let url =
                        item as? URL {

                    droppedURL =
                        url
                }

                if
                    let data =
                        item as? Data {

                    droppedURL =
                        URL(
                            dataRepresentation:
                                data,
                            relativeTo: nil
                        )
                }

                guard
                    let droppedURL
                else {
                    return
                }

                Task {
                    @MainActor in

                    handleDroppedURL(
                        droppedURL
                    )
                }
            }

            return true
        }

        // Fall back to text

        if
            let provider =
                providers.first(
                    where: {

                        $0
                            .hasItemConformingToTypeIdentifier(
                                UTType
                                    .plainText
                                    .identifier
                            )
                    }
                ) {

            provider.loadItem(
                forTypeIdentifier:
                    UTType
                        .plainText
                        .identifier,
                options: nil
            ) { item, _ in

                var droppedText:
                    String?

                if
                    let text =
                        item as? String {

                    droppedText =
                        text
                }

                if
                    let data =
                        item as? Data,

                    let text =
                        String(
                            data: data,
                            encoding: .utf8
                        ) {

                    droppedText =
                        text
                }

                guard
                    let droppedText
                else {
                    return
                }

                let trimmed =
                    droppedText
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                guard
                    let url =
                        URL(
                            string:
                                trimmed
                        )
                else {
                    return
                }

                Task {
                    @MainActor in

                    handleDroppedURL(
                        url
                    )
                }
            }

            return true
        }

        return false
    }

    // MARK: - Dropped URL

    private func handleDroppedURL(
        _ url: URL
    ) {

        guard
            let scheme =
                url.scheme?
                    .lowercased(),

            scheme == "http"
            || scheme == "https"
        else {
            return
        }

        let value =
            url.absoluteString

        videoURL =
            value

        downloader
            .loadMetadata(
                for: value
            )
    }

    // MARK: - Folder Picker

    private func chooseFolder() {

        let panel =
            NSOpenPanel()

        panel.canChooseFiles =
            false

        panel.canChooseDirectories =
            true

        panel.allowsMultipleSelection =
            false

        panel.prompt =
            "Choose"

        panel.directoryURL =
            destination

        if
            panel.runModal() == .OK,

            let selectedURL =
                panel.url {

            destination =
                selectedURL
        }
    }
}

// MARK: - Card Style

private extension View {

    func appCard()
        -> some View {

        self
            .padding(18)
            .background(

                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .fill(
                    Color.white
                        .opacity(
                            0.045
                        )
                )
            )
            .overlay(

                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    Color.white
                        .opacity(
                            0.075
                        ),
                    lineWidth: 1
                )
            )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
