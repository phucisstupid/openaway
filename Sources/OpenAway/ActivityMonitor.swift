import AVFoundation
import AppKit
import CoreAudio
import OpenAwayCore

/// Reads activity metadata only: no capture session, audio tap, or permission request.
@MainActor
final class ActivityMonitor {
    private var nextPoll = Date.distantPast
    private var meetingUntil = Date.distantPast
    private var videoUntil = Date.distantPast
    private var meetingReason = "Microphone in use"

    private static let browsers = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome",
        "org.chromium.Chromium", "org.mozilla.firefox", "com.microsoft.edgemac",
        "com.brave.Browser", "company.thebrowser.Browser", "com.operasoftware.Opera",
        "net.imput.helium",
    ]
    private static let videoApps = [
        "com.apple.TV", "com.apple.QuickTimePlayerX", "org.videolan.vlc", "com.colliderli.iina",
    ]
    private static let meetingApps = [
        "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2", "com.apple.FaceTime",
        "com.cisco.webexmeetingsapp", "com.webex.meetingmanager", "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
    ]

    private lazy var cameras: AVCaptureDevice.DiscoverySession = {
        let external: AVCaptureDevice.DeviceType
        if #available(macOS 14, *) { external = .external } else { external = .externalUnknown }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, external], mediaType: .video, position: .unspecified
        )
    }()

    func pauseReason(settings: AppSettings, now: Date = Date()) -> String? {
        guard settings.pauseForMeetings || settings.pauseForVideo else {
            nextPoll = .distantPast
            meetingUntil = .distantPast
            videoUntil = .distantPast
            return nil
        }
        if now >= nextPoll {
            nextPoll = now.addingTimeInterval(2)
            let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            var microphone = false
            var meetingAudio = false
            var videoAudio = false

            if #available(macOS 14.2, *), let processes = audioProcesses() {
                for process in processes {
                    if settings.pauseForMeetings, readUInt32(process, kAudioProcessPropertyIsRunningInput) == 1 {
                        microphone = true
                    }
                    guard readUInt32(process, kAudioProcessPropertyIsRunningOutput) == 1,
                        let bundleID = bundleID(for: process)
                    else { continue }
                    meetingAudio = meetingAudio || Self.matches(bundleID, apps: Self.meetingApps)
                    // Safari can route sound through a WebKit helper shared with other apps.
                    let browserHelper =
                        bundleID.hasPrefix("com.apple.WebKit.") && Self.matches(foreground, apps: Self.browsers)
                    videoAudio =
                        videoAudio || browserHelper || Self.matches(bundleID, apps: Self.browsers + Self.videoApps)
                }
            } else {
                // ponytail: older macOS exposes device-level activity, not its owner.
                // This can include duplex-device output; per-process checks need macOS 14.2+.
                microphone = defaultDeviceRunning(kAudioHardwarePropertyDefaultInputDevice)
                let output = defaultDeviceRunning(kAudioHardwarePropertyDefaultOutputDevice)
                meetingAudio = output && Self.matches(foreground, apps: Self.meetingApps)
                videoAudio = output && Self.matches(foreground, apps: Self.browsers + Self.videoApps)
            }

            if settings.pauseForMeetings {
                // Device discovery and this property do not open a capture input.
                let camera = !microphone && cameras.devices.contains { $0.isInUseByAnotherApplication }
                if microphone || camera || meetingAudio {
                    meetingReason = microphone ? "Microphone in use" : camera ? "Camera in use" : "Meeting app audio"
                    meetingUntil = now.addingTimeInterval(5)
                }
            }
            // ponytail: audio I/O from known browsers/players is a video heuristic.
            // Muted video may be missed; music or idle audio streams may match. Exact
            // browser playback would require an optional browser extension.
            if settings.pauseForVideo && videoAudio { videoUntil = now.addingTimeInterval(5) }
        }
        if settings.pauseForMeetings && now < meetingUntil { return meetingReason }
        if settings.pauseForVideo && now < videoUntil { return "Video or browser audio" }
        return nil
    }

    private static func matches(_ bundleID: String, apps: [String]) -> Bool {
        apps.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }

    static func smokeCheck() -> Bool {
        let cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        let microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)
        let monitor = ActivityMonitor()
        var settings = AppSettings()
        _ = monitor.pauseReason(settings: settings)
        settings.pauseForMeetings = false
        settings.pauseForVideo = false
        return monitor.pauseReason(settings: settings) == nil
            && matches("com.google.Chrome.helper", apps: browsers)
            && !matches("com.google.ChromeOther", apps: browsers)
            && matches("us.zoom.xos", apps: meetingApps)
            && AVCaptureDevice.authorizationStatus(for: .video) == cameraPermission
            && AVCaptureDevice.authorizationStatus(for: .audio) == microphonePermission
    }

    private func defaultDeviceRunning(_ selector: AudioObjectPropertySelector) -> Bool {
        guard let device = readUInt32(AudioObjectID(kAudioObjectSystemObject), selector), device != kAudioObjectUnknown
        else { return false }
        return readUInt32(device, kAudioDevicePropertyDeviceIsRunningSomewhere) == 1
    }

    private func readUInt32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    @available(macOS 14.2, *)
    private func audioProcesses() -> [AudioObjectID]? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        guard size > 0 else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        let status = processes.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return nil }
        return Array(processes.prefix(Int(size) / MemoryLayout<AudioObjectID>.stride))
    }

    @available(macOS 14.2, *)
    private func bundleID(for process: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr else { return nil }
        // CoreAudio explicitly transfers ownership of this CFString to the caller.
        return value.map { $0.takeRetainedValue() as String }
    }
}
