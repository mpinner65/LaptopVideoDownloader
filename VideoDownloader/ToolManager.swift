import Foundation
import Combine

@MainActor
final class ToolManager: ObservableObject {

    // MARK: - Published State

    @Published private(set)
    var status = ToolStatus(
        ytDLPPath: nil,
        ffmpegPath: nil
    )

    // MARK: - Refresh

    func refresh() {

        status = ToolStatus(
            ytDLPPath: Self.findExecutable(
                named: "yt-dlp"
            ),
            ffmpegPath: Self.findExecutable(
                named: "ffmpeg"
            )
        )
    }

    // MARK: - Executable Lookup

    nonisolated
    static func findExecutable(
        named name: String
    ) -> String? {

        // 1. Prefer bundled tools, whether Xcode preserves the Tools
        // folder or copies its contents directly into Resources.
        if let resources = Bundle.main.resourceURL {
            let bundledURLs = [
                resources
                    .appendingPathComponent("Tools", isDirectory: true)
                    .appendingPathComponent(name, isDirectory: false),
                resources
                    .appendingPathComponent(name, isDirectory: false)
            ]

            for bundledURL in bundledURLs {
                if FileManager.default.isExecutableFile(atPath: bundledURL.path) {
                    return bundledURL.path
                }
            }
        }

        // 2. Apple Silicon Homebrew

        let appleSiliconPath =
            "/opt/homebrew/bin/\(name)"

        if FileManager.default
            .isExecutableFile(
                atPath:
                    appleSiliconPath
            ) {

            return appleSiliconPath
        }

        // 3. Intel Homebrew

        let intelPath =
            "/usr/local/bin/\(name)"

        if FileManager.default
            .isExecutableFile(
                atPath:
                    intelPath
            ) {

            return intelPath
        }

        // 4. Common system locations

        let systemPaths = [
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]

        for path in systemPaths {

            if FileManager.default
                .isExecutableFile(
                    atPath: path
                ) {

                return path
            }
        }

        return nil
    }
}
