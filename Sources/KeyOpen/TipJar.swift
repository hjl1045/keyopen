import AppKit
import KeyOpenCore
import StoreKit
import SwiftUI

/// The App Store edition's tips, through StoreKit. Tips are consumable in-app
/// purchases that unlock nothing; the App Store rules out any other way to take
/// money inside an App Store app.
@MainActor
final class TipJar: ObservableObject {
    enum State: Equatable {
        case loading, ready, unavailable, thanked
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var tiles: [(tip: TipCatalog.Tip, product: Product)] = []
    @Published private(set) var purchasing: String?
    private var updates: Task<Void, Never>?

    /// Finishes purchases that complete outside the window (Ask to Buy, a
    /// purchase interrupted by a quit). Unfinished transactions are redelivered
    /// on every launch, so this runs from launch, not from the window.
    func listenForTransactions() {
        updates = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
            }
        }
    }

    func load() async {
        state = .loading
        do {
            let products = try await Product.products(for: TipCatalog.productIDs)
            tiles = TipCatalog.arrange(products, id: \.id).map { (tip: $0.0, product: $0.1) }
            state = tiles.isEmpty ? .unavailable : .ready
        } catch {
            state = .unavailable
        }
    }

    func buy(_ product: Product) async {
        purchasing = product.id
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                state = .thanked
            case .success(.unverified(let transaction, _)):
                // Apple couldn't verify it; finish so it isn't redelivered,
                // but don't thank anyone for money that may not have moved.
                await transaction.finish()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            NSLog("KeyOpen: tip purchase failed: \(error)")
        }
    }
}

struct TipJarView: View {
    @ObservedObject var jar: TipJar

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
            if jar.state == .thanked {
                Text("🎉").font(.system(size: 30)).padding(.top, 10)
                Text("Thank you!")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.top, 6)
                Text("That made my day. — Hansee")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Text("Buy me a coffee")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.top, 8)
                Text("KeyOpen is free and stays free. If it saved you a hunt for a shortcut, a coffee keeps me building.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                tiles.padding(.top, 14)
                Text("A one-time tip. It doesn't unlock anything.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .frame(width: 400)
        .task { if jar.state != .thanked { await jar.load() } }
    }

    @ViewBuilder private var tiles: some View {
        switch jar.state {
        case .loading:
            ProgressView().controlSize(.small).frame(height: 84)
        case .unavailable:
            Text("Tips aren't available right now.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 84)
        case .ready, .thanked:
            HStack(spacing: 8) {
                ForEach(jar.tiles, id: \.product.id) { tile in
                    Button {
                        Task { await jar.buy(tile.product) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tile.tip.symbol).font(.system(size: 20))
                            Text(tile.tip.name).font(.system(size: 12, weight: .semibold))
                            Text(tile.product.displayPrice)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.free)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(jar.purchasing != nil)
                    .opacity(jar.purchasing == nil || jar.purchasing == tile.product.id ? 1 : 0.5)
                }
            }
        }
    }
}
