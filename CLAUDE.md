# Solobeleg

Native Apple app (Mac, iPhone, iPad) for German freelancers and small businesses to create
legally valid e-invoices (XRechnung and ZUGFeRD) without a subscription.

The owner has about an hour a week for this project and is not on social media. Claude leads
the work: make decisions, state them, and keep going. Ask only for things the owner alone can
do (accounts, payments, approvals).

## Why this product

- German law: every business must be able to receive e-invoices since 1 Jan 2025. Businesses
  above €800k turnover must issue them from 1 Jan 2027, all others except Kleinunternehmer
  (§ 19 UStG) from 1 Jan 2028.
- Google Trends for "E-Rechnung erstellen" spikes before each deadline and drops within two
  months. The larger wave is the run-up to 2028.
- The web is taken: PDF24, sevDesk and several single-purpose sites offer free, unlimited
  online generators. Do not build a free web generator.
- The German App Store is thin: about a dozen e-invoice apps, nearly all with under 15
  ratings, one priced at €49.99.
- The gap: free web generators do not save master data. Solobeleg stores customers, items
  and invoice numbering on the device.

## Product decisions

- One SwiftUI app for macOS, iOS and iPadOS. Data stays on the device; no account, no server.
- One-time purchase, no subscription. Planned: a few free invoices, then a single unlock.
- Exports: XRechnung (XML only) and ZUGFeRD (PDF/A-3 with the XML embedded).
- UI language: German.
- App Store title: "Solobeleg: E-Rechnung erstellen". Subtitle: "XRechnung & ZUGFeRD, ohne Abo".
- Domain solobeleg.de is registered by the owner. The site is a simple supporting page, to be
  built later in this repo.

## Status

Done:

- `InvoiceCore/` Swift package: invoice model, VAT totals grouped by rate, mandatory-field
  checks with German messages, and a UN/CEFACT CII XML writer for the EN 16931 and
  XRechnung 3.0 profiles.
- Six sample invoices (standard, mixed 19 %/7 %, Kleinunternehmer; each in both profiles)
  pass the Mustang validator 2.26.0 with no errors or warnings.

Not done, in order:

1. ZUGFeRD PDF export: render the invoice as PDF/A-3 and embed the XML (attachment name
   `factur-x.xml`, XMP metadata, output intent). This is the hardest part. Validate the
   result with Mustang.
2. Xcode project with a SwiftUI app target that depends on `InvoiceCore`: invoice form,
   saved customers and items, invoice numbering, export and share.
3. One-time purchase with StoreKit.
4. App Store listing, screenshots, privacy details.
5. Website at solobeleg.de.

Waiting on the owner:

- Apple Developer Program enrolment is submitted; approval pending.
- Trademark check for "Solobeleg" in the DPMA register is not done.

## Working in this repo

Run the engine tests:

```bash
cd InvoiceCore && swift test
```

Write sample invoices for validation:

```bash
cd InvoiceCore && swift run invoice-samples /tmp/solobeleg-samples
```

Validate a file with Mustang (Java; `Mustang-CLI` from Maven Central, group `org.mustangproject`):

```bash
java -jar Mustang-CLI-2.26.0.jar --action validate --source /tmp/solobeleg-samples/standard-xrechnung.xml
```

Every change to the XML or PDF output must pass Mustang before it is committed. The plain
EN 16931 files show two notices about XRechnung rules; those are expected, because those
files are not XRechnung.

## Rules learned so far

- XRechnung needs `BusinessProcessSpecifiedDocumentContextParameter` with
  `urn:fdc:peppol.eu:2017:poacc:billing:01:1.0`; plain EN 16931 must not carry it.
- A seller without a USt-IdNr. fails rule BR-CO-26 unless another identifier is present. The
  writer emits the Steuernummer as seller identifier (`ram:ID`) in that case.
- VAT is computed per rate group, then summed. Do not compute it per line.
- Number formatting must not depend on the device locale: dot as decimal separator, no grouping.

## How success is judged

- Target: submitted to the App Store by mid-December 2026, with XML and PDF export validated.
- Four weeks after launch: under 200 downloads and no sales means stop and build the next
  candidate, reusing the Apple account and setup.
- The owner would be content with small first-month revenue; the goal is fast, real feedback.
