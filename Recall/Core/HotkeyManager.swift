import AppKit
import Carbon

// MARK: - Hotkey Manager

/// Registers a global keyboard shortcut using Carbon's RegisterEventHotKey API.
/// This works even when the app has no active window.
final class HotkeyManager {

    static let shared = HotkeyManager()
    private init() {}

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?

    // MARK: - Registration

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        unregister()
        self.handler = action

        // Install Carbon event handler if not already done
        installEventHandler()

        let id = EventHotKeyID(signature: FourCharCode("RCL1"), id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("⚠️ HotkeyManager: Failed to register hotkey, status \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Default shortcut

    /// Cmd+Shift+V → keyCode 9, modifiers cmdKey | shiftKey = 256 | 512 = 768
    static let defaultKeyCode: UInt32 = 9
    static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    // MARK: - Carbon event handler

    private func installEventHandler() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handler?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }
}

// MARK: - FourCharCode helper

private extension FourCharCode {
    init(_ string: String) {
        var result: FourCharCode = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        self = result
    }
}
