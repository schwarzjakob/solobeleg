import XCTest
#if canImport(FoundationXML)
import FoundationXML
#endif
@testable import InvoiceCore

final class InvoiceCoreTests: XCTestCase {
    func sample(lines: [LineItem]) -> Invoice {
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 15; components.hour = 12
        components.timeZone = TimeZone(identifier: "Europe/Berlin")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        return Invoice(
            number: "RE-2026-001",
            issueDate: date,
            dueDate: date.addingTimeInterval(14 * 86400),
            seller: Party(name: "Muster & Söhne GmbH",
                          address: Address(street: "Hauptstraße 1", postcode: "10115", city: "Berlin"),
                          contactName: "Erika Muster", phone: "+49 30 123456", email: "rechnung@muster.example",
                          vatID: "DE123456789"),
            buyer: Party(name: "Kunde AG",
                         address: Address(street: "Marktplatz 5", postcode: "80331", city: "München"),
                         email: "einkauf@kunde.example"),
            buyerReference: "04011000-12345-06",
            lines: lines,
            paymentTerms: "Zahlbar innerhalb von 14 Tagen ohne Abzug",
            iban: "DE02 1203 0000 0000 2020 51")
    }

    func testTotalsGroupVATByRate() {
        let invoice = sample(lines: [
            LineItem(name: "Beratung", quantity: 2.5, unitCode: "HUR", unitPrice: 90),
            LineItem(name: "Fachbuch", quantity: 3, unitPrice: Decimal(string: "19.99")!, taxPercent: 7),
            LineItem(name: "Lizenz", quantity: 1, unitPrice: Decimal(string: "0.05")!),
        ])
        let totals = InvoiceTotals(invoice)
        XCTAssertEqual(totals.lineTotal, Decimal(string: "285.02"))
        XCTAssertEqual(totals.taxSubtotals.count, 2)
        XCTAssertEqual(totals.taxSubtotals[0].basis, Decimal(string: "225.05"))
        XCTAssertEqual(totals.taxSubtotals[0].tax, Decimal(string: "42.76"))
        XCTAssertEqual(totals.taxSubtotals[1].tax, Decimal(string: "4.20"))
        XCTAssertEqual(totals.grandTotal, Decimal(string: "331.98"))
    }

    func testXMLIsWellFormedAndCarriesTotals() throws {
        let invoice = sample(lines: [LineItem(name: "Beratung <Workshop>", quantity: 2, unitCode: "HUR", unitPrice: 100)])
        let xml = CIIWriter(profile: .xrechnung).xml(for: invoice)
        let document = try XMLDocument(xmlString: xml)
        XCTAssertEqual(document.rootElement()?.name, "rsm:CrossIndustryInvoice")
        XCTAssertTrue(xml.contains("xrechnung_3.0"))
        XCTAssertTrue(xml.contains("<ram:ID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</ram:ID>"))
        XCTAssertFalse(CIIWriter(profile: .en16931).xml(for: invoice).contains("BusinessProcessSpecifiedDocumentContextParameter"))
        XCTAssertTrue(xml.contains("<udt:DateTimeString format=\"102\">20261115</udt:DateTimeString>"))
        XCTAssertTrue(xml.contains("<ram:Name>Muster &amp; Söhne GmbH</ram:Name>"))
        XCTAssertTrue(xml.contains("Beratung &lt;Workshop&gt;"))
        XCTAssertTrue(xml.contains("<ram:GrandTotalAmount>238.00</ram:GrandTotalAmount>"))
        XCTAssertTrue(xml.contains("<ram:TaxTotalAmount currencyID=\"EUR\">38.00</ram:TaxTotalAmount>"))
        XCTAssertTrue(xml.contains("<ram:IBANID>DE02120300000000202051</ram:IBANID>"))
    }

    func testKleinunternehmerInvoiceHasNoVAT() {
        var invoice = sample(lines: [LineItem(name: "Logo-Design", quantity: 1, unitPrice: 450,
                                              taxCategory: .exempt, taxPercent: 0)])
        invoice.seller.vatID = nil
        invoice.seller.taxNumber = "12/345/67890"
        let xml = CIIWriter().xml(for: invoice)
        XCTAssertTrue(xml.contains("<ram:CategoryCode>E</ram:CategoryCode>"))
        XCTAssertTrue(xml.contains("§ 19 UStG"))
        XCTAssertTrue(xml.contains("<ram:ID schemeID=\"FC\">12/345/67890</ram:ID>"))
        // Without a VAT ID the Steuernummer also serves as seller identifier (rule BR-CO-26).
        let compact = xml.components(separatedBy: .whitespacesAndNewlines).joined()
        XCTAssertTrue(compact.contains("<ram:SellerTradeParty><ram:ID>12/345/67890</ram:ID>"))
        XCTAssertTrue(xml.contains("<ram:GrandTotalAmount>450.00</ram:GrandTotalAmount>"))
        XCTAssertTrue(invoice.validate().isEmpty)
    }

    func testValidationReportsMissingFields() {
        var invoice = sample(lines: [])
        invoice.number = " "
        invoice.seller.vatID = nil
        let fields = invoice.validate().map(\.field)
        XCTAssertEqual(fields, ["number", "seller.vatID", "lines"])
    }

    func testNumberFormatting() {
        XCTAssertEqual(CIIWriter.money(Decimal(string: "1234.5")!), "1234.50")
        XCTAssertEqual(CIIWriter.money(Decimal(string: "0.005")!), "0.01")
        XCTAssertEqual(CIIWriter.number(Decimal(string: "2.50")!, minFraction: 0, maxFraction: 4), "2.5")
        XCTAssertEqual(CIIWriter.number(19, minFraction: 0, maxFraction: 2), "19")
    }
}
