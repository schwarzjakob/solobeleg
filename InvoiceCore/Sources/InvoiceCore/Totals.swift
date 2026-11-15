import Foundation

/// One VAT breakdown row: all lines sharing a category and rate.
public struct TaxSubtotal: Equatable, Sendable {
    public let category: TaxCategory
    public let percent: Decimal
    public let basis: Decimal
    public let tax: Decimal
}

public struct InvoiceTotals: Equatable, Sendable {
    public let lineTotal: Decimal
    public let taxSubtotals: [TaxSubtotal]
    public let taxTotal: Decimal
    public let grandTotal: Decimal

    public init(_ invoice: Invoice) {
        var order: [String] = []
        var groups: [String: (TaxCategory, Decimal, Decimal)] = [:]
        for line in invoice.lines {
            let key = "\(line.taxCategory.rawValue)|\(line.taxPercent)"
            if groups[key] == nil {
                order.append(key)
                groups[key] = (line.taxCategory, line.taxPercent, 0)
            }
            groups[key]!.2 += line.netAmount
        }
        // EN 16931 computes VAT per breakdown group, not per line, then sums the groups.
        taxSubtotals = order.map { key in
            let (category, percent, basis) = groups[key]!
            return TaxSubtotal(category: category, percent: percent, basis: basis,
                               tax: (basis * percent / 100).roundedMoney)
        }
        lineTotal = taxSubtotals.reduce(0) { $0 + $1.basis }
        taxTotal = taxSubtotals.reduce(0) { $0 + $1.tax }
        grandTotal = lineTotal + taxTotal
    }
}
