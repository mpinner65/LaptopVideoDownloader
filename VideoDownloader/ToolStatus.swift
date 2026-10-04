import Foundation

struct ToolStatus: Sendable {

    let ytDLPPath: String?
    let ffmpegPath: String?

    var hasYtDLP: Bool {
        ytDLPPath != nil
    }

    var hasFFmpeg: Bool {
        ffmpegPath != nil
    }

    var isReady: Bool {
        hasYtDLP && hasFFmpeg
    }
}
