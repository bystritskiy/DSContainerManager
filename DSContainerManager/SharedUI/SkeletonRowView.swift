import SwiftUI

struct SkeletonRowView: View {
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
        ForEach(0 ..< 5) { _ in
            SkeletonRowView()
        }
    }
}
