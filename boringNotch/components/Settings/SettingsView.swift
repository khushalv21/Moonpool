//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Defaults
import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            NotchSettings()
                .tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }
            MusicSettings()
                .tabItem { Label("Music", systemImage: "music.note") }
            BatterySettings()
                .tabItem { Label("Battery", systemImage: "battery.100percent") }
        }
        .frame(width: 480, height: 460)
        .tint(.effectiveAccent)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .menubarIcon) {
                    Text("Show in menu bar")
                }
                LaunchAtLogin.Toggle("Open at login")
            }

            Section {
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(showOnAllDisplays)
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Follow the active display")
                }
                .onChange(of: automaticallySwitchDisplay) {
                    NotificationCenter.default.post(
                        name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                }
                .disabled(showOnAllDisplays)
            } header: {
                Text("Displays")
            } footer: {
                Text("The notch appears on every display, or only on the one you choose.")
            }

            Section {
                Button("Quit Moonpool", role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notch

private struct NotchSettings: View {
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.nonNotchHeight) var nonNotchHeight

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableHaptics) {
                    Text("Haptic feedback")
                }
            } header: {
                Text("Opening")
            } footer: {
                Text("Hovering gives a small nudge. Click the notch or swipe down to open it.")
            }

            Section {
                Defaults.Toggle(key: .lockAnimation) {
                    Text("Lock and unlock animation")
                }
                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Keep visible on the lock screen")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recording")
                }
            } header: {
                Text("Behaviour")
            }

            Section {
                Picker("Notch displays", selection: $notchHeightMode) {
                    Text("Match the notch").tag(WindowHeightMode.matchRealNotchSize)
                    Text("Match the menu bar").tag(WindowHeightMode.matchMenuBar)
                    Text("Custom").tag(WindowHeightMode.custom)
                }
                .onChange(of: notchHeightMode) {
                    switch notchHeightMode {
                    case .matchRealNotchSize, .custom: notchHeight = 38
                    case .matchMenuBar: notchHeight = 44
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Height")
                    }
                    .onChange(of: notchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Other displays", selection: $nonNotchHeightMode) {
                    Text("Match the menu bar").tag(WindowHeightMode.matchMenuBar)
                    Text("Match the notch").tag(WindowHeightMode.matchRealNotchSize)
                    Text("Custom").tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar: nonNotchHeight = 24
                    case .matchRealNotchSize, .custom: nonNotchHeight = 32
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Height")
                    }
                    .onChange(of: nonNotchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
            } header: {
                Text("Height")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Music

private struct MusicSettings: View {
    @Default(.sliderColor) var sliderColor

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .playerColorTinting) {
                    Text("Tint text with the album colour")
                }
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colour the visualizer")
                }
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Glow behind the album art")
                }
                Picker("Progress bar", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue)
                    }
                }
            } header: {
                Text("Appearance")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Battery

private struct BatterySettings: View {
    @ObservedObject var battery = BatteryStatusViewModel.shared
    @Default(.showBatteryIndicator) var showIndicator
    @Default(.showBatteryPercentage) var showPercentage

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Right now")
                    Spacer()
                    HStack(spacing: 6) {
                        if showIndicator && showPercentage {
                            Text("\(Int(battery.levelBattery))%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        if showIndicator {
                            BatteryGlyph(
                                level: battery.levelBattery,
                                isCharging: battery.isCharging,
                                isPluggedIn: battery.isPluggedIn,
                                isInLowPowerMode: battery.isInLowPowerMode,
                                width: 30)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black))
                    .foregroundStyle(.white)
                }
            } header: {
                Text("Preview")
            }

            Section {
                Defaults.Toggle(key: .showBatteryIndicator) {
                    Text("Show the battery in the open notch")
                }
                Defaults.Toggle(key: .showBatteryPercentage) {
                    Text("Show the percentage")
                }
                .disabled(!showIndicator)
            } header: {
                Text("Open notch")
            }

            Section {
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Show power changes")
                }
            } header: {
                Text("Closed notch")
            } footer: {
                Text("A short popup when you plug in, unplug, finish charging, or change Low Power Mode.")
            }
        }
        .formStyle(.grouped)
    }
}
