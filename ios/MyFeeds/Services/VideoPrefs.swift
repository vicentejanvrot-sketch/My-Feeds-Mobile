import Foundation
import UIKit
import Observation

/// Video quality options matching the companion apps.
enum VideoQuality: String, CaseIterable {
    case auto = "Auto"
    case q1080 = "1080p"
    case q720 = "720p"
    case q480 = "480p"
    case q360 = "360p"
    case q240 = "240p"

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .q1080: return "1080p HD"
        case .q720: return "720p HD"
        case .q480: return "480p"
        case .q360: return "360p"
        case .q240: return "240p"
        }
    }

    /// YouTube IFrame API quality hint.
    var youtubeValue: String {
        switch self {
        case .auto: return "default"
        case .q1080: return "hd1080"
        case .q720: return "hd720"
        case .q480: return "large"
        case .q360: return "medium"
        case .q240: return "small"
        }
    }
}

enum VideoSpeed: String, CaseIterable {
    case x1 = "1"
    case x125 = "1.25"
    case x15 = "1.5"
    case x175 = "1.75"
    case x2 = "2"

    var label: String { self == .x1 ? "Normal (1×)" : "\(rawValue)×" }
    var pillLabel: String { "\(rawValue)×" }
    var value: Double { Double(rawValue) ?? 1 }
}

/// Locally persisted playback preferences (quality default 1080p, speed default 2×).
@Observable
final class VideoPrefs {
    var quality: VideoQuality {
        didSet { UserDefaults.standard.set(quality.rawValue, forKey: "settings.video_quality") }
    }

    var speed: VideoSpeed {
        didSet { UserDefaults.standard.set(speed.rawValue, forKey: "settings.video_speed") }
    }

    var keepScreenOn: Bool {
        didSet { UserDefaults.standard.set(keepScreenOn, forKey: "settings.keep_screen_on") }
    }

    init() {
        let defaults = UserDefaults.standard
        quality = VideoQuality(rawValue: defaults.string(forKey: "settings.video_quality") ?? "") ?? .q1080
        speed = VideoSpeed(rawValue: defaults.string(forKey: "settings.video_speed") ?? "") ?? .x2
        keepScreenOn = defaults.object(forKey: "settings.keep_screen_on") as? Bool ?? false
    }

    // MARK: - Resume positions

    func savedPosition(videoId: String) -> (time: Double, duration: Double)? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "video_position.\(videoId)"),
              let time = dict["currentTime"] as? Double,
              let duration = dict["duration"] as? Double else { return nil }
        return (time, duration)
    }

    func savePosition(videoId: String, time: Double, duration: Double) {
        UserDefaults.standard.set(
            ["currentTime": time, "duration": duration, "updatedAt": Date().timeIntervalSince1970],
            forKey: "video_position.\(videoId)"
        )
    }

    func clearPosition(videoId: String) {
        UserDefaults.standard.removeObject(forKey: "video_position.\(videoId)")
    }
}
