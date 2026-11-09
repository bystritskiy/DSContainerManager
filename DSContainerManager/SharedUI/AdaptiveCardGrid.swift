import SwiftUI

/// Lays dashboard-style cards out in as many columns as the available width allows.
///
/// On a regular iPhone (and the iPhone Duo cover display) this collapses to a single
/// column, identical to a `VStack`. On wide canvases — the unfolded iPhone Duo inner
/// display, landscape, or an iPad-width sidebar detail — cards flow into two or more
/// columns instead of stretching edge to edge.
struct AdaptiveCardGrid<Content: View>: View {
    var minimumColumnWidth: CGFloat = 300
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: spacing, alignment: .top)],
            alignment: .leading,
            spacing: spacing,
        ) {
            content
        }
    }
}

#Preview("Duo inner display", traits: .fixedLayout(width: 669, height: 951)) {
    ScrollView {
        AdaptiveCardGrid {
            ForEach(0 ..< 5) { index in
                RoundedRectangle(cornerRadius: 16)
                    .fill(.blue.opacity(0.2))
                    .frame(height: CGFloat(80 + index * 20))
            }
        }
        .padding()
    }
}
