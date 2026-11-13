//
//  AppleMusicController.swift
//  boringNotch
//
//  Created by Alexander on 2025-03-29.
//

import Foundation
import Combine
import SwiftUI

class AppleMusicController: MediaControllerProtocol {
    // MARK: - Properties
    @Published private var playbackState: PlaybackState = PlaybackState(
        bundleIdentifier: "com.apple.Music",
        playbackRate: 1
    )
    
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }


    private var notificationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init() {
        setupPlaybackStateChangeObserver()
        Task {
            if isActive() {
                await updatePlaybackInfo()
            }
        }
    }
    
    private func setupPlaybackStateChangeObserver() {
        notificationTask = Task { @Sendable [weak self] in
            let notifications = DistributedNotificationCenter.default().notifications(
                named: NSNotification.Name("com.apple.Music.playerInfo")
            )
            
            for await _ in notifications {
                await self?.updatePlaybackInfo()
            }
        }
    }
    
    deinit {
        notificationTask?.cancel()
    }
    
    // MARK: - Protocol Implementation
    func play() async {
        await executeCommand("play")
    }
    
    func pause() async {
        await executeCommand("pause")
    }
    
    func togglePlay() async {
        await executeCommand("playpause")
    }
    
    func nextTrack() async {
        await executeCommand("next track")
    }
    
    func previousTrack() async {
        await executeCommand("previous track")
    }
    
    func seek(to time: Double) async {
        await executeCommand("set player position to \(time)")
        await updatePlaybackInfo()
    }
    
    func isActive() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    func updatePlaybackInfo() async {
        // Never script Music while it is closed: AppleScript would launch it again.
        guard isActive() else {
            var stopped = playbackState
            stopped.isPlaying = false
            stopped.lastUpdated = Date()
            playbackState = stopped
            return
        }
        // Artwork is the heavy part of the query, so only ask for it when the track changed.
        let includeArtwork = playbackState.artwork == nil || playbackState.trackKey != lastArtworkKey
        guard let descriptor = try? await fetchPlaybackInfoAsync(includeArtwork: includeArtwork) else { return }
        guard descriptor.numberOfItems >= 7 else { return }
        var updatedState = self.playbackState

        updatedState.isPlaying = descriptor.atIndex(1)?.booleanValue ?? false
        updatedState.title = descriptor.atIndex(2)?.stringValue ?? "Unknown"
        updatedState.artist = descriptor.atIndex(3)?.stringValue ?? "Unknown"
        updatedState.album = descriptor.atIndex(4)?.stringValue ?? "Unknown"
        updatedState.currentTime = descriptor.atIndex(5)?.doubleValue ?? 0
        updatedState.duration = descriptor.atIndex(6)?.doubleValue ?? 0
        if includeArtwork {
            updatedState.artwork = descriptor.atIndex(7)?.data as Data?
            lastArtworkKey = updatedState.trackKey
        }
        updatedState.lastUpdated = Date()
        self.playbackState = updatedState
    }

    // MARK: - Private Methods

    private var lastArtworkKey: String?

    private func executeCommand(_ command: String) async {
        let script = "tell application \"Music\" to \(command)"
        try? await AppleScriptHelper.executeVoid(script)
    }

    private func fetchPlaybackInfoAsync(includeArtwork: Bool) async throws -> NSAppleEventDescriptor? {
        let artworkBlock = includeArtwork
            ? """
                try
                    set artData to data of artwork 1 of current track
                on error
                    set artData to ""
                end try
            """
            : "set artData to \"\""
        let script = """
        tell application "Music"
            try
                set playerState to player state is playing
                set currentTrackName to name of current track
                set currentTrackArtist to artist of current track
                set currentTrackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                \(artworkBlock)
                return {playerState, currentTrackName, currentTrackArtist, currentTrackAlbum, trackPosition, trackDuration, artData}
            on error
                return {false, "Not Playing", "Unknown", "Unknown", 0, 0, ""}
            end try
        end tell
        """

        return try await AppleScriptHelper.execute(script)
    }

}
