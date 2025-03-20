import SwiftUI
import ServiceManagement
import CoreServices

@available(macOS 11.0, *)
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published var openAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(openAtLogin, forKey: "openAtLogin")
            updateLoginItem()
        }
    }
    
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            // Post notification for window level changes
            NotificationCenter.default.post(name: Notification.Name("AlwaysOnTopChanged"), object: nil)
        }
    }
    
    // Make shortcuts a read-only property with fixed value
    var shortcuts: [String: String] = [
        "toggleWindow": "⌘E"
    ]
    
    private init() {
        self.openAtLogin = UserDefaults.standard.bool(forKey: "openAtLogin")
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        
        // Always use ⌘E regardless of what might be stored in UserDefaults
        self.shortcuts = [
            "toggleWindow": "⌘E"
        ]
        
        updateLoginItem()
    }
    
    func getShortcut(for key: String) -> String {
        return shortcuts[key] ?? ""
    }
    
    // This method no longer changes the shortcut
    func setShortcut(_ shortcut: String, for key: String) {
        // Do nothing - shortcuts can't be changed
    }
    
    // Toggle always on top setting
    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
    }
    
    // Set always on top setting directly
    func setAlwaysOnTop(_ value: Bool) {
        alwaysOnTop = value
    }
    
    func resetToDefaults() {
        // No need to update shortcuts as they're now fixed
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if openAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Error updating login item:", error)
            }
        } else {
            // For older macOS versions, we'll use the legacy approach
            updateLoginItemLegacy(enabled: openAtLogin)
        }
    }
    
    private func updateLoginItemLegacy(enabled: Bool) {
        guard let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() else {
            print("Failed to create login items list")
            return
        }
        
        if enabled {
            guard let bundleURL = Bundle.main.bundleURL as CFURL? else {
                print("Failed to get bundle URL")
                return
            }
            LSSharedFileListInsertItemURL(loginItems,
                                        kLSSharedFileListItemLast.takeRetainedValue(),
                                        nil,
                                        nil,
                                        bundleURL,
                                        nil,
                                        nil)
        } else {
            guard let snapshot = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem] else {
                print("Failed to get login items snapshot")
                return
            }
            
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            for item in snapshot {
                if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL?,
                   itemURL.bundleIdentifier == bundleID {
                    LSSharedFileListItemRemove(loginItems, item)
                }
            }
        }
    }
}

private extension URL {
    var bundleIdentifier: String? {
        if let bundle = Bundle(url: self) {
            return bundle.bundleIdentifier
        }
        return nil
    }
} 