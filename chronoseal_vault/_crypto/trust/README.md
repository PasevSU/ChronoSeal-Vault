# Additional TSA trust anchors

Optional controlled trust anchors may be placed here as PEM or DER `.cer/.crt/.pem` files before building the add-on. At startup they are merged with Alpine's system CA bundle into a private `/tmp/pasevsu-ca-bundle.pem` used only by the evidence backend.

The strict provider pin still has to match the expected root fingerprint. Adding an unrelated certificate cannot make DFN or DigiCert validation pass.
