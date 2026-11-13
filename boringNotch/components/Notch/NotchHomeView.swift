//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan
//

import Combine
import Defaults
import SwiftUI

// MARK: - Music Player (expanded, Dynamic Island style)

struct MusicPlayerView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var musicManager = MusicManager.shared
    let albumArtNamespace: Namespace.ID

    private var accent: Color {
        Defaults[.playerColorTinting]
            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.8) : .white
    }

    var body: some View {
        VStack(spacing: 14) {
            nowPlaying
            ScrubberView(accent: accent)
            transport
        }
        .padding(.top, 2)
        .buttonStyle(IslandPressStyle())
    }

    // MARK: Now playing

    private var nowPlaying: some View {
        HStack(spacing: 12) {
            IslandArtView(albumArtNamespace: albumArtNamespace)

            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 1) {
                                        MarqueeText(
                        $musicManager.songTitle, font: .system(size: 15, weight: .semibold),
                        nsFont: .title3, textColor: .white, frameWidth: geo.size.width)
                                        MarqueeText(
                        $musicManager.artistName, font: .system(size: 13),
                        nsFont: .body, textColor: .white.opacity(0.75), frameWidth: geo.size.width)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }

            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                .frame(width: 16, height: 14)
                .foregroundStyle(accent)
                .colorMultiply(accent)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 48)
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 48) {
            Button { MusicManager.shared.previousTrack() } label: {
                Image(systemName: "backward.fill").font(.system(size: 22, weight: .semibold))
                    .frame(width: 44, height: 36)
            }
            .accessibilityLabel("Previous track")
            Button { MusicManager.shared.togglePlay() } label: {
                Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                    .frame(width: 44, height: 36)
            }
            .accessibilityLabel(musicManager.isPlaying ? "Pause" : "Play")
            Button { MusicManager.shared.nextTrack() } label: {
                Image(systemName: "forward.fill").font(.system(size: 22, weight: .semibold))
                    .frame(width: 44, height: 36)
            }
            .accessibilityLabel("Next track")
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
    }
}

/// Progress bar and times. Nothing here ticks inside the app: the bar is a Core Animation layer that
/// animates itself to the end of the track, and the labels are system timer text.
struct ScrubberView: View {
    let accent: Color
    @ObservedObject private var musicManager = MusicManager.shared

    private var start: Date {
        musicManager.timestampDate.addingTimeInterval(-musicManager.elapsedTime)
    }
    private var end: Date { start.addingTimeInterval(max(musicManager.songDuration, 1)) }
    private var pauseTime: Date? { musicManager.isPlaying ? nil : musicManager.timestampDate }

    var body: some View {
        HStack(spacing: 8) {
            Text(timerInterval: start...end, pauseTime: pauseTime, countsDown: false, showsHours: false)
                .frame(width: 34, alignment: .leading)

            ScrubBar(
                position: musicManager.estimatedPlaybackPosition(),
                duration: musicManager.songDuration,
                isPlaying: musicManager.isPlaying,
                snapshot: musicManager.timestampDate,
                color: NSColor(accent),
                onSeek: { MusicManager.shared.seek(to: $0) }
            )
            .frame(height: 14)

            (Text("-") + Text(timerInterval: start...end, pauseTime: pauseTime, countsDown: true, showsHours: false))
                .frame(width: 40, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.75))
    }
}

struct ScrubBar: NSViewRepresentable {
    var position: Double
    var duration: Double
    var isPlaying: Bool
    var snapshot: Date
    var color: NSColor
    var onSeek: (Double) -> Void

    func makeNSView(context: Context) -> ScrubBarView {
        let view = ScrubBarView()
        view.onSeek = onSeek
        return view
    }

    func updateNSView(_ view: ScrubBarView, context: Context) {
        view.onSeek = onSeek
        view.configure(
            position: position, duration: duration, isPlaying: isPlaying, snapshot: snapshot, color: color)
    }
}

final class ScrubBarView: NSView {
    var onSeek: ((Double) -> Void)?

    private let track = CALayer()
    private let fill = CALayer()
    private let restHeight: CGFloat = 4
    private let activeHeight: CGFloat = 8

    private var duration: Double = 0
    private var progress: Double = 0
    private var isPlaying = false
    private var lastSnapshot: Date?
    private var dragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        track.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        layoutBars(animated: false)
        applyProgress(restart: true)
    }

    private func layoutBars(animated: Bool) {
        let h = dragging ? activeHeight : restHeight
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.25)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        track.frame = CGRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        track.cornerRadius = h / 2
        fill.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: h)
        fill.position = CGPoint(x: 0, y: bounds.midY)
        fill.cornerRadius = h / 2
        CATransaction.commit()
    }

    func configure(position: Double, duration: Double, isPlaying: Bool, snapshot: Date, color: NSColor) {
        fill.backgroundColor = color.cgColor
        guard !dragging else { return }
        // Only restart the animation when the playback state really changed.
        let changed = lastSnapshot != snapshot || self.isPlaying != isPlaying || self.duration != duration
        self.duration = duration
        self.isPlaying = isPlaying
        lastSnapshot = snapshot
        progress = duration > 0 ? min(max(position / duration, 0), 1) : 0
        if changed { applyProgress(restart: true) }
    }

    private func applyProgress(restart: Bool) {
        guard restart else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.removeAnimation(forKey: "progress")
        fill.transform = CATransform3DMakeScale(CGFloat(isPlaying && duration > 0 ? 1 : progress), 1, 1)
        if isPlaying, duration > 0, progress < 1 {
            let animation = CABasicAnimation(keyPath: "transform.scale.x")
            animation.fromValue = progress
            animation.toValue = 1
            animation.duration = max(0.01, duration * (1 - progress))
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 10)
            fill.add(animation, forKey: "progress")
        }
        CATransaction.commit()
    }

    // MARK: Dragging

    private func setProgress(from event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        progress = bounds.width > 0 ? min(max(Double(x / bounds.width), 0), 1) : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.removeAnimation(forKey: "progress")
        fill.transform = CATransform3DMakeScale(CGFloat(progress), 1, 1)
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        dragging = true
        layoutBars(animated: true)
        setProgress(from: event)
    }

    override func mouseDragged(with event: NSEvent) {
        setProgress(from: event)
    }

    override func mouseUp(with event: NSEvent) {
        setProgress(from: event)
        dragging = false
        layoutBars(animated: true)
        onSeek?(progress * duration)
        applyProgress(restart: true)
    }
}

struct IslandArtView: View {
    @ObservedObject var musicManager = MusicManager.shared
    let albumArtNamespace: Namespace.ID

    private let size: CGFloat = 48
    private let radius: CGFloat = 12

    var body: some View {
        ZStack {
            if Defaults[.lightingEffect] {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: size, height: size)
                    .blur(radius: 28)
                    .drawingGroup()
                    .opacity(musicManager.isPlaying ? 0.35 : 0)
            }
            Button {
                musicManager.openMusicApp()
            } label: {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(musicManager.isPlaying ? 1 : 0.9)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: musicManager.isPlaying)
        }
        .frame(width: size, height: size)
    }
}

struct IslandPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// MARK: - Main View

struct NotchHomeView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        MusicPlayerView(albumArtNamespace: albumArtNamespace)
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            .opacity(vm.notchState == .closed ? 0 : 1)
    }
}
