import Foundation

struct VideoMetadata: Codable, Sendable {

    let title: String
    let thumbnail: String?
    let uploader: String?
    let duration: Double?
    let webpageURL: String?
    let formats: [VideoFormat]?

    enum CodingKeys: String, CodingKey {
        case title
        case thumbnail
        case uploader
        case duration
        case formats
        case webpageURL = "webpage_url"
    }

    var thumbnailURL: URL? {
        guard let thumbnail else {
            return nil
        }

        return URL(string: thumbnail)
    }

    var formattedDuration: String {

        guard let duration else {
            return ""
        }

        let totalSeconds = Int(duration)

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format: "%d:%02d",
            minutes,
            seconds
        )
    }

    var availableVideoOptions: [VideoFormatOption] {

        let heights = formats?
            .compactMap { format -> Int? in

                guard
                    let codec = format.vcodec,
                    codec != "none",
                    let height = format.height
                else {
                    return nil
                }

                return height
            }
            ?? []

        let uniqueHeights =
            Array(Set(heights))
                .sorted(by: >)

        var options: [VideoFormatOption] = [
            .best, .mp4
        ]

        options += uniqueHeights.map {
            .video(height: $0)
        }

        options.append(.audioOnly)

        return options
    }
}

// MARK: - Video Format

struct VideoFormat: Codable, Sendable, Identifiable {

    let formatID: String

    let ext: String?
    let width: Int?
    let height: Int?
    let fps: Double?

    let vcodec: String?
    let acodec: String?

    let filesize: Double?
    let filesizeApprox: Double?

    enum CodingKeys: String, CodingKey {

        case ext
        case width
        case height
        case fps
        case vcodec
        case acodec
        case filesize

        case formatID = "format_id"

        case filesizeApprox =
            "filesize_approx"
    }

    var id: String {
        formatID
    }
}

// MARK: - Video Format Option

enum VideoFormatOption:
    Hashable,
    Identifiable,
    Sendable {

    case best
    case mp4
    case video(height: Int)
    case audioOnly

    var id: String {

        switch self {

        case .mp4:
            return "mp4"

        case .best:
            return "best"

        case .video(let height):
            return "video-\(height)"

        case .audioOnly:
            return "audio"
        }
    }

    var title: String {

        switch self {

        case .mp4:
            return "MP4 Video"

        case .best:
            return "Best Quality"

        case .video(let height):

            switch height {

            case 4320:
                return "8K (4320p)"

            case 2160:
                return "4K (2160p)"

            case 1440:
                return "1440p"

            case 1080:
                return "1080p"

            case 720:
                return "720p"

            case 480:
                return "480p"

            case 360:
                return "360p"

            default:
                return "\(height)p"
            }

        case .audioOnly:
            return "Audio Only"
        }
    }

    var ytDLPFormat: String {

        switch self {

        case .best, .mp4:

            return "bestvideo+bestaudio/best"

        case .video(let height):

            return
                "bestvideo[height<=\(height)]+bestaudio/best[height<=\(height)]"

        case .audioOnly:

            return "bestaudio/best"
        }
    }

    var isAudioOnly: Bool {

        if case .audioOnly = self {
            return true
        }

        return false
    }
}
