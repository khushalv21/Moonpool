//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false

    @State private var gestureProgress: CGFloat = .zero
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeFired = false
    @State private var swipeDir: CGFloat = 0
    @State private var swipeProgress: CGFloat = 0
    @State private var glyphScale: CGFloat = 1
    @State private var swipeResetTask: Task<Void, Never>?
    @State private var swipeReleaseTask: Task<Void, Never>?
    @State private var playFlash = false
    @State private var playFlashTask: Task<Void, Never>?

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)

    private func labelWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width
    }

    /// Wings hug their content so the pill is no wider than its text and battery.
    private var batteryWingWidth: CGFloat {
        let label = BatteryEvent(statusText: batteryModel.statusText, level: batteryModel.levelBattery).label
        let glyph: CGFloat = 72  // percentage, gap, battery
        return (max(labelWidth(label) + 4, glyph) + 2).rounded(.up)
    }

    private var lockWingWidth: CGFloat { max(0, vm.effectiveClosedNotchHeight - 12) + 8 }
    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    private var topCornerRadius: CGFloat {
       ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.top
                : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.lockTransition != nil && vm.notchState == .closed {
            chinWidth += 2 * lockWingWidth
        } else if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth += 2 * batteryWingWidth
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(width: vm.notchState == .open ? openNotchSize.width - 40 : nil, alignment: .top)
                    .padding(
                        .horizontal,
                        vm.notchState == .open
                        ? cornerRadiusInsets.opened.top + 20
                        : cornerRadiusInsets.closed.bottom
                    )
                    .padding(.bottom, vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .background {
                        currentNotchShape
                            .fill(.black)
                            .shadow(
                                color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                                    ? .black.opacity(0.7) : .clear,
                                radius: Defaults[.cornerRadiusScaling] ? 6 : 4)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .padding(
                        .bottom,
                        vm.effectiveClosedNotchHeight == 0 ? 10 : 0
                    )
                
                mainLayout
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                        let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
                        
                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .scaleEffect(isHovering && vm.notchState == .closed && vm.hasContent ? 1.05 : 1, anchor: .top)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .horizontalSwipe { translation, phase in
                        handleSwipe(translation: translation, phase: phase)
                    }
                    .onChange(of: musicManager.isPlaying) { _, playing in
                        guard playing else {
                            playFlashTask?.cancel()
                            playFlash = false
                            return
                        }
                        // Resuming: show a play glyph for a moment before the bars take over.
                        playFlash = true
                        playFlashTask?.cancel()
                        playFlashTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(750))
                            guard !Task.isCancelled else { return }
                            playFlash = false
                        }
                    }
                    .onChange(of: musicManager.isPlayerIdle) {
                        if vm.notchState == .open && !vm.hasContent { vm.close() }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if let lockKind = coordinator.lockTransition, vm.notchState == .closed {
                    LockActivity(kind: lockKind)
                } else if coordinator.expandingView.type == .battery && coordinator.expandingView.show
                    && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
                {
                    BatteryEventActivity()
                } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
                    && vm.notchState == .closed
                    && (musicManager.isPlaying || !musicManager.isPlayerIdle)
                    && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
                {
                    MusicLiveActivity()
                        .frame(alignment: .center)
                        .offset(x: swipeOffset)
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                } else if vm.notchState == .open {
                    Color.clear
                        .frame(height: max(24, vm.effectiveClosedNotchHeight))
                } else {
                    Rectangle().fill(.clear)
                        .frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                }
            }
            .zIndex(2)
            if vm.notchState == .open {
                VStack {
                    NotchHomeView(albumArtNamespace: albumArtNamespace)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(
                    .scale(scale: 0.94, anchor: .top)
                    .combined(with: .opacity)
                    .animation(.smooth(duration: 0.35))
                )
                .zIndex(1)
                .allowsHitTesting(vm.notchState == .open)
                .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
            }
        }
    }

    @ViewBuilder
    func BatteryEventActivity() -> some View {
        let event = BatteryEvent(statusText: batteryModel.statusText, level: batteryModel.levelBattery)
        HStack(spacing: 0) {
            Text(event.label)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.1)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .frame(width: batteryWingWidth, alignment: .leading)
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top)
            BatteryEventGlyph(event: event)
                .frame(width: batteryWingWidth, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .id(event.label)
        .transition(.opacity)
    }

    @ViewBuilder
    func LockActivity(kind: LockTransition) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: lockWingWidth)
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top)
            LockGlyph(kind: kind)
                .frame(width: lockWingWidth, alignment: .trailing)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }

    /// Wing width that fits the longer of title and artist, so the pill hugs its content.
    private func popupWing(side: CGFloat) -> CGFloat {
        let title = (musicManager.songTitle as NSString)
            .size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]).width
        let artist = (musicManager.artistName as NSString)
            .size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width
        // art + gap on the left; bars + gap on the right; 4 pt slack for tracking
        let content = max(title + side + 8, artist + 18 + 8) + 4
        // The pill must fit inside the notch window, otherwise its corners and edges get cut off.
        let fixed = (vm.closedNotchSize.width - cornerRadiusInsets.closed.top)
            + 2 * cornerRadiusInsets.closed.bottom
        let limit = ((windowSize.width - fixed) / 2).rounded(.down) - 2
        return min(max(content.rounded(.up), 84), min(limit, 106))
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        let side = max(0, vm.effectiveClosedNotchHeight - 12)
        let showing = coordinator.expandingView.show && coordinator.expandingView.type == .music
        let tint: Color = Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.7)
        let wing: CGFloat = showing ? popupWing(side: side) : side + 8

        HStack(spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    Image(nsImage: musicManager.albumArt)
                        .resizable()
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed,
                                style: .continuous)
                        )
                        .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                        .frame(width: side, height: side)
                        .id(musicManager.songTitle)
                        .transition(.roll(delay: 0))
                        .opacity((swipeDir > 0 ? 1 - swipeProgress : 1) * (musicManager.isPlaying ? 1 : 0.55))
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .opacity(swipeDir > 0 ? swipeProgress : 0)
                        .scaleEffect(glyphScale)
                }
                .frame(width: side, height: side)
                if showing {
                    Text(musicManager.songTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(musicManager.songTitle)
                        .transition(.roll(delay: 0.05))
                }
            }
            .frame(width: wing, alignment: .leading)
            .clipped()

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top)

            HStack(spacing: 8) {
                if showing {
                    Text(musicManager.artistName)
                        .font(.system(size: 13))
                        .tracking(-0.1)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(musicManager.songTitle + musicManager.artistName)
                        .transition(.roll(delay: 0.09))
                }
                ZStack {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 50, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                .frame(width: 18, height: 14)
                        }
                        .opacity((swipeDir < 0 ? 1 - swipeProgress : 1) * (musicManager.isPlaying && !playFlash ? 1 : 0))
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .opacity(playFlash && musicManager.isPlaying ? 1 : 0)
                        .scaleEffect(playFlash && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0.8)
                        .accessibilityLabel("Playing")
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .opacity(musicManager.isPlaying ? 0 : 1)
                        .scaleEffect(musicManager.isPlaying && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.8 : 1)
                        .accessibilityLabel("Paused")
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .opacity(swipeDir < 0 ? swipeProgress : 0)
                        .scaleEffect(glyphScale)
                }
                .frame(width: max(0, side + gestureProgress / 2), height: side)
            }
            .frame(width: wing, alignment: .trailing)
            .clipped()
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showing)
        .animation(.smooth(duration: 0.25), value: musicManager.songTitle)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: musicManager.isPlaying)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: playFlash)
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open {
                        self.vm.close()
                    }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    /// Swipe left = next track, right = previous. The pill content follows the finger with a rubber band
    /// (capped at 10 pt) while a skip glyph fades in on the opposite side. Past the threshold it skips once,
    /// the glyph pulses, holds for a moment, then everything eases back.
    private func handleSwipe(translation: CGFloat, phase: NSEvent.Phase) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        // After a skip, ignore the rest of the same physical swipe, including the trackpad's momentum tail,
        // which keeps sending scroll events after the fingers lift. The latch is only released once the
        // events have been quiet for 450 ms, so one swipe can never skip twice.
        if swipeFired {
            scheduleSwipeRelease()
            return
        }

        if phase == .ended {
            if swipeProgress < 1 { resetSwipe(holdFor: 0) }
            return
        }

        guard vm.notchState == .closed, vm.hasContent, coordinator.lockTransition == nil,
              !coordinator.expandingView.show || coordinator.expandingView.type == .music else { return }

        swipeResetTask?.cancel()
        let distance = abs(translation)
        swipeDir = translation < 0 ? -1 : 1
        swipeProgress = min(distance / 36, 1)
        if !reduceMotion {
            let limit: CGFloat = 10, c: CGFloat = 0.55
            swipeOffset = swipeDir * (distance * limit * c) / (limit + c * distance)
        }

        guard distance >= 36 else { return }
        swipeFired = true
        if Defaults[.enableHaptics] { strongHaptic() }
        if swipeDir < 0 {
            MusicManager.shared.nextTrack()
        } else {
            MusicManager.shared.previousTrack()
        }
        if !reduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { glyphScale = 1.25 }
        }
        resetSwipe(holdFor: 0.65)
        scheduleSwipeRelease()
    }

    private func scheduleSwipeRelease() {
        swipeReleaseTask?.cancel()
        swipeReleaseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            swipeFired = false
        }
    }

    /// Eases the swipe cue back. After a committed skip it first settles the pulse and holds the glyph so it can be seen.
    private func resetSwipe(holdFor hold: Double) {
        swipeResetTask?.cancel()
        swipeResetTask = Task { @MainActor in
            if hold > 0 {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { glyphScale = 1 }
                try? await Task.sleep(for: .milliseconds(Int(hold * 1000) - 200))
                guard !Task.isCancelled else { return }
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { swipeOffset = 0 }
            withAnimation(.easeOut(duration: 0.4)) { swipeProgress = 0 }
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            swipeDir = 0
        }
    }

    /// The strongest pattern the trackpad offers (.levelChange), struck twice 45 ms apart so it reads as one firm thump.
    private func strongHaptic() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(45))
            performer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            gestureProgress = .zero
            vm.close()

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }
}

enum BatteryEventKind {
    case pluggedIn, onBattery, charging, notCharging, fullyCharged, lowBattery, lowPower
}

struct BatteryEvent {
    let kind: BatteryEventKind
    let label: String
    /// Small mark drawn on the battery. Colour is never the only signal.
    let mark: String?
    let tint: Color
    let level: Float

    init(statusText: String, level: Float) {
        self.level = level
        switch statusText {
        case "Plugged In":
            kind = .pluggedIn; label = "Plugged in"; mark = "powerplug.fill"; tint = .white
        case "Unplugged":
            kind = .onBattery; label = "On battery"
            mark = level <= 20 ? "exclamationmark.triangle.fill" : nil
            tint = level <= 20 ? .red : .white
        case "Charging battery":
            kind = .charging; label = "Charging"; mark = "bolt.fill"; tint = .green
        case "Not charging":
            kind = .notCharging; label = "Not charging"; mark = "powerplug.fill"; tint = .white
        case "Full charge":
            kind = .fullyCharged; label = "Fully charged"; mark = "checkmark"; tint = .green
        case "Low battery":
            kind = .lowBattery; label = "Low battery"; mark = "exclamationmark.triangle.fill"; tint = .red
        default:
            kind = .lowPower; label = statusText.replacingOccurrences(of: ":", with: "")
            mark = nil; tint = .yellow
        }
    }
}

/// Battery drawn from shapes: the fill sweeps up to the real level, the percentage rolls up with it,
/// and the mark (bolt, plug, check, warning) lands once. Nothing loops.
struct BatteryEventGlyph: View {
    let event: BatteryEvent
    @State private var shownLevel: CGFloat = 0
    @State private var markShown = false
    @State private var markScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let bodyWidth: CGFloat = 28
    private let bodyHeight: CGFloat = 13
    private let inset: CGFloat = 2.5

    var body: some View {
        HStack(spacing: 7) {
            Text("\(Int(shownLevel))%")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(shownLevel)))

            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(event.tint)
                        .frame(
                            width: max(bodyHeight - 2 * inset, (bodyWidth - 2 * inset) * shownLevel / 100),
                            height: bodyHeight - 2 * inset
                        )
                        .padding(.leading, inset)
                    if let mark = event.mark {
                        Image(systemName: mark)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.65), radius: 1.5)
                            .frame(width: bodyWidth)
                            .scaleEffect(markScale)
                            .opacity(markShown ? 1 : 0)
                    }
                }
                .frame(width: bodyWidth, height: bodyHeight)
                Capsule()
                    .fill(.white.opacity(0.55))
                    .frame(width: 2, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.label), \(Int(event.level)) percent")
        .task {
            let level = CGFloat(event.level)
            if reduceMotion {
                shownLevel = level
                markShown = true
                return
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 1)) { shownLevel = level }
            let delay: Duration = event.kind == .fullyCharged ? .milliseconds(560) : .milliseconds(200)
            try? await Task.sleep(for: delay)
            withAnimation(.easeOut(duration: 0.25)) { markShown = true }
            if event.kind == .charging {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { markScale = 1.25 }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { markScale = 1 }
            }
        }
    }
}

private struct ShacklePath: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 20
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
        var p = Path()
        p.move(to: pt(6, 9))
        p.addLine(to: pt(6, 6.2))
        p.addCurve(to: pt(10, 2.2), control1: pt(6, 4.0), control2: pt(7.8, 2.2))
        p.addCurve(to: pt(14, 6.2), control1: pt(12.2, 2.2), control2: pt(14, 4.0))
        p.addLine(to: pt(14, 9))
        return p
    }
}

/// One padlock, always white. Locking: the shackle drops and the body presses in. Unlocking: it lifts and swings open.
struct LockGlyph: View {
    let kind: LockTransition
    @State private var shut: Bool
    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: LockTransition) {
        self.kind = kind
        _shut = State(initialValue: kind == .unlocking)
    }

    var body: some View {
        ZStack {
            ShacklePath()
                .stroke(.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .rotationEffect(.degrees(shut ? 0 : -38), anchor: UnitPoint(x: 0.7, y: 0.45))
                .offset(y: shut ? 0 : -4.5)
            // Solid when locked, hollow when unlocked: a state cue that needs no colour.
            ZStack {
                RoundedRectangle(cornerRadius: 2.6, style: .continuous)
                    .fill(.white)
                    .opacity(shut ? 1 : 0)
                    .animation(.easeOut(duration: 0.42).delay(shut ? 0.12 : 0), value: shut)
                RoundedRectangle(cornerRadius: 2.6, style: .continuous)
                    .strokeBorder(.white, lineWidth: 1.8)
            }
            .frame(width: 13, height: 8.5)
            .offset(y: 3.25 + (pressed ? 0.5 : 0))
        }
        .frame(width: 20, height: 20)
        .scaleEffect(1.1)
        .accessibilityLabel(kind == .locking ? "Locked" : "Unlocked")
        .task {
            if reduceMotion {
                shut = (kind == .locking)
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(response: kind == .locking ? 0.32 : 0.4, dampingFraction: 0.66)) {
                shut = (kind == .locking)
            }
            if kind == .locking {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeOut(duration: 0.08)) { pressed = true }
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = false }
            }
        }
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}

/// Track-change roll: the new content rises 12 pt from below with a short stagger; the old one simply fades.
private struct RollOffset: ViewModifier {
    var y: CGFloat
    func body(content: Content) -> some View { content.offset(y: y) }
}

extension AnyTransition {
    static func roll(delay: Double) -> AnyTransition {
        .asymmetric(
            insertion: AnyTransition
                .modifier(active: RollOffset(y: 12), identity: RollOffset(y: 0))
                .combined(with: .opacity)
                .animation(.spring(response: 0.34, dampingFraction: 1).delay(delay)),
            removal: AnyTransition.opacity.animation(.easeOut(duration: 0.1))
        )
    }
}
