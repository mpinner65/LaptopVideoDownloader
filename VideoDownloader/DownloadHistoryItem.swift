import Foundation

struct DownloadHistoryItem:
    Identifiable,
    Codable,
    Hashable,
    Sendable {

    let id: UUID

    let title: String

    let thumbnailURLString: String?

    let sourceURL: String

    let filePath: String

    let formatTitle: String

    let completedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        thumbnailURLString: String?,
        sourceURL: String,
        filePath: String,
        formatTitle: String,
        completedAt: Date = Date()
    ) {

        self.id = id

        self.title = title

        self.thumbnailURLString =
            thumbnailURLString

        self.sourceURL =
            sourceURL

        self.filePath =
            filePath

        self.formatTitle =
            formatTitle

        self.completedAt =
            completedAt
    }

    var thumbnailURL: URL? {

        guard let thumbnailURLString else {
            return nil
        }

        return URL(
            string: thumbnailURLString
        )
    }

    var fileURL: URL {

        URL(
            fileURLWithPath: filePath
        )
    }

    var fileExists: Bool {

        FileManager.default
            .fileExists(
                atPath: filePath
            )
    }
}
