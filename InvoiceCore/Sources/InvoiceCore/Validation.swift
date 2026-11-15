import Foundation

/// A problem that would make the e-invoice invalid, phrased for the person filling in the form.
public struct ValidationIssue: Equatable, Sendable {
    public let field: String
    public let message: String
}

extension Invoice {
    /// Checks the mandatory fields of EN 16931 and the German XRechnung additions.
    public func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        func require(_ value: String?, _ field: String, _ message: String) {
            if (value ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(field: field, message: message))
            }
        }
        require(number, "number", "Rechnungsnummer fehlt.")
        require(seller.name, "seller.name", "Name des Rechnungsstellers fehlt.")
        require(seller.address.city, "seller.address.city", "Ort des Rechnungsstellers fehlt.")
        require(seller.address.postcode, "seller.address.postcode", "PLZ des Rechnungsstellers fehlt.")
        require(seller.email, "seller.email", "E-Mail-Adresse des Rechnungsstellers fehlt.")
        require(buyer.name, "buyer.name", "Name des Kunden fehlt.")
        require(buyer.address.city, "buyer.address.city", "Ort des Kunden fehlt.")
        require(buyer.address.postcode, "buyer.address.postcode", "PLZ des Kunden fehlt.")
        if (seller.vatID ?? "").isEmpty && (seller.taxNumber ?? "").isEmpty {
            issues.append(ValidationIssue(field: "seller.vatID",
                                          message: "USt-IdNr. oder Steuernummer des Rechnungsstellers fehlt."))
        }
        if lines.isEmpty {
            issues.append(ValidationIssue(field: "lines", message: "Die Rechnung hat keine Positionen."))
        }
        for (index, line) in lines.enumerated() {
            require(line.name, "lines[\(index)].name", "Position \(index + 1): Bezeichnung fehlt.")
            if line.taxCategory != .standard && line.taxPercent != 0 {
                issues.append(ValidationIssue(field: "lines[\(index)].taxPercent",
                                              message: "Position \(index + 1): Steuersatz muss bei Steuerbefreiung 0 sein."))
            }
        }
        return issues
    }
}
