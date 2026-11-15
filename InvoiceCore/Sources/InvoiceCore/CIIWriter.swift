import Foundation

/// Which specification the XML declares. Both use the same UN/CEFACT CII syntax.
public enum InvoiceProfile: Sendable {
    /// Plain EN 16931, as embedded in ZUGFeRD / Factur-X PDFs.
    case en16931
    /// German XRechnung 3.0 (CIUS of EN 16931).
    case xrechnung

    /// XRechnung requires a business process identifier; plain EN 16931 does not.
    var businessProcessID: String? {
        switch self {
        case .en16931: return nil
        case .xrechnung: return "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0"
        }
    }

    var guidelineID: String {
        switch self {
        case .en16931: return "urn:cen.eu:en16931:2017"
        case .xrechnung: return "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0"
        }
    }
}

/// Serialises an invoice as UN/CEFACT Cross Industry Invoice XML.
public struct CIIWriter {
    public var profile: InvoiceProfile

    public init(profile: InvoiceProfile = .en16931) {
        self.profile = profile
    }

    public func xml(for invoice: Invoice) -> String {
        let totals = InvoiceTotals(invoice)
        var x = XMLBuilder()
        x.raw("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        x.open("rsm:CrossIndustryInvoice", [
            ("xmlns:rsm", "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"),
            ("xmlns:qdt", "urn:un:unece:uncefact:data:standard:QualifiedDataType:100"),
            ("xmlns:ram", "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"),
            ("xmlns:udt", "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"),
        ])

        x.open("rsm:ExchangedDocumentContext")
        if let process = profile.businessProcessID {
            x.open("ram:BusinessProcessSpecifiedDocumentContextParameter")
            x.leaf("ram:ID", process)
            x.close()
        }
        x.open("ram:GuidelineSpecifiedDocumentContextParameter")
        x.leaf("ram:ID", profile.guidelineID)
        x.close()
        x.close()

        x.open("rsm:ExchangedDocument")
        x.leaf("ram:ID", invoice.number)
        x.leaf("ram:TypeCode", "380")
        x.open("ram:IssueDateTime")
        x.date(invoice.issueDate)
        x.close()
        var notes: [String] = []
        if let note = invoice.note, !note.isEmpty { notes.append(note) }
        for note in notes {
            x.open("ram:IncludedNote")
            x.leaf("ram:Content", note)
            x.close()
        }
        x.close()

        x.open("rsm:SupplyChainTradeTransaction")
        for (index, line) in invoice.lines.enumerated() {
            x.open("ram:IncludedSupplyChainTradeLineItem")
            x.open("ram:AssociatedDocumentLineDocument")
            x.leaf("ram:LineID", String(index + 1))
            x.close()
            x.open("ram:SpecifiedTradeProduct")
            x.leaf("ram:Name", line.name)
            x.close()
            x.open("ram:SpecifiedLineTradeAgreement")
            x.open("ram:NetPriceProductTradePrice")
            x.leaf("ram:ChargeAmount", Self.number(line.unitPrice, minFraction: 2, maxFraction: 4))
            x.close()
            x.close()
            x.open("ram:SpecifiedLineTradeDelivery")
            x.leaf("ram:BilledQuantity", Self.number(line.quantity, minFraction: 0, maxFraction: 4),
                   [("unitCode", line.unitCode)])
            x.close()
            x.open("ram:SpecifiedLineTradeSettlement")
            x.open("ram:ApplicableTradeTax")
            x.leaf("ram:TypeCode", "VAT")
            x.leaf("ram:CategoryCode", line.taxCategory.rawValue)
            x.leaf("ram:RateApplicablePercent", Self.number(line.taxPercent, minFraction: 0, maxFraction: 2))
            x.close()
            x.open("ram:SpecifiedTradeSettlementLineMonetarySummation")
            x.leaf("ram:LineTotalAmount", Self.money(line.netAmount))
            x.close()
            x.close()
            x.close()
        }

        x.open("ram:ApplicableHeaderTradeAgreement")
        if let reference = invoice.buyerReference, !reference.isEmpty {
            x.leaf("ram:BuyerReference", reference)
        }
        party("ram:SellerTradeParty", invoice.seller, into: &x)
        party("ram:BuyerTradeParty", invoice.buyer, into: &x)
        x.close()

        x.open("ram:ApplicableHeaderTradeDelivery")
        x.open("ram:ActualDeliverySupplyChainEvent")
        x.open("ram:OccurrenceDateTime")
        x.date(invoice.deliveryDate ?? invoice.issueDate)
        x.close()
        x.close()
        x.close()

        x.open("ram:ApplicableHeaderTradeSettlement")
        x.leaf("ram:InvoiceCurrencyCode", invoice.currency)
        if let iban = invoice.iban, !iban.isEmpty {
            x.open("ram:SpecifiedTradeSettlementPaymentMeans")
            x.leaf("ram:TypeCode", "58")
            x.open("ram:PayeePartyCreditorFinancialAccount")
            x.leaf("ram:IBANID", iban.replacingOccurrences(of: " ", with: ""))
            x.close()
            x.close()
        }
        for subtotal in totals.taxSubtotals {
            x.open("ram:ApplicableTradeTax")
            x.leaf("ram:CalculatedAmount", Self.money(subtotal.tax))
            x.leaf("ram:TypeCode", "VAT")
            if let reason = Self.exemptionReason(subtotal.category) {
                x.leaf("ram:ExemptionReason", reason)
            }
            x.leaf("ram:BasisAmount", Self.money(subtotal.basis))
            x.leaf("ram:CategoryCode", subtotal.category.rawValue)
            x.leaf("ram:RateApplicablePercent", Self.number(subtotal.percent, minFraction: 0, maxFraction: 2))
            x.close()
        }
        if invoice.paymentTerms != nil || invoice.dueDate != nil {
            x.open("ram:SpecifiedTradePaymentTerms")
            if let terms = invoice.paymentTerms, !terms.isEmpty {
                x.leaf("ram:Description", terms)
            }
            if let due = invoice.dueDate {
                x.open("ram:DueDateDateTime")
                x.date(due)
                x.close()
            }
            x.close()
        }
        x.open("ram:SpecifiedTradeSettlementHeaderMonetarySummation")
        x.leaf("ram:LineTotalAmount", Self.money(totals.lineTotal))
        x.leaf("ram:TaxBasisTotalAmount", Self.money(totals.lineTotal))
        x.leaf("ram:TaxTotalAmount", Self.money(totals.taxTotal), [("currencyID", invoice.currency)])
        x.leaf("ram:GrandTotalAmount", Self.money(totals.grandTotal))
        x.leaf("ram:DuePayableAmount", Self.money(totals.grandTotal))
        x.close()
        x.close()

        x.close()
        x.close()
        return x.output
    }

    private func party(_ element: String, _ party: Party, into x: inout XMLBuilder) {
        x.open(element)
        // EN 16931 rule BR-CO-26 wants the seller identified by a VAT ID, a legal registration or a
        // seller identifier. Sellers with only a Steuernummer (typically Kleinunternehmer) have no
        // VAT ID, so the Steuernummer doubles as the seller identifier.
        if element == "ram:SellerTradeParty", (party.vatID ?? "").isEmpty,
           let taxNumber = party.taxNumber, !taxNumber.isEmpty {
            x.leaf("ram:ID", taxNumber)
        }
        x.leaf("ram:Name", party.name)
        if party.contactName != nil || party.phone != nil || party.email != nil {
            x.open("ram:DefinedTradeContact")
            if let name = party.contactName, !name.isEmpty { x.leaf("ram:PersonName", name) }
            if let phone = party.phone, !phone.isEmpty {
                x.open("ram:TelephoneUniversalCommunication")
                x.leaf("ram:CompleteNumber", phone)
                x.close()
            }
            if let email = party.email, !email.isEmpty {
                x.open("ram:EmailURIUniversalCommunication")
                x.leaf("ram:URIID", email)
                x.close()
            }
            x.close()
        }
        x.open("ram:PostalTradeAddress")
        x.leaf("ram:PostcodeCode", party.address.postcode)
        if !party.address.street.isEmpty { x.leaf("ram:LineOne", party.address.street) }
        x.leaf("ram:CityName", party.address.city)
        x.leaf("ram:CountryID", party.address.countryCode)
        x.close()
        if let email = party.email, !email.isEmpty {
            x.open("ram:URIUniversalCommunication")
            x.leaf("ram:URIID", email, [("schemeID", "EM")])
            x.close()
        }
        if let taxNumber = party.taxNumber, !taxNumber.isEmpty {
            x.open("ram:SpecifiedTaxRegistration")
            x.leaf("ram:ID", taxNumber, [("schemeID", "FC")])
            x.close()
        }
        if let vatID = party.vatID, !vatID.isEmpty {
            x.open("ram:SpecifiedTaxRegistration")
            x.leaf("ram:ID", vatID, [("schemeID", "VA")])
            x.close()
        }
        x.close()
    }

    static func exemptionReason(_ category: TaxCategory) -> String? {
        switch category {
        case .standard: return nil
        case .exempt: return "Kein Ausweis von Umsatzsteuer, da Kleinunternehmer gemäß § 19 UStG"
        case .reverseCharge: return "Steuerschuldnerschaft des Leistungsempfängers"
        }
    }

    static func money(_ value: Decimal) -> String {
        number(value.roundedMoney, minFraction: 2, maxFraction: 2)
    }

    /// Formats with a dot as decimal separator and no grouping, independent of the device locale.
    static func number(_ value: Decimal, minFraction: Int, maxFraction: Int) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, maxFraction, .plain)
        var text = NSDecimalNumber(decimal: rounded).stringValue
        if text.contains("E") || text.contains("e") {
            text = String(format: "%.\(maxFraction)f", NSDecimalNumber(decimal: rounded).doubleValue)
        }
        var parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 1 { parts.append("") }
        while parts[1].count < minFraction { parts[1] += "0" }
        return parts[1].isEmpty ? parts[0] : parts[0] + "." + parts[1]
    }
}

struct XMLBuilder {
    private(set) var output = ""
    private var stack: [String] = []

    mutating func raw(_ text: String) {
        output += text + "\n"
    }

    mutating func open(_ name: String, _ attributes: [(String, String)] = []) {
        output += indent + "<" + name + Self.attributes(attributes) + ">\n"
        stack.append(name)
    }

    mutating func close() {
        let name = stack.removeLast()
        output += indent + "</" + name + ">\n"
    }

    mutating func leaf(_ name: String, _ value: String, _ attributes: [(String, String)] = []) {
        output += indent + "<" + name + Self.attributes(attributes) + ">" + Self.escape(value) + "</" + name + ">\n"
    }

    mutating func date(_ date: Date) {
        leaf("udt:DateTimeString", Self.dateFormatter.string(from: date), [("format", "102")])
    }

    private var indent: String { String(repeating: "  ", count: stack.count) }

    private static func attributes(_ attributes: [(String, String)]) -> String {
        attributes.map { " \($0.0)=\"\(escape($0.1))\"" }.joined()
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
