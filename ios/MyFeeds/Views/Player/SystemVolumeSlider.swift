import MediaPlayer
import SwiftUI

/// The native iOS output-volume control used for embedded video playback.
struct SystemVolumeSlider: UIViewRepresentable {
    @Binding var value: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        volumeView.showsVolumeSlider = true

        guard let slider = volumeSlider(in: volumeView) else { return volumeView }
        configure(slider)
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.volumeChanged(_:)),
            for: .valueChanged
        )

        DispatchQueue.main.async {
            context.coordinator.updateValue(from: slider)
        }
        return volumeView
    }

    func updateUIView(_ volumeView: MPVolumeView, context: Context) {
        context.coordinator.value = $value
        guard let slider = volumeSlider(in: volumeView) else { return }
        configure(slider)
    }

    private func volumeSlider(in volumeView: MPVolumeView) -> UISlider? {
        volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    private func configure(_ slider: UISlider) {
        slider.minimumTrackTintColor = UIColor(red: 0.055, green: 0.647, blue: 0.914, alpha: 1)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.24)
        slider.thumbTintColor = .white
    }

    final class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func volumeChanged(_ slider: UISlider) {
            updateValue(from: slider)
        }

        func updateValue(from slider: UISlider) {
            value.wrappedValue = Double(slider.value) * 100
        }
    }
}
