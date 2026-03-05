import SwiftUI

struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat

    @State private var isAnimating = false

    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 3)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.15), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
            )
            .clipShape(RoundedRectangle(cornerRadius: height / 3))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 120, height: 14)
                SkeletonView(width: 200, height: 12)
            }
            Spacer()
            SkeletonView(width: 60, height: 20)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ForEach(0..<5) { _ in
            SkeletonRow()
        }
    }
}
