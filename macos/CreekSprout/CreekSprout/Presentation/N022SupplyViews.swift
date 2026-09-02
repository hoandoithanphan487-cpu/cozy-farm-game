import SwiftUI

struct FarmAnimalCardSnapshot: Equatable, Identifiable, Sendable {
    var id: String
    var definitionID: String
    var name: String
    var speciesName: String
    var ageDays: Int
    var stageLabel: String
    var caredToday: Bool
    var isProtected: Bool
    var canSupply: Bool
    var supplyPrice: Int
}

struct CatShopOfferCardSnapshot: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case crop(itemID: String)
        case animal(definitionID: String)
    }

    var id: String
    var kind: Kind
    var name: String
    var unitPrice: Int
    var dailyLimit: Int
    var remaining: Int
    var ownedQuantity: Int
}

struct CatShopBoardSnapshot: Equatable, Sendable {
    var day: Int
    var balance: Int
    var offers: [CatShopOfferCardSnapshot]
    var animals: [FarmAnimalCardSnapshot]
    var latestReceiptText: String?
}

struct LivestockRosterView: View {
    let animals: [FarmAnimalCardSnapshot]
    let stamina: Int
    let scale: CGFloat
    let onCare: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14 * scale) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("农场动物名册")
                            .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                        Text("每日照料一次，每只消耗 \(LivestockCatalog.careStaminaCost) 点体力；漏照料不会生病或死亡。")
                            .font(.system(size: 13 * scale, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("体力 \(stamina)/100")
                        .font(.system(size: 15 * scale, weight: .semibold, design: .monospaced))
                    Button("关闭 [Esc]", action: onClose)
                }

                if animals.isEmpty {
                    ContentUnavailableView("圈舍暂时空着", systemImage: "leaf", description: Text("以后可以从畜牧扩展中补充动物。"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10 * scale) {
                            ForEach(animals) { animal in
                                HStack(spacing: 12 * scale) {
                                    VStack(alignment: .leading, spacing: 4 * scale) {
                                        Text("\(animal.name) · \(animal.speciesName)")
                                            .font(.system(size: 17 * scale, weight: .bold, design: .rounded))
                                        Text("\(animal.stageLabel) · 来农场 \(animal.ageDays) 天 · 累计照料 \(animal.caredToday ? "今日已照料" : "今日待照料")")
                                            .font(.system(size: 13 * scale, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Text(animal.isProtected
                                             ? "伙伴保护：不可供货"
                                             : "成年并在当日照料后，可到猫猫烧烤店供货。")
                                            .font(.system(size: 12 * scale, weight: .medium))
                                            .foregroundStyle(animal.isProtected ? .orange : .secondary)
                                    }
                                    Spacer()
                                    Button(animal.caredToday ? "今日已照料" : "照料 −2体力") {
                                        onCare(animal.id)
                                    }
                                    .disabled(animal.caredToday || stamina < LivestockCatalog.careStaminaCost)
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(12 * scale)
                                .background(Color.white.opacity(0.78))
                                .clipShape(RoundedRectangle(cornerRadius: 12 * scale))
                            }
                        }
                    }
                }
            }
            .padding(22 * scale)
            .frame(maxWidth: 820 * scale, maxHeight: 600 * scale)
            .background(Color(red: 0.91, green: 0.88, blue: 0.72))
            .clipShape(RoundedRectangle(cornerRadius: 18 * scale))
            .shadow(radius: 24)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("农场动物名册")
    }
}

struct CatShopSupplyView: View {
    let board: CatShopBoardSnapshot
    let scale: CGFloat
    let onSupplyCrop: (String, String, Int) -> Void
    let onSupplyAnimal: (String, String) -> Void
    let onShowArtTour: () -> Void
    let onClose: () -> Void

    @State private var pendingAnimalID: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.56).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12 * scale) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("溪火猫食铺 · 今日收购板")
                            .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                        Text("第 \(board.day) 天 · 供货成功后溪票立即到账")
                            .font(.system(size: 13 * scale, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("溪票 \(board.balance)")
                        .font(.system(size: 16 * scale, weight: .bold, design: .monospaced))
                    Button("美术巡礼", action: onShowArtTour)
                    Button("关闭 [Esc]", action: onClose)
                }

                if let latest = board.latestReceiptText {
                    Text(latest)
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .padding(8 * scale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14 * scale) {
                        Text("今日作物")
                            .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                        ForEach(board.offers.filter { if case .crop = $0.kind { true } else { false } }) { offer in
                            cropRow(offer)
                        }

                        Divider()
                        Text("合格圈养动物")
                            .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                        ForEach(board.animals) { animal in
                            animalRow(animal)
                        }
                    }
                }
            }
            .padding(22 * scale)
            .frame(maxWidth: 900 * scale, maxHeight: 650 * scale)
            .background(Color(red: 0.95, green: 0.87, blue: 0.67))
            .clipShape(RoundedRectangle(cornerRadius: 18 * scale))
            .shadow(radius: 24)
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("猫猫烧烤店今日收购板")
    }

    @ViewBuilder
    private func cropRow(_ offer: CatShopOfferCardSnapshot) -> some View {
        if case .crop(let itemID) = offer.kind {
            HStack(spacing: 12 * scale) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.name)
                        .font(.system(size: 16 * scale, weight: .bold))
                    Text("单价 \(offer.unitPrice) · 今日剩余 \(offer.remaining)/\(offer.dailyLimit) · 背包 \(offer.ownedQuantity)")
                        .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("供货 1 件 · +\(offer.unitPrice)") {
                    onSupplyCrop(offer.id, itemID, 1)
                }
                .disabled(offer.remaining <= 0 || offer.ownedQuantity <= 0)
                .buttonStyle(.borderedProminent)
            }
            .padding(11 * scale)
            .background(Color.white.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 10 * scale))
        }
    }

    @ViewBuilder
    private func animalRow(_ animal: FarmAnimalCardSnapshot) -> some View {
        let offer = board.offers.first { offer in
            if case .animal(let definitionID) = offer.kind {
                return definitionID == animal.definitionID
            }
            return false
        }
        HStack(spacing: 12 * scale) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(animal.name) · \(animal.speciesName)")
                    .font(.system(size: 16 * scale, weight: .bold))
                Text("\(animal.stageLabel) · \(animal.caredToday ? "今日已照料" : "今日未照料") · 公开价 \(animal.supplyPrice)")
                    .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !animal.canSupply {
                    Text(animal.isProtected ? "伙伴保护中，不可供货" : "需要成年并在今天完成照料")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if pendingAnimalID == animal.id, let offer {
                VStack(alignment: .trailing, spacing: 5 * scale) {
                    Text("确认后动物将离开圈舍")
                        .font(.system(size: 12 * scale, weight: .bold))
                        .foregroundStyle(.red)
                    HStack {
                        Button("取消") { pendingAnimalID = nil }
                        Button("再次确认 · +\(animal.supplyPrice)") {
                            pendingAnimalID = nil
                            onSupplyAnimal(offer.id, animal.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                Button("选择供货") {
                    pendingAnimalID = animal.id
                }
                .disabled(!animal.canSupply || offer?.remaining == 0)
                .buttonStyle(.bordered)
            }
        }
        .padding(11 * scale)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10 * scale))
    }
}
