import SwiftUI

enum PocoAdPlacement: String, Sendable {
    case app
}

struct PocoAdPlacementView: View {
    @Environment(PocoStore.self) private var store
    @State private var showsMembership = false
    let placement: PocoAdPlacement

    var body: some View {
        if store.capabilities.shouldShowAds {
            PocoAdBanner {
                showsMembership = true
            }
            .sheet(isPresented: $showsMembership) {
                PocoMembershipView()
            }
            .accessibilityIdentifier("poco-ad-\(placement.rawValue)")
        }
    }
}

struct PocoAdBanner: View {
    let onRemoveAds: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PocoTheme.bubble(.yellow).opacity(0.65))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "sparkles")
                        .foregroundStyle(PocoTheme.primary)
                }

            Text("スポンサー広告")
                .pocoFont(.caption, weight: .medium)
                .foregroundStyle(PocoTheme.secondaryText)

            Spacer(minLength: 8)

            Button("広告を消す", action: onRemoveAds)
                .pocoFont(.caption, weight: .medium)
                .foregroundStyle(PocoTheme.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("スポンサー広告。Poco Proになると広告を非表示にできます")
    }
}
