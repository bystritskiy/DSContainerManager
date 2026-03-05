import SwiftUI

struct ErrorBanner: View {
    let message: String
    let retryAction: (() -> Void)?

    init(_ message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

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
    }
}

#Preview {
    VStack(spacing: 16) {
        ErrorBanner("Failed to load containers")
        ErrorBanner("Network connection lost") {
            print("Retry tapped")
        }
    }
    .padding()
}
