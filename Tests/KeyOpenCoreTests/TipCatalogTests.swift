import XCTest
@testable import KeyOpenCore

final class TipCatalogTests: XCTestCase {
    func testProductIDsMatchTheAppStoreRecord() {
        // The in-app purchases in App Store Connect must use exactly these ids.
        XCTAssertEqual(TipCatalog.productIDs, [
            "com.theautonomes.keyopen.tip.thanks",
            "com.theautonomes.keyopen.tip.bigthanks",
            "com.theautonomes.keyopen.tip.hugethanks",
        ])
        XCTAssertEqual(TipCatalog.tips.map(\.name), ["Thanks", "Big thanks", "Huge thanks"])
    }

    func testSymbolsAreSingleSoNothingReadsAsACount() {
        // "☕☕" next to "☕" implied two of something at a price that didn't double.
        for tip in TipCatalog.tips {
            XCTAssertEqual(tip.symbol.count, 1, tip.name)
        }
        XCTAssertEqual(Set(TipCatalog.tips.map(\.symbol)).count, TipCatalog.tips.count)
    }

    func testArrangeKeepsCatalogOrderAndDropsStrangers() {
        // The store returns products in no particular order.
        let returned = ["com.theautonomes.keyopen.tip.hugethanks", "com.example.other",
                        "com.theautonomes.keyopen.tip.thanks"]
        let arranged = TipCatalog.arrange(returned, id: { $0 })
        XCTAssertEqual(arranged.map(\.0.name), ["Thanks", "Huge thanks"])
        XCTAssertEqual(arranged.map(\.1), ["com.theautonomes.keyopen.tip.thanks",
                                            "com.theautonomes.keyopen.tip.hugethanks"])
    }

    func testNothingReturnedMeansNoTiles() {
        XCTAssertTrue(TipCatalog.arrange([String](), id: { $0 }).isEmpty)
    }
}
