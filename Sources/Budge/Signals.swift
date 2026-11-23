import AppKit
import BudgeCore
import CoreAudio
import CoreGraphics
import CoreMediaIO
import Foundation

/// What the Mac can tell us without asking for any permission.
enum Signals {
    /// Seconds since the last key press, click or mouse move.
    static func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Name of the app in front if it fills a whole screen (slides, full-screen video), else nil.
    ///
    /// Only checks screens where a maximized window can't look full screen: the main screen
    /// (it always has a menu bar) and any screen that keeps room for one. On a screen without
    /// a menu bar, a maximized window and a full-screen app look the same, so it is skipped
    /// rather than risk Budge never nudging.
    @MainActor
    static func fullScreenApp() -> String? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier,
              let main = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return nil }

        let frontWindows = windows.compactMap { window -> CGRect? in
            guard window[kCGWindowOwnerPID as String] as? pid_t == front.processIdentifier,
                  (window[kCGWindowLayer as String] as? Int ?? -1) >= 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }

        // Window bounds use a top-left origin; NSScreen uses bottom-left.
        let checkable = NSScreen.screens.filter { $0 == main || $0.visibleFrame.maxY < $0.frame.maxY }
        let covered = checkable.contains { screen in
            let frame = CGRect(x: screen.frame.minX, y: main.frame.maxY - screen.frame.maxY,
                               width: screen.frame.width, height: screen.frame.height)
            return FullScreen.isCovered(frame, byAnyOf: frontWindows)
        }
        return covered ? (front.localizedName ?? "An app") : nil
    }

    /// True while a call is likely: some app is recording the mic, or a camera is on.
    static func inCall() -> Bool {
        !appsUsingMic().isEmpty || cameraInUse()
    }

    /// Bundle ids of apps currently recording audio input.
    static func appsUsingMic() -> [String] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }

        return processes.compactMap { process in
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            address.mSelector = kAudioProcessPropertyIsRunningInput
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &runningSize, &running) == noErr,
                  running != 0 else { return nil }

            var bundleID: Unmanaged<CFString>?
            var idSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            address.mSelector = kAudioProcessPropertyBundleID
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &idSize, &bundleID) == noErr,
                  let name = bundleID?.takeRetainedValue() as String? else { return "unknown" }
            return name
        }
    }

    static func cameraInUse() -> Bool {
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return false }

        address.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        return devices.contains { device in
            var running: UInt32 = 0
            var runningUsed: UInt32 = 0
            let ok = CMIOObjectGetPropertyData(device, &address, 0, nil,
                                               UInt32(MemoryLayout<UInt32>.size), &runningUsed, &running)
            return ok == noErr && running != 0
        }
    }
}
