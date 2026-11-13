//
//  MusicVisualizer.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//
import AppKit
import Cocoa
import SwiftUI

/// Four bars animated entirely by Core Animation: no timers, so the app does not wake up to draw them.
final class AudioSpectrum: NSView {
    private let barCount = 4
    private let barWidth: CGFloat = 3
    private let barHeight: CGFloat = 14
    private let restScale: CGFloat = 0.35
    private var barLayers: [CALayer] = []
    private var isPlaying = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        let spacing: CGFloat = 2
        frame.size = CGSize(width: CGFloat(barCount) * (barWidth + spacing), height: barHeight)
        for i in 0..<barCount {
            let bar = CALayer()
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: barHeight)
            bar.position = CGPoint(
                x: CGFloat(i) * (barWidth + spacing) + barWidth / 2, y: barHeight / 2)
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = barWidth / 2
            bar.transform = CATransform3DMakeScale(1, restScale, 1)
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Animations are dropped when a layer leaves the screen, so restart them on return.
        if window != nil, isPlaying { startAnimating() }
    }

    private func startAnimating() {
        guard window != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            for bar in barLayers { bar.transform = CATransform3DMakeScale(1, 0.7, 1) }
            return
        }
        for bar in barLayers {
            bar.removeAllAnimations()
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = restScale
            animation.toValue = CGFloat.random(in: 0.75...1.0)
            animation.duration = Double.random(in: 0.28...0.52)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.timeOffset = Double.random(in: 0...0.5)
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 24)
            bar.add(animation, forKey: "scaleY")
        }
    }

    private func stopAnimating() {
        for bar in barLayers {
            bar.removeAllAnimations()
            bar.transform = CATransform3DMakeScale(1, restScale, 1)
        }
    }

    func setPlaying(_ playing: Bool) {
        guard playing != isPlaying else { return }
        isPlaying = playing
        playing ? startAnimating() : stopAnimating()
    }
}

struct AudioSpectrumView: NSViewRepresentable {
    @Binding var isPlaying: Bool
    
    func makeNSView(context: Context) -> AudioSpectrum {
        let spectrum = AudioSpectrum()
        spectrum.setPlaying(isPlaying)
        return spectrum
    }
    
    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        nsView.setPlaying(isPlaying)
    }
}

#Preview {
    AudioSpectrumView(isPlaying: .constant(true))
        .frame(width: 16, height: 20)
        .padding()
}
