/* Resolve the htmlwidgets dependency URL at runtime: works in Shiny and HTML. */
(function () {
  "use strict";
  var source = document.currentScript && document.currentScript.src;
  if (!source) return;
  window.BloomrGeoBase = new URL("data/", source).href;
})();
