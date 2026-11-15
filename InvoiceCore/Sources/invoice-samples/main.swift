import Foundation
import InvoiceCore

// Writes sample e-invoices to a directory so they can be checked with an external validator.
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "samples")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let issueDate = ISO8601DateFormatter().date(from: "2026-11-15T11:00:00Z")!
let seller = Party(name: "Muster & Söhne GmbH",
                   address: Address(street: "Hauptstraße 1", postcode: "10115", city: "Berlin"),
                   contactName: "Erika Muster", phone: "+49 30 123456", email: "rechnung@muster.example",
                   vatID: "DE123456789")
let buyer = Party(name: "Kunde AG",
                  address: Address(street: "Marktplatz 5", postcode: "80331", city: "München"),
                  email: "einkauf@kunde.example")

func invoice(_ number: String, seller: Party, lines: [LineItem]) -> Invoice {
    Invoice(number: number, issueDate: issueDate, dueDate: issueDate.addingTimeInterval(14 * 86400),
            seller: seller, buyer: buyer, buyerReference: "04011000-12345-06", lines: lines,
            note: "Vielen Dank für Ihren Auftrag.",
            paymentTerms: "Zahlbar innerhalb von 14 Tagen ohne Abzug",
            iban: "DE02 1203 0000 0000 2020 51")
}

var kleinunternehmer = seller
kleinunternehmer.name = "Erika Muster Design"
kleinunternehmer.vatID = nil
kleinunternehmer.taxNumber = "12/345/67890"

let samples: [(String, Invoice)] = [
    ("standard", invoice("RE-2026-001", seller: seller, lines: [
        LineItem(name: "Beratung", quantity: 2, unitCode: "HUR", unitPrice: 100),
    ])),
    ("mixed-rates", invoice("RE-2026-002", seller: seller, lines: [
        LineItem(name: "Beratung", quantity: 2.5, unitCode: "HUR", unitPrice: 90),
        LineItem(name: "Fachbuch", quantity: 3, unitPrice: Decimal(string: "19.99")!, taxPercent: 7),
        LineItem(name: "Lizenz", quantity: 1, unitPrice: Decimal(string: "0.05")!),
    ])),
    ("kleinunternehmer", invoice("RE-2026-003", seller: kleinunternehmer, lines: [
        LineItem(name: "Logo-Design", quantity: 1, unitPrice: 450, taxCategory: .exempt, taxPercent: 0),
    ])),
]

for (name, invoice) in samples {
    for (suffix, profile) in [("en16931", InvoiceProfile.en16931), ("xrechnung", InvoiceProfile.xrechnung)] {
        let file = outputDirectory.appendingPathComponent("\(name)-\(suffix).xml")
        try CIIWriter(profile: profile).xml(for: invoice).write(to: file, atomically: true, encoding: .utf8)
        print(file.path)
    }
}
