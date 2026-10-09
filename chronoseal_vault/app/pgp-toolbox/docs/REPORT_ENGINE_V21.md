# PasevSU Technical Report Engine v2.1

The report engine is presentation and evidence-packaging logic, not a digital-signature substitute.

It builds a canonical JSON payload from controlled runtime metadata, the latest policy report, available Advanced OpenPGP reports and optionally a public-key inventory. Private-key fields are not collected.

The canonical payload receives SHA-256 and SHA-512 digests. The PDF uses A4, 20 mm left/right, 25 mm top and 15 mm bottom margins, repeated page headers/footers, a 128-hex-character derived Page-ID based on SHA-512(report hash + page ordinal) and a QR payload containing report ID plus canonical SHA-256.

The verified built-in PDF path is German because standard jsPDF fonts do not provide the Unicode/Cyrillic coverage required for a trustworthy Bulgarian PDF. The UI itself remains BG/DE. Bulgarian PDF output will be enabled only when a verified embedded Unicode font provider is added.

## v2.1.1 canonical snapshot semantics

PDF and JSON exports now reuse one canonical report snapshot while the selected report inputs remain unchanged. This guarantees the same `generatedAt`, Report-ID, canonical SHA-256 and canonical SHA-512 regardless of whether PDF or JSON is exported first. `New report snapshot` explicitly invalidates the snapshot. Any change in collected report data automatically causes a new snapshot on the next export.

The 128-hex-character `Derived Page-ID` is **not** a hash of the rendered PDF page bytes. It is deterministically derived from the canonical report SHA-512 plus the page ordinal, so it identifies the page position inside that canonical report instance without making a circular claim about the final rendered PDF bytes.
