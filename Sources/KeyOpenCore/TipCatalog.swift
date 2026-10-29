import Foundation

/// The App Store edition's tips: three consumable in-app purchases. The names
/// are sizes of thanks rather than things to buy, so no price can contradict
/// them (an "espresso" at $0.99 read as wrong). Prices come from the App Store
/// in the buyer's currency.
public enum TipCatalog {
    public struct Tip: Equatable {
        public let productID: String
        public let name: String
        public let symbol: String
    }

    /// Smallest first: the order the window lays them out in. US prices, as set
    /// in App Store Connect: $0.99, $4.99, $9.99.
    public static let tips: [Tip] = [
        Tip(productID: "com.theautonomes.keyopen.tip.thanks", name: "Thanks", symbol: "🙏"),
        Tip(productID: "com.theautonomes.keyopen.tip.bigthanks", name: "Big thanks", symbol: "✨"),
        Tip(productID: "com.theautonomes.keyopen.tip.hugethanks", name: "Huge thanks", symbol: "🎉"),
    ]

    public static var productIDs: [String] { tips.map(\.productID) }

    /// Pairs what the App Store returned with our tips, in catalog order. A
    /// product we don't know is dropped, and a tip the store didn't return is
    /// left out rather than shown without a price.
    public static func arrange<Product>(_ products: [Product], id: (Product) -> String) -> [(Tip, Product)] {
        tips.compactMap { tip in
            products.first { id($0) == tip.productID }.map { (tip, $0) }
        }
    }
}
