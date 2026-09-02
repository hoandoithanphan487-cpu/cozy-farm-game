import SwiftUI

/// Player-facing bridge between the runtime pixel landmark and the complete
/// N-014 HD cat-shop set. This view is presentation-only and owns no game state.
struct CatBbqArtTourView: View {
    let scale: CGFloat
    let onClose: () -> Void

    private let ink = Color(red: 0.96, green: 0.94, blue: 0.84)
    private let copper = Color(red: 0.88, green: 0.50, blue: 0.23)
    private let panel = Color(red: 0.08, green: 0.11, blue: 0.10)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()

                VStack(spacing: 12 * scale) {
                    HStack(spacing: 10 * scale) {
                        if let pixelShop = WorldLifeCatalog.image(for: .catBbqShop) {
                            Image(nsImage: pixelShop)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 86 * scale, height: 70 * scale)
                                .accessibilityLabel("溪火猫食铺像素造型")
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("溪火猫食铺 · 美术巡礼")
                                .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                            Text("地图采用像素运行层；本页展示店铺与三名猫店员的完整高清美术。")
                                .font(.system(size: 12 * scale, weight: .medium, design: .rounded))
                                .opacity(0.78)
                        }
                        Spacer()
                        Button("关闭  Esc", action: onClose)
                            .buttonStyle(.borderedProminent)
                            .tint(copper)
                            .accessibilityIdentifier("n019.cat-shop-tour.close")
                    }

                    HStack(spacing: 12 * scale) {
                        CatBbqArtCard(kind: .catBbqShop, featured: true, scale: scale)
                            .frame(maxWidth: .infinity)
                        VStack(spacing: 8 * scale) {
                            ForEach(
                                [WorldLifeKind.catBlack, .catCalico, .catRagdoll],
                                id: \.rawValue
                            ) { kind in
                                CatBbqArtCard(kind: kind, featured: false, scale: scale)
                            }
                        }
                        .frame(width: min(geometry.size.width * 0.31, 280 * scale))
                    }
                }
                .foregroundStyle(ink)
                .padding(18 * scale)
                .frame(
                    width: min(geometry.size.width - 48, 980 * scale),
                    height: min(geometry.size.height - 40, 650 * scale)
                )
                .background(panel.opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: 18 * scale))
                .overlay(
                    RoundedRectangle(cornerRadius: 18 * scale)
                        .stroke(copper.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.5), radius: 24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("n019.cat-shop-tour")
    }
}

struct CatBbqVisitCard: View {
    let scale: CGFloat
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10 * scale) {
                if let image = WorldLifeCatalog.image(for: .catBbqShop) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 96 * scale, height: 76 * scale)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("溪火猫食铺")
                        .font(.system(size: 15 * scale, weight: .bold, design: .rounded))
                    Text("查看店铺与三名猫店员")
                        .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                        .opacity(0.78)
                    Text("点击或按 J · 美术巡礼")
                        .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.96, green: 0.66, blue: 0.32))
                }
            }
            .foregroundStyle(Color.white)
            .padding(10 * scale)
            .background(Color(red: 0.06, green: 0.09, blue: 0.08).opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale))
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scale)
                    .stroke(Color(red: 0.88, green: 0.50, blue: 0.23), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("溪火猫食铺，美术巡礼")
        .accessibilityIdentifier("n019.cat-shop-tour.open")
    }
}

private struct CatBbqArtCard: View {
    let kind: WorldLifeKind
    let featured: Bool
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 12 * scale)
                .fill(Color.white.opacity(0.05))
            if let image = WorldLifeCatalog.catBbqHDImage(for: kind) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(featured ? 8 * scale : 4 * scale)
            } else {
                Text("美术资源未加载")
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(WorldLifeCatalog.displayName(for: kind))
                .font(.system(
                    size: (featured ? 16 : 13) * scale,
                    weight: .bold,
                    design: .rounded
                ))
                .padding(.horizontal, 10 * scale)
                .padding(.vertical, 6 * scale)
                .background(Color.black.opacity(0.68))
                .clipShape(RoundedRectangle(cornerRadius: 7 * scale))
                .padding(8 * scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scale)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
        .accessibilityLabel(WorldLifeCatalog.displayName(for: kind))
    }
}
