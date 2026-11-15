import UIKit

/// Clipboard helper for sensitive values.
///
/// Values are written `localOnly` (never synced through Universal Clipboard)
/// with a system-enforced expiration date, so the value disappears even when
/// the app is suspended or killed before the expiry.
///
/// All methods must be called on the main thread.
class PasteboardHandler {

    /// `changeCount` of the general pasteboard right after our last write.
    private var ownedChangeCount: Int?

    func copy(value: String, expiresAfterMs: Double) {
        let pasteboard = UIPasteboard.general
        let expiry = Date().addingTimeInterval(expiresAfterMs / 1000.0)
        pasteboard.setItems(
            [["public.utf8-plain-text": value]],
            options: [
                .localOnly: true,
                .expirationDate: expiry,
            ]
        )
        ownedChangeCount = pasteboard.changeCount
    }

    /// Clears the pasteboard and returns `true` when it was cleared.
    ///
    /// With `onlyIfOwned` the pasteboard is left untouched (and `false` is
    /// returned) when something else was copied after our write.
    func clear(onlyIfOwned: Bool) -> Bool {
        let pasteboard = UIPasteboard.general
        if onlyIfOwned {
            guard let owned = ownedChangeCount, owned == pasteboard.changeCount else {
                ownedChangeCount = nil
                return false
            }
        }
        pasteboard.items = []
        ownedChangeCount = nil
        return true
    }
}
