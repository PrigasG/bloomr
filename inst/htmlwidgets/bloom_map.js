HTMLWidgets.widget({
  name: "bloom_map",
  type: "output",
  factory: function (el) {
    var map = null;
    return {
      renderValue: function (x) {
        if (map) map.destroy();
        map = new window.Bloomr.Map(el, x);
      },
      resize: function () {
        if (map) map.resize();
      }
    };
  }
});
