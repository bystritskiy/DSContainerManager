import SwiftUI

struct FluidPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.1)
                    : .spring(response: 0.22, dampingFraction: 1),
                value: configuration.isPressed,
            )
    }
}
