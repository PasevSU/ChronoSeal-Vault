# PasevSU PGP Toolbox — self-starting JS launcher

Файлове за поставяне в root на `_WEB_pgp`:

- `start.js` — основният launcher; стартира `server/server.js`, чака `/api/health`, записва PID/logs и отваря браузъра.
- `start.ps1` — тънък Windows bootstrap към Node.js.
- `start.bat` — compatibility launcher.

## Поведение

`start.js` не изпълнява `setup_vendor.ps1` по подразбиране. Това премахва блокирането, при което липсващият browser bundle на OpenPGP.js спира HTTP сървъра преди неговия старт.

Локален OpenPGP.js runtime се търси в project vendor/runtime директории и в:

`<PASEVSU_CRYPTO_HOME>\\openpgpjs\\dist\\openpgp.min.mjs`

както и в sibling `_crypto\\openpgpjs\\dist`.

Ако runtime е намерен, се проверява source version `6.3.1`, изчислява се SHA-256 и към server process се подават:

- `PASEVSU_OPENPGP_RUNTIME`
- `PASEVSU_OPENPGPJS_RUNTIME`
- `PASEVSU_OPENPGPJS_VERSION`
- `PASEVSU_OPENPGPJS_SHA256`

Ако runtime липсва, сървърът **все пак се стартира**. Ако `/api/health` върне `vendorReady=false`, launcher-ът записва предупреждение, но отваря UI.

За изрично стартиране на стария vendor migration преди сървъра:

`$env:PASEVSU_RUN_VENDOR_SETUP='1'`

По подразбиране няма `npm install` и няма network download.
