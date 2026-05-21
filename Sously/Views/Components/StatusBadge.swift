import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

extension StockStatus {
    var color: Color {
        switch self {
        case .inStock: .green
        case .low: .orange
        case .out: .red
        }
    }
}

extension ExpirationStatus {
    var color: Color {
        switch self {
        case .fresh: .green
        case .expiringSoon: .orange
        case .expired: .red
        }
    }
}
