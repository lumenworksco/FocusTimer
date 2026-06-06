import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onToggle: (() -> Void)?
    var onSkip: (() -> Void)?

    private var eventHandlerRef: EventHandlerRef?
    private var toggleHotKeyRef: EventHotKeyRef?
    private var skipHotKeyRef: EventHotKeyRef?

    private static let signature: OSType = {
        var r: OSType = 0
        for c in "FTMR".utf8 { r = (r << 8) | OSType(c) }
        return r
    }()

    private init() {}

    func register() {
        guard eventHandlerRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), carbonHotKeyHandler, 1, &spec, ptr, &eventHandlerRef)

        let id1 = EventHotKeyID(signature: HotkeyManager.signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            id1,
            GetApplicationEventTarget(),
            0,
            &toggleHotKeyRef
        )

        let id2 = EventHotKeyID(signature: HotkeyManager.signature, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(controlKey | optionKey),
            id2,
            GetApplicationEventTarget(),
            0,
            &skipHotKeyRef
        )
    }

    func unregister() {
        if let ref = toggleHotKeyRef { UnregisterEventHotKey(ref); toggleHotKeyRef = nil }
        if let ref = skipHotKeyRef   { UnregisterEventHotKey(ref); skipHotKeyRef   = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref);    eventHandlerRef  = nil }
    }
}

private func carbonHotKeyHandler(
    _: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        switch hotKeyID.id {
        case 1: manager.onToggle?()
        case 2: manager.onSkip?()
        default: break
        }
    }
    return noErr
}
