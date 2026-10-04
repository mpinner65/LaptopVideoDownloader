import Foundation
import Combine

@MainActor
final class DownloadHistoryStore:
    ObservableObject {

    // MARK: - Published State

    @Published private(set)
    var items: [DownloadHistoryItem] = []

    // MARK: - Storage

    private let storageKey =
        "VideoDownloader.DownloadHistory"

    private let maximumHistoryItems =
        100

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Add

    func add(
        _ item: DownloadHistoryItem
    ) {

        // Remove an older entry for the same file.
        items.removeAll {
            $0.filePath == item.filePath
        }

        items.insert(
            item,
            at: 0
        )

        if items.count >
            maximumHistoryItems {

            items = Array(
                items.prefix(
                    maximumHistoryItems
                )
            )
        }

        save()
    }

    // MARK: - Remove

    func remove(
        _ item: DownloadHistoryItem
    ) {

        items.removeAll {
            $0.id == item.id
        }

        save()
    }

    // MARK: - Clear

    func clear() {

        items.removeAll()

        save()
    }

    // MARK: - Save

    private func save() {

        do {

            let encoder =
                JSONEncoder()

            encoder.dateEncodingStrategy =
                .iso8601

            let data =
                try encoder.encode(
                    items
                )

            UserDefaults.standard.set(
                data,
                forKey: storageKey
            )

        } catch {

            print(
                "Could not save download history:",
                error
            )
        }
    }

    // MARK: - Load

    private func load() {

        guard
            let data =
                UserDefaults.standard.data(
                    forKey: storageKey
                )
        else {
            return
        }

        do {

            let decoder =
                JSONDecoder()

            decoder.dateDecodingStrategy =
                .iso8601

            items =
                try decoder.decode(
                    [DownloadHistoryItem].self,
                    from: data
                )

        } catch {

            print(
                "Could not load download history:",
                error
            )

            items = []
        }
    }
}
