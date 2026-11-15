import Foundation

/// VAT treatment of a line, using the EN 16931 category codes.
public enum TaxCategory: String, Codable, Sendable {
    /// Standard rated (19 % or 7 % in Germany).
    case standard = "S"
    /// Exempt. Used for Kleinunternehmer invoices under § 19 UStG.
    case exempt = "E"
    /// Reverse charge.
    case reverseCharge = "AE"
}

public struct Address: Codable, Equatable, Sendable {
    public var street: String
    public var postcode: String
    public var city: String
    /// ISO 3166-1 alpha-2, e.g. "DE".
    public var countryCode: String

    public init(street: String, postcode: String, city: String, countryCode: String = "DE") {
        self.street = street
        self.postcode = postcode
        self.city = city
        self.countryCode = countryCode
    }
}

public struct Party: Codable, Equatable, Sendable {
    public var name: String
    public var address: Address
    public var contactName: String?
    public var phone: String?
    public var email: String?
    /// Umsatzsteuer-Identifikationsnummer, e.g. "DE123456789".
    public var vatID: String?
    /// Steuernummer issued by the tax office, e.g. "12/345/67890".
    public var taxNumber: String?

    public init(name: String, address: Address, contactName: String? = nil, phone: String? = nil,
                email: String? = nil, vatID: String? = nil, taxNumber: String? = nil) {
        self.name = name
        self.address = address
        self.contactName = contactName
        self.phone = phone
        self.email = email
        self.vatID = vatID
        self.taxNumber = taxNumber
    }
}

public struct LineItem: Codable, Equatable, Sendable {
    public var name: String
    public var quantity: Decimal
    /// UN/ECE Rec. 20 unit code: "C62" piece, "HUR" hour, "DAY" day, "LS" lump sum.
    public var unitCode: String
    public var unitPrice: Decimal
    public var taxCategory: TaxCategory
    public var taxPercent: Decimal

    public init(name: String, quantity: Decimal, unitCode: String = "C62", unitPrice: Decimal,
                taxCategory: TaxCategory = .standard, taxPercent: Decimal = 19) {
        self.name = name
        self.quantity = quantity
        self.unitCode = unitCode
        self.unitPrice = unitPrice
        self.taxCategory = taxCategory
        self.taxPercent = taxPercent
    }

    public var netAmount: Decimal { (quantity * unitPrice).roundedMoney }
}

public struct Invoice: Codable, Equatable, Sendable {
    public var number: String
    public var issueDate: Date
    public var deliveryDate: Date?
    public var dueDate: Date?
    public var seller: Party
    public var buyer: Party
    /// Leitweg-ID for public-sector buyers; otherwise any reference the buyer asked for.
    public var buyerReference: String?
    public var lines: [LineItem]
    public var note: String?
    public var paymentTerms: String?
    public var iban: String?
    public var currency: String

    public init(number: String, issueDate: Date, deliveryDate: Date? = nil, dueDate: Date? = nil,
                seller: Party, buyer: Party, buyerReference: String? = nil, lines: [LineItem],
                note: String? = nil, paymentTerms: String? = nil, iban: String? = nil,
                currency: String = "EUR") {
        self.number = number
        self.issueDate = issueDate
        self.deliveryDate = deliveryDate
        self.dueDate = dueDate
        self.seller = seller
        self.buyer = buyer
        self.buyerReference = buyerReference
        self.lines = lines
        self.note = note
        self.paymentTerms = paymentTerms
        self.iban = iban
        self.currency = currency
    }
}

extension Decimal {
    /// Rounds to two decimal places, half away from zero, as invoices require.
    public var roundedMoney: Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}
