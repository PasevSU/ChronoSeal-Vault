/* PasevSU embedded-origin bootstrap v3.4 — Home Assistant Ingress safe. */
(() => {
  'use strict';
  // ChronoSeal serves the toolbox from the same authenticated Ingress origin.
  // Never redirect to localhost:3000: in a browser that address is the client, not the HA app.
  window.PASEVSU_EMBEDDED_ORIGIN = true;
})();
