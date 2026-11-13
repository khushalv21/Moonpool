import Defaults
import SwiftUI

/// Colour for a battery state. Always paired with a glyph or text, never the only signal.
func batteryTint(level: Float, isCharging: Bool, isPluggedIn: Bool, isInLowPowerMode: Bool) -> Color {
    if isInLowPowerMode { return .yellow }
    if isCharging || isPluggedIn { return .green }
    if level <= 20 { return .red }
    return .white
}

/// Battery drawn from shapes so the level, outline and status icon stay concentric at any size.
struct BatteryGlyph: View {
    var level: Float
    var isCharging: Bool
    var isPluggedIn: Bool
    var isInLowPowerMode: Bool
    var width: CGFloat = 30

    private var height: CGFloat { width * 0.46 }
    private var bodyWidth: CGFloat { width * 0.92 }
    private var inset: CGFloat { max(1.5, height * 0.12) }
    private var outerRadius: CGFloat { height * 0.32 }
    private var tint: Color {
        batteryTint(
            level: level, isCharging: isCharging, isPluggedIn: isPluggedIn,
            isInLowPowerMode: isInLowPowerMode)
    }

    private var fillWidth: CGFloat {
        let inner = bodyWidth - 2 * inset
        let minimum = height - 2 * inset
        return max(minimum, inner * CGFloat(min(max(level, 0), 100)) / 100)
    }

    var body: some View {
        HStack(spacing: width * 0.03) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                RoundedRectangle(cornerRadius: max(0, outerRadius - inset), style: .continuous)
                    .fill(tint)
                    .frame(width: fillWidth, height: height - 2 * inset)
                    .padding(.leading, inset)
                    .animation(.smooth, value: level)
                if isCharging || isPluggedIn {
                    Image(systemName: isCharging ? "bolt.fill" : "powerplug.fill")
                        .font(.system(size: height * 0.6, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 1.5)
                        .frame(width: bodyWidth)
                        .transition(.opacity)
                }
            }
            .frame(width: bodyWidth, height: height)

            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: width * 0.06, height: height * 0.38)
        }
        .animation(.smooth, value: isCharging)
        .animation(.smooth, value: isPluggedIn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(Int(level)) percent")
        .accessibilityValue(isCharging ? "Charging" : (isPluggedIn ? "Plugged in" : "On battery"))
    }
}

/// Battery level and charging state in the open notch.
struct BoringBatteryView: View {
    @State var batteryWidth: CGFloat = 26
    var isCharging: Bool = false
    var isInLowPowerMode: Bool = false
    var isPluggedIn: Bool = false
    var levelBattery: Float = 0
    var maxCapacity: Float = 0
    var timeToFullCharge: Int = 0
    @State var isForNotification: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if Defaults[.showBatteryPercentage] {
                Text("\(Int(levelBattery))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            BatteryGlyph(
                level: levelBattery, isCharging: isCharging, isPluggedIn: isPluggedIn,
                isInLowPowerMode: isInLowPowerMode, width: batteryWidth)
        }
    }
}

#Preview {
    BoringBatteryView(
        batteryWidth: 30,
        isCharging: true,
        isInLowPowerMode: false,
        isPluggedIn: true,
        levelBattery: 80,
        maxCapacity: 100,
        timeToFullCharge: 10,
        isForNotification: false
    )
    .environmentObject(BoringViewModel())
    .padding()
    .background(.black)
}
