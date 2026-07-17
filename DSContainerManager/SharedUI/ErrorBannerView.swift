import SwiftUI

struct ErrorBannerView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let retryAction {
                Button("Retry", action: retryAction)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    VStack(spacing: 16) {
        ErrorBannerView("Failed to load containers")
        ErrorBannerView("Network connection lost") {
            print("Retry tapped")
        }
    }
    .padding()
}
