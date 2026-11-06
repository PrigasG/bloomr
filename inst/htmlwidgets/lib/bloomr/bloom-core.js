/* bloomr: geographic bloom map engine.
   Each map has its own state, events, and styles. Assets are bundled locally. */
(function (global) {
  "use strict";
  const NS = "http://www.w3.org/2000/svg";
  const WIDTH = 1000, HEIGHT = 720, EDGE_PADDING = 22;
  const instances = new Map();
  const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
  const finite = n => Number.isFinite(n);
  const add = (a, b) => ({ x: (a?.x || 0) + (b?.x || 0), y: (a?.y || 0) + (b?.y || 0) });
  const elem = (tag, cls, parent) => {
    const e = document.createElementNS(NS, tag);
    if (cls) e.setAttribute("class", cls);
    if (parent) parent.appendChild(e);
    return e;
  };
  const html = (tag, cls, parent, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    if (parent) parent.appendChild(e);
    return e;
  };
  const hexMix = (first, second, t) => {
    const a = first.replace("#", ""), b = second.replace("#", "");
    const hex = i => Math.round(parseInt(a.slice(i, i + 2), 16) * (1 - t) + parseInt(b.slice(i, i + 2), 16) * t).toString(16).padStart(2, "0");
    return `#${hex(0)}${hex(2)}${hex(4)}`;
  };
  // Mercator projection with a consistent geographic resting area.
  const merc = xy => {
    const lon = Number(xy[0]) * Math.PI / 180;
    const lat = clamp(Number(xy[1]), -85, 85) * Math.PI / 180;
    return [lon, -Math.log(Math.tan(Math.PI / 4 + lat / 2))];
  };
  const ringsOf = geometry => {
    if (!geometry) return [];
    if (geometry.type === "Polygon") return geometry.coordinates || [];
    if (geometry.type === "MultiPolygon") return (geometry.coordinates || []).flat();
    return [];
  };
  function featureBounds(features) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    features.forEach(f => ringsOf(f.geometry).forEach(r => r.forEach(p => {
      const q = merc(p);
      minX = Math.min(minX, q[0]); maxX = Math.max(maxX, q[0]);
      minY = Math.min(minY, q[1]); maxY = Math.max(maxY, q[1]);
    })));
    if (!finite(minX)) throw Error("Invalid or empty geographic coordinates.");
    return [minX, minY, maxX, maxY];
  }
  function makeProjection(counties) {
    const b = featureBounds(counties);
    const aspect = (b[2] - b[0]) / Math.max(1e-9, b[3] - b[1]);
    const area = 190 * 370;
    let h = Math.sqrt(area / aspect), w = h * aspect;
    const shrink = Math.min(1, WIDTH * 0.46 / w, HEIGHT * 0.62 / h);
    w *= shrink; h *= shrink;
    const scale = Math.min(w / (b[2] - b[0]), h / (b[3] - b[1]));
    const cx = (b[0] + b[2]) / 2, cy = (b[1] + b[3]) / 2;
    return coord => {
      const m = merc(coord);
      return [WIDTH / 2 + (m[0] - cx) * scale, HEIGHT / 2 + (m[1] - cy) * scale];
    };
  }
  function geometryInfo(feature, project) {
    const geometry = feature.geometry || {};
    // Preserve polygon grouping: the first ring of EACH polygon is an outer
    // boundary, not just the first ring of the whole MultiPolygon.
    const polygons = geometry.type === "MultiPolygon" ? geometry.coordinates :
      geometry.type === "Polygon" ? [geometry.coordinates] : [];
    const rings = polygons.flatMap(polygon => polygon.map((coords, index) => ({
      points: coords.map(project), hole: index > 0
    })));
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    let cx = 0, cy = 0, weight = 0, path = "";
    rings.forEach(record => {
      const ring = record.points;
      if (!ring.length) return;
      path += ring.map((p, i) => `${i === 0 ? "M" : "L"}${p[0].toFixed(2)},${p[1].toFixed(2)}`).join(" ") + "Z ";
      let area = 0, ax = 0, ay = 0;
      ring.forEach((p, i) => {
        x0 = Math.min(x0, p[0]); x1 = Math.max(x1, p[0]);
        y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]);
        const n = ring[(i + 1) % ring.length];
        const cross = p[0] * n[1] - n[0] * p[1];
        area += cross; ax += (p[0] + n[0]) * cross; ay += (p[1] + n[1]) * cross;
      });
      if (Math.abs(area) > 1e-7) {
        const contribution = Math.abs(area) * (record.hole ? -1 : 1);
        cx += contribution * ax / (3 * area);
        cy += contribution * ay / (3 * area);
        weight += contribution;
      }
    });
    const center = Math.abs(weight) > 1e-7 ? [cx / weight, cy / weight] : [(x0 + x1) / 2, (y0 + y1) / 2];
    return { path, center, bounds: [[x0, y0], [x1, y1]] };
  }
  function curvedTrail(sx, sy, tx, ty) {
    const dx = tx - sx, dy = ty - sy;
    return `M${sx},${sy} C${sx + dx * .18},${sy + dy * .72} ${tx - dx * .18},${ty - dy * .72} ${tx},${ty}`;
  }
  const easeBack = t => { const s = 1.35, u = t - 1; return 1 + (s + 1) * u * u * u + s * u * u; };
  // Returning to the parent should settle gently, without an elastic overshoot.
  const easeInOut = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(2 - 2 * t, 3) / 2;
  function makeCountyId(feature) { return String(feature.properties?.id || feature.id || feature.properties?.geoid || ""); }
  function makeLocalId(feature) { return String(feature.properties?.id || feature.properties?.geoid || feature.id || ""); }
  const configFor = state => state === "tx" ? {
    name: "Texas", countyLabel: "counties", localLabel: "subdivisions", root: "tx/", state: "tx/state.geojson", counties: "tx/counties.geojson"
  } : {
    name: "New Jersey", countyLabel: "counties", localLabel: "municipalities", root: "", state: "nj_state.geojson", counties: "nj_counties.geojson"
  };

  // Use the deterministic geographic collision algorithm. Its
  // deterministic layout decisions are not substituted with random forces.
  function computeGeographicExpansion(features, parentCentroid, options) {
    if (!Array.isArray(features) || !features.length) return;

    const scale = Number(options.scale) || 1;
    const shapeScale = Number(options.shapeScale) || 1;
    const radialKick = Number(options.radialKick) || 0;
    const gap = Math.max(0, Number(options.gap) || 0);
    const iterations = Math.max(1, Math.round(Number(options.iterations) || 180));
    const cleanupIterations = options.cleanupIterations === undefined
      ? 90 : Math.max(0, Math.round(Number(options.cleanupIterations) || 0));
    const attraction = Math.max(0.01, Math.min(0.25, Number(options.attraction) || 0.08));
    const maxBearingDrift = Math.max(0.04, Number(options.maxBearingDrift) || 0.22);
    const offsetProperty = options.offsetProperty || "__baseBloomOffset";
    const [parentX, parentY] = parentCentroid;

    const nodes = features.map((feature, index) => {
      const [cx, cy] = feature.__centroid;
      let vx = cx - parentX;
      let vy = cy - parentY;
      let sourceRadius = Math.hypot(vx, vy);
      if (sourceRadius < 0.5) {
        const angle = (index / Math.max(1, features.length)) * Math.PI * 2 - Math.PI / 2;
        vx = Math.cos(angle);
        vy = Math.sin(angle);
        sourceRadius = 1;
      }
      const bearing = Math.atan2(vy, vx);
      const nx = vx / sourceRadius;
      const ny = vy / sourceRadius;
      const targetX = parentX + vx * scale + nx * radialKick;
      const targetY = parentY + vy * scale + ny * radialKick;
      const width = Math.max(0.5, feature.__bounds[1][0] - feature.__bounds[0][0]);
      const height = Math.max(0.5, feature.__bounds[1][1] - feature.__bounds[0][1]);
      return {
        feature,
        index,
        sourceX: cx,
        sourceY: cy,
        bearing,
        targetX,
        targetY,
        targetRadius: Math.hypot(targetX - parentX, targetY - parentY),
        halfWidth: width * (feature.__bloom === false ? 1 : shapeScale) / 2,
        halfHeight: height * (feature.__bloom === false ? 1 : shapeScale) / 2,
        x: targetX,
        y: targetY
      };
    });

    const normalizeAngle = angle => {
      let value = angle;
      while (value > Math.PI) value -= Math.PI * 2;
      while (value < -Math.PI) value += Math.PI * 2;
      return value;
    };

    for (let iteration = 0; iteration < iterations; iteration += 1) {
      nodes.forEach(node => {
        node.x += (node.targetX - node.x) * attraction;
        node.y += (node.targetY - node.y) * attraction;
      });

      for (let i = 0; i < nodes.length; i += 1) {
        for (let j = i + 1; j < nodes.length; j += 1) {
          const a = nodes[i];
          const b = nodes[j];
          let dx = b.x - a.x;
          let dy = b.y - a.y;
          const overlapX = a.halfWidth + b.halfWidth + gap - Math.abs(dx);
          const overlapY = a.halfHeight + b.halfHeight + gap - Math.abs(dy);
          if (overlapX <= 0 || overlapY <= 0) continue;

          if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) {
            const direction = a.index < b.index ? 1 : -1;
            dx = direction;
            dy = direction * 0.5;
          }

          if (overlapX < overlapY) {
            const direction = dx >= 0 ? 1 : -1;
            const shift = overlapX / 2 + 0.08;
            a.x -= direction * shift;
            b.x += direction * shift;
          } else {
            const direction = dy >= 0 ? 1 : -1;
            const shift = overlapY / 2 + 0.08;
            a.y -= direction * shift;
            b.y += direction * shift;
          }
        }
      }

      nodes.forEach(node => {
        const vx = node.x - parentX;
        const vy = node.y - parentY;
        const radius = Math.max(node.targetRadius * 0.78, Math.hypot(vx, vy));
        const currentBearing = Math.atan2(vy, vx);
        const drift = Math.max(-maxBearingDrift, Math.min(maxBearingDrift, normalizeAngle(currentBearing - node.bearing)));
        const bearing = node.bearing + drift;
        node.x = parentX + Math.cos(bearing) * radius;
        node.y = parentY + Math.sin(bearing) * radius;
        node.x = Math.max(EDGE_PADDING + node.halfWidth, Math.min(WIDTH - EDGE_PADDING - node.halfWidth, node.x));
        node.y = Math.max(EDGE_PADDING + node.halfHeight, Math.min(HEIGHT - EDGE_PADDING - node.halfHeight, node.y));
      });
    }

    for (let cleanup = 0; cleanup < cleanupIterations; cleanup += 1) {
      let collisions = 0;
      for (let i = 0; i < nodes.length; i += 1) {
        for (let j = i + 1; j < nodes.length; j += 1) {
          const a = nodes[i];
          const b = nodes[j];
          let dx = b.x - a.x;
          let dy = b.y - a.y;
          const overlapX = a.halfWidth + b.halfWidth + gap - Math.abs(dx);
          const overlapY = a.halfHeight + b.halfHeight + gap - Math.abs(dy);
          if (overlapX <= 0 || overlapY <= 0) continue;
          collisions += 1;
          if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) {
            const direction = a.index < b.index ? 1 : -1;
            dx = direction;
            dy = direction * 0.5;
          }
          if (overlapX < overlapY) {
            const direction = dx >= 0 ? 1 : -1;
            const shift = overlapX / 2 + 0.12;
            a.x -= direction * shift;
            b.x += direction * shift;
          } else {
            const direction = dy >= 0 ? 1 : -1;
            const shift = overlapY / 2 + 0.12;
            a.y -= direction * shift;
            b.y += direction * shift;
          }
        }
      }
      nodes.forEach(node => {
        node.x = Math.max(EDGE_PADDING + node.halfWidth, Math.min(WIDTH - EDGE_PADDING - node.halfWidth, node.x));
        node.y = Math.max(EDGE_PADDING + node.halfHeight, Math.min(HEIGHT - EDGE_PADDING - node.halfHeight, node.y));
      });
      if (!collisions) break;
    }

    nodes.forEach(node => {
      node.feature[offsetProperty] = {
        x: node.x - node.sourceX,
        y: node.y - node.sourceY
      };
    });
  }



  class BloomMap {
    constructor(el, config) {
      this.el = el;
      this.config = Object.assign({ geography: "nj", theme: "light", preset: "dashboard", appearance: "seamless", controls: false, dots: true, connectors: true,
        overviewBoundaries: true, localBoundaries: true, localOrigin: "original", labels: "none", labelAreas: [],
        draggable: true, duration: 470, showLegend: true, mapZoom: 1, bloomSpread: 1, bloomScale: 1 }, config || {});
      if (this.config.bloomAreas != null && !Array.isArray(this.config.bloomAreas)) {
        this.config.bloomAreas = [this.config.bloomAreas];
      }
      this.config.labels = ["none", "selected", "all", "custom"].includes(this.config.labels) ? this.config.labels : "none";
      this.config.localOrigin = this.config.localOrigin === "expanded" ? "expanded" : "original";
      // Geographic IDs are kept as strings, including leading zeros.
      const initialLabels = this.config.labelAreas;
      this.pinnedLabels = new Set((Array.isArray(initialLabels) ? initialLabels :
        initialLabels == null ? [] : [initialLabels]).map(String));
      this.stateId = this.config.geography === "custom" ? "custom" : this.config.geography === "tx" ? "tx" : "nj";
      this.meta = this.config.customMeta || configFor(this.stateId);
      this.id = el.id || `bloomr-${Math.random().toString(36).slice(2)}`;
      this.manualCounty = new Map(); this.manualLocal = new Map();
      this.counties = []; this.locals = [];
      this.countyExpanded = false; this.localExpanded = false;
      this.selected = null; this.selectedLocal = null; this.destroyed = false;
      this.currentAnimation = null; this.drag = null; this.busy = false;
      this.camera = { k: 1, x: 0, y: 0 };
      this.countyCamera = null;
      this.localBaseShift = { x: 0, y: 0 };
      this.focusCounty = null; this.focusLocal = null;
      this.values = new Map(); this.updateValues(this.config.data || []);
      this.tooltipDetails = new Map(); this.updateTooltipRows(this.config.tooltipRows || []);
      this.activeTipKey = null;
      instances.set(this.id, this);
      this._build();
      this._initialize();
    }
    _build() {
      const el = this.el;
      el.replaceChildren();
      el.classList.add("bloomr-widget");
      el.dataset.bloomAppearance = this.config.appearance === "seamless" ? "seamless" : "card";
      el.dataset.bloomTheme = this.config.theme === "dark" ? "dark" : this.config.theme === "auto" && global.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light";
      el.setAttribute("aria-label", "Hierarchical geographic bloom visualization");
      // Escape closes the display menu first, then returns one geography level.
      this.onEscape = e => {
        if (e.key !== "Escape") return;
        if (this.displayPanel && !this.displayPanel.hidden) {
          e.preventDefault(); e.stopPropagation(); this._closeDisplay(true);
        } else if (this.localExpanded || this.countyExpanded) {
          e.preventDefault(); e.stopPropagation(); this.back(true);
        }
      };
      el.addEventListener("keydown", this.onEscape);
      this.shell = html("div", "bloomr-shell", el);
      const toolbar = html("div", "bloomr-toolbar", this.shell);
      toolbar.hidden = !this.config.controls;
      this.title = html("div", "bloomr-title", toolbar, this.meta.name + " Bloom");
      const actions = html("div", "bloomr-actions", toolbar);
      const button = (label, text, action) => {
        const b = html("button", "bloomr-button", actions, text);
        b.type = "button"; b.setAttribute("aria-label", label);
        b.addEventListener("click", action);
        return b;
      };
      this.backButton = button("Return to parent geography", "Back", () => this.back());
      this.bloomButton = button("Expand " + this.meta.countyLabel, "Bloom " + this.meta.countyLabel, () => this.expandCounties());
      this.localButton = button("Expand selected " + (this.stateId === "custom" ? "region" : "county"), "Bloom " + this.meta.localLabel, () => this.expandLocal());
      button("Zoom in", "+", () => this.zoom(1.3));
      button("Zoom out", "−", () => this.zoom(1 / 1.3));
      button("Reset map view", "Fit", () => this._resetCamera());
      this.displayButton = button("Map display options", "Display", () => this._toggleDisplay());
      this.displayButton.setAttribute("aria-expanded", "false");
      this.displayButton.setAttribute("aria-controls", this.id + "-display");
      if (this.config.preset !== "viewer") button("Export visible map as SVG", "SVG", () => this.exportSvg());
      // Compact display controls.
      this.displayPanel = html("div", "bloomr-display-panel", this.shell);
      this.displayPanel.id = this.id + "-display";
      this.displayPanel.hidden = true;
      this.displayPanel.setAttribute("role", "group");
      this.displayPanel.setAttribute("aria-label", "Map display options");
      const check = (text, key, value) => {
        const row = html("label", "bloomr-display-option", this.displayPanel);
        const control = html("input", "", row);
        control.type = "checkbox"; control.checked = value;
        html("span", "", row, text);
        control.addEventListener("change", () => {
          this.config[key] = control.checked;
          this._updateBoundaryVisibility();
        });
        return { row, control };
      };
      this.overviewOption = check("Overview boundaries", "overviewBoundaries", this.config.overviewBoundaries);
      this.localOption = check("Local boundaries", "localBoundaries", this.config.localBoundaries);
      const originRow = html("label", "bloomr-display-option", this.displayPanel);
      this.localOriginOption = { row: originRow, control: html("input", "", originRow) };
      this.localOriginOption.control.type = "checkbox";
      this.localOriginOption.control.checked = this.config.localOrigin === "expanded";
      html("span", "", originRow, "Bloom from expanded parent");
      this.localOriginOption.control.addEventListener("change", () => {
        this.config.localOrigin = this.localOriginOption.control.checked ? "expanded" : "original";
      });
      const labelRow = html("label", "bloomr-display-option", this.displayPanel);
      html("span", "", labelRow, "Map labels");
      this.labelSelect = html("select", "bloomr-label-select", labelRow);
      [
        ["none", "Off (tooltips on)"], ["selected", "Selected area"],
        ["all", "All (avoid overlap)"], ["custom", "Chosen areas"]
      ].forEach(([value, name]) => {
        const option = html("option", "", this.labelSelect, name);
        option.value = value;
      });
      this.labelSelect.value = this.config.labels;
      this.labelSelect.addEventListener("change", () => {
        this.config.labels = this.labelSelect.value;
        this._updateLabels();
        this._updateDisplayHelp();
      });
      this.displayHelp = html("p", "bloomr-display-help", this.displayPanel);
      this._updateDisplayHelp();
      this.stage = html("div", "bloomr-stage", this.shell);
      this.svg = elem("svg", "bloomr-svg", this.stage);
      this.svg.setAttribute("viewBox", `0 0 ${WIDTH} ${HEIGHT}`);
      this.svg.setAttribute("role", "img");
      this.svg.setAttribute("aria-label", this.meta.name + ": expand the map into " + this.meta.countyLabel +
        (this.config.maxLevel === "county" ? "." : ", then into " + this.meta.localLabel + ".") +
        " Original-location dots and dotted connector lines show geographic relationships.");
      this.svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
      // When the full toolbar is hidden, retain only the buttons needed to
      // navigate on touch screens. Click and keyboard controls still work.
      this.minimalNav = html("div", "bloomr-minimal-nav", this.stage);
      this.minimalBack = html("button", "bloomr-button", this.minimalNav, "Back");
      this.minimalBack.type = "button";
      this.minimalBack.setAttribute("aria-label", "Return to parent geography");
      this.minimalBack.addEventListener("click", () => this.back());
      this.minimalExplore = html("button", "bloomr-button", this.minimalNav, "Explore");
      this.minimalExplore.type = "button";
      this.minimalExplore.setAttribute("aria-label", "Explore selected region");
      this.minimalExplore.addEventListener("click", () => this.expandLocal());
      this.minimalNav.hidden = true;
      // With no toolbar, clicking empty map space also opens the overview.
      this.svg.addEventListener("click", e => {
        if (!this.config.controls && e.target === this.svg && !this.countyExpanded) {
          this.expandCounties();
        }
      });
      this.svg.addEventListener("dblclick", e => {
        if (!this.config.controls && e.target === this.svg) {
          e.preventDefault();
          this.back();
        }
      });
      // Ctrl + wheel gives toolbar-free views a zoom gesture, without
      // swallowing the dashboard's normal mouse-wheel page scrolling.
      this.svg.addEventListener("wheel", e => {
        if (this.config.controls || (!e.ctrlKey && !e.metaKey)) return;
        e.preventDefault();
        const box = this.svg.getBoundingClientRect();
        const scale = Math.max(1e-6, Math.min(box.width / WIDTH, box.height / HEIGHT));
        const mx = (e.clientX - box.left - (box.width - scale * WIDTH) / 2) / scale;
        const my = (e.clientY - box.top - (box.height - scale * HEIGHT) / 2) / scale;
        const next = clamp(this.camera.k * (e.deltaY < 0 ? 1.1 : 1 / 1.1), .65, 3.5);
        this.setCamera(next, mx - (mx - this.camera.x) * next / this.camera.k,
          my - (my - this.camera.y) * next / this.camera.k);
      }, { passive: false });
      this.viewport = elem("g", "bloomr-viewport", this.svg);
      this._resetCamera();
      this.stateLayer = elem("g", "bloomr-state-layer", this.viewport);
      this.refLayer = elem("g", "bloomr-reference-layer", this.viewport);
      this.lineLayer = elem("g", "bloomr-line-layer", this.viewport);
      this.dotLayer = elem("g", "bloomr-dot-layer", this.viewport);
      this.shapeLayer = elem("g", "bloomr-shape-layer", this.viewport);
      this.countyLabelLayer = elem("g", "bloomr-county-label-layer", this.viewport);
      this.localRefLayer = elem("g", "bloomr-local-reference-layer", this.viewport);
      this.localLineLayer = elem("g", "bloomr-local-line-layer", this.viewport);
      this.localDotLayer = elem("g", "bloomr-local-dot-layer", this.viewport);
      this.localShapeLayer = elem("g", "bloomr-local-shape-layer", this.viewport);
      this.localLabelLayer = elem("g", "bloomr-local-label-layer", this.viewport);
      this.frameLayer = elem("g", "bloomr-frame-layer", this.viewport);
      this.tip = html("div", "bloomr-tooltip", this.stage);
      this.tip.setAttribute("role", "tooltip");
      this.tip.hidden = true;
      this.legend = html("div", "bloomr-legend", this.stage);
      this._updateLegend();
      this.status = html("div", "bloomr-status", this.shell, "Loading geography...");
      this.status.setAttribute("role", "status"); this.status.setAttribute("aria-live", "polite");
      this._refreshToolbar();
    }
    async _getJSON(relative) {
      const base = global.BloomrGeoBase;
      if (!base && !this.config.inlineGeometry) throw Error("Bundled geographic assets not found.");
      const url = new URL(relative, base || global.location.href).href;
      const response = await fetch(url);
      if (!response.ok) throw Error(`Could not load ${relative} (HTTP ${response.status}).`);
      return response.json();
    }
    _readGeometry(raw) {
      return typeof raw === "string" ? JSON.parse(raw) : raw;
    }
    async _initialize() {
      try {
        const geometry = this.config.inlineGeometry;
        const [state, counties] = geometry ? [this._readGeometry(geometry.state), this._readGeometry(geometry.counties)] : await Promise.all([
          this._getJSON(this.meta.state), this._getJSON(this.meta.counties)
        ]);
        if (this.destroyed) return;
        const region = state.type === "FeatureCollection" ? state.features[0] : state;
        if (!region?.geometry || !Array.isArray(counties?.features) || !counties.features.length) throw Error("Missing state or county polygons.");
        this.project = makeProjection(counties.features);
        this.stateInfo = geometryInfo(region, this.project);
        this.stateCenter = this.stateInfo.center;
        this.counties = counties.features.slice().sort((a, b) => String(a.properties?.name).localeCompare(String(b.properties?.name))).map(f => this._prepare(f, "county"));
        const spread = clamp(Number(this.config.bloomSpread) || 1, .5, 1.5);
        computeGeographicExpansion(this.counties, this.stateCenter, {
          scale: 1 + .67 * .95 * spread, radialKick: 34 * .95 * spread, gap: (7 + .95 * 2.2) * spread,
          shapeScale: this.config.bloomScale,
          iterations: 190, cleanupIterations: 90, attraction: .085,
          maxBearingDrift: .20, offsetProperty: "__baseCountyOffset"
        });
        this.statePath = elem("path", "bloomr-parent", this.stateLayer);
        this.statePath.setAttribute("d", this.stateInfo.path);
        this.statePath.setAttribute("tabindex", "0");
        this.statePath.setAttribute("role", "button");
        this.statePath.setAttribute("aria-label", "Expand " + this.meta.name + " into " + this.meta.countyLabel);
        this.statePath.addEventListener("click", () => this.expandCounties());
        this.statePath.addEventListener("keydown", e => {
          if (e.key === "Enter" || e.key === " ") { e.preventDefault(); this.expandCounties(); }
        });
        this.counties.forEach((f, i) => {
          // The fixed reference is where the county belongs in the state.
          // It never moves with the expanded polygon.
          const reference = elem("path", "bloomr-overview-reference", this.refLayer);
          reference.setAttribute("d", f.__path);
          f.trail = elem("path", "bloomr-connector", this.lineLayer);
          f.dot = elem("circle", "bloomr-origin-dot bloomr-halo", this.dotLayer);
          f.pathEl = elem("path", "bloomr-county", this.shapeLayer);
          f.pathEl.setAttribute("d", f.__path);
          f.pathEl.setAttribute("tabindex", "0");
          f.pathEl.setAttribute("role", "button");
          f.pathEl.setAttribute("aria-label", `${f.__name}, select county`);
          f.pathEl.setAttribute("fill", this._color(f, "county", i));
          f.pathEl.addEventListener("pointerenter", e => this._tooltip(e, f));
          f.pathEl.addEventListener("pointermove", e => this._tooltip(e, f));
          f.pathEl.addEventListener("pointerleave", () => this._hideTip());
          f.pathEl.addEventListener("click", e => {
            if (f.__suppressClickUntil && performance.now() <= f.__suppressClickUntil) return;
            if (e.shiftKey) this._togglePinned(f);
            else this.select(f.__id);
          });
          f.pathEl.addEventListener("dblclick", () => { this.select(f.__id); this.expandLocal(); });
          f.pathEl.addEventListener("keydown", e => this._regionKeydown(e, f, "county"));
          this._attachDrag(f, "county");
          this._makeLabel(f, this.countyLabelLayer);
        });
        this._updateBoundaryVisibility();
        this._render(0);
        this._updateLabels();
        this._updateLegend();
        this.ready = true;
        this._syncKeyboardFocus();
        this.status.textContent = `${this.meta.name} ready. Click the map or press Enter to bloom ${this.meta.countyLabel}.`;
        this._refreshToolbar();
      } catch (error) {
        if (!this.destroyed) {
          this.status.textContent = error.message || "Map initialization failed.";
          this.status.classList.add("bloomr-error");
          console.error("bloomr initialization:", error);
        }
      }
    }
    _prepare(f, level) {
      const info = geometryInfo(f, this.project);
      const p = f.properties || {};
      f.__id = level === "county" ? makeCountyId(f) : makeLocalId(f);
      f.__geoid = String(p.geoid || p.CENSUS2020 || "");
      f.__name = String(p.name || p.MUN_LABEL || p.NAME || p.short_name || f.__id);
      f.__path = info.path;
      f.__centroid = info.center;
      f.__bounds = info.bounds;
      f.__level = level;
      f.__bloom = level !== "county" || this.config.bloomAreas == null ||
        this.config.bloomAreas.includes(f.__id) || this.config.bloomAreas.includes(f.__geoid);
      return f;
    }
    _color(f, level, index) {
      if (level === "county" && f.__bloom && this.config.bloomColor) return this.config.bloomColor;
      const key = this.values.has(f.__geoid) ? f.__geoid : f.__id;
      const matchesLevel = (level === "county" ? this.counties : this.locals).some(item => this.values.has(item.__geoid) || this.values.has(item.__id));
      if (matchesLevel) {
        const entry = this.values.get(key);
        if (entry === null || !finite(entry)) return "#CBD5E1";
        const finiteValues = (level === "county" ? this.counties : this.locals)
          .map(item => this.values.get(this.values.has(item.__geoid) ? item.__geoid : item.__id)).filter(finite);
        const min = Math.min(...finiteValues), max = Math.max(...finiteValues);
        return hexMix("#BFDBFE", "#155E75", min === max ? .55 : clamp((entry - min) / (max - min), 0, 1));
      }
      if (level === "local") return hexMix("#A7D7F1", "#2B6DB1", index / Math.max(1, this.locals.length - 1));
      return hexMix("#8FB8E8", "#2D9C9D", index / Math.max(1, this.counties.length - 1));
    }
    _offset(f) {
      if (f.__bloom === false) return { x: 0, y: 0 };
      const base = f.__level === "local" ? f.__baseMunicipalityOffset : f.__baseCountyOffset;
      const manual = f.__level === "local" ? this.manualLocal.get(f.__id) : this.manualCounty.get(f.__id);
      return add(base, manual);
    }
    _renderNode(f, progress) {
      const movedProgress = f.__bloom === false ? 0 : progress;
      const o = this._offset(f), dx = o.x * movedProgress, dy = o.y * movedProgress;
      const shapeScale = 1 + (this.config.bloomScale - 1) * clamp(movedProgress, 0, 1);
      const [cx, cy] = f.__centroid;
      f.pathEl.setAttribute("transform", shapeScale === 1
        ? `translate(${dx},${dy})`
        : `translate(${dx},${dy}) translate(${cx},${cy}) scale(${shapeScale}) translate(${-cx},${-cy})`);
      f.pathEl.setAttribute("opacity", progress <= 0 ? 0 : 1);
      f.pathEl.setAttribute("pointer-events", progress > .85 ? "all" : "none");
      if (f.trail) {
        const sx = f.__centroid[0], sy = f.__centroid[1];
        f.trail.setAttribute("d", curvedTrail(sx, sy, sx + dx, sy + dy));
        f.trail.setAttribute("opacity", this.config.connectors && movedProgress > 0 ? .75 : 0);
        f.trail.style.display = this.config.connectors ? "" : "none";
      }
      if (f.dot) {
        f.dot.setAttribute("cx", f.__centroid[0]); f.dot.setAttribute("cy", f.__centroid[1]);
        f.dot.setAttribute("r", f.__level === "county" ? "3.1" : "2.5");
        f.dot.setAttribute("opacity", this.config.dots && movedProgress > 0 ? .85 : 0);
        f.dot.style.display = this.config.dots ? "" : "none";
      }
      if (f.labelEl) {
        f.labelEl.setAttribute("transform", `translate(${dx},${dy})`);
        f.labelEl.style.opacity = String(clamp(progress, 0, 1));
      }
    }
    _render(progress) {
      this.counties.forEach(f => this._renderNode(f, progress));
      this.statePath?.setAttribute("opacity", progress > 0 ? .20 : 1);
      this.statePath?.setAttribute("pointer-events", progress > 0 ? "none" : "all");
    }
    _animate(ms, onFrame, done, easing = easeBack) {
      if (this.currentAnimation !== null) cancelAnimationFrame(this.currentAnimation);
      const reduced = global.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
      if (reduced || ms <= 0) { onFrame(1, 1); done?.(); return; }
      this.busy = true; this._refreshToolbar();
      const started = performance.now();
      const tick = now => {
        if (this.destroyed) return;
        const t = clamp((now - started) / ms, 0, 1);
        onFrame(easing(t), t);
        if (t < 1) this.currentAnimation = requestAnimationFrame(tick);
        else { this.currentAnimation = null; this.busy = false; done?.(); this._refreshToolbar(); }
      };
      this.currentAnimation = requestAnimationFrame(tick);
    }
    _moveCamera(from, to, t) {
      this.setCamera(from.k + (to.k - from.k) * t,
        from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t);
    }
    _countyAppearance(progress) {
      const t = clamp(progress, 0, 1);
      this.counties.forEach(f => {
        const faded = f === this.selected ? .12 : .03;
        f.pathEl.style.opacity = String(1 - (1 - faded) * t);
        f.pathEl.style.pointerEvents = t > 0 ? "none" : "";
        f.dot.style.opacity = String(1 - t);
        f.trail.style.opacity = String(1 - t);
      });
      this.statePath.style.opacity = String(.20 - .10 * t);
      this.refLayer.style.opacity = String(1 - t);
      this.countyLabelLayer.style.opacity = String(1 - t);
      this.localRefLayer.style.opacity = String(t);
    }
    _restoreCountyAppearance() {
      this.counties.forEach(f => {
        f.pathEl.style.opacity = "";
        f.pathEl.style.pointerEvents = "";
        f.dot.style.opacity = "";
        f.trail.style.opacity = "";
      });
      this.statePath.style.opacity = "";
      this.refLayer.style.opacity = "";
      this.countyLabelLayer.style.opacity = "";
      this.localRefLayer.style.opacity = "";
    }
    _toggleDisplay() {
      const opening = this.displayPanel.hidden;
      this.displayPanel.hidden = !opening;
      this.displayButton.setAttribute("aria-expanded", String(opening));
      if (opening) this.overviewOption.control.focus();
    }
    _closeDisplay(focus = false) {
      this.displayPanel.hidden = true;
      this.displayButton.setAttribute("aria-expanded", "false");
      if (focus) this.displayButton.focus();
    }
    _updateDisplayHelp() {
      if (!this.displayHelp) return;
      const singular = word => ({ counties: "county", municipalities: "municipality",
        subdivisions: "subdivision", regions: "region", areas: "area" })[word] || word.replace(/s$/, "");
      this.overviewOption.row.querySelector("span").textContent = `Overview: ${singular(this.meta.countyLabel)} lines`;
      this.localOption.row.querySelector("span").textContent = `Local: ${singular(this.meta.localLabel)} lines`;
      this.overviewOption.row.title = "Show region outlines at their original locations in the map";
      this.localOption.row.title = `Show ${this.meta.localLabel} outlines at their starting locations inside the selected region`;
      this.localOriginOption.row.title = "Start the local bloom where the parent has expanded or been dragged. Leave off to use its original position.";
      this.displayHelp.textContent = this.config.labels === "custom"
        ? "Shift+click an area, or focus it and press L, to add or remove its label."
        : "Hover over an area for its name. Labels are optional.";
    }
    _updateBoundaryVisibility() {
      if (this.refLayer) this.refLayer.style.display = this.config.overviewBoundaries ? "" : "none";
      if (this.localRefLayer) this.localRefLayer.style.display = this.config.localBoundaries ? "" : "none";
    }
    _makeLabel(f, layer) {
      const label = elem("text", "bloomr-area-label", layer);
      label.textContent = f.__name;
      label.setAttribute("x", f.__centroid[0]);
      label.setAttribute("y", f.__centroid[1] - 5);
      label.setAttribute("text-anchor", "middle");
      label.setAttribute("aria-hidden", "true");
      label.style.display = "none";
      f.labelEl = label;
    }
    _togglePinned(f) {
      const key = f.__id;
      if (this.pinnedLabels.has(key)) this.pinnedLabels.delete(key);
      else this.pinnedLabels.add(key);
      this.config.labels = "custom";
      this.labelSelect.value = "custom";
      this._updateDisplayHelp();
      this._updateLabels();
      this.status.textContent = `${f.__name} label ${this.pinnedLabels.has(key) ? "shown" : "hidden"}.`;
    }
    _updateLabels() {
      if (!this.countyLabelLayer) return;
      const level = this.localExpanded ? "local" : this.countyExpanded ? "county" : null;
      const features = level === "local" ? this.locals : level === "county" ? this.counties : [];
      const visible = this.config.labels;
      const selected = level === "local" ? this.selectedLocal : this.selected;
      // For all labels, keep a simple collision filter. Customized or selected
      // labels should never be silently removed by collision detection.
      const occupied = [];
      for (const f of features) {
        if (!f.labelEl) continue;
        const show = visible === "all" || (visible === "selected" && selected === f) ||
          (visible === "custom" && (this.pinnedLabels.has(f.__id) || this.pinnedLabels.has(f.__geoid)));
        if (!show) { f.labelEl.style.display = "none"; continue; }
        const offset = this._offset(f);
        const centerX = f.__centroid[0] + offset.x, centerY = f.__centroid[1] + offset.y - 5;
        const halfWidth = Math.min(88, 3.5 * f.__name.length + 7);
        const box = [centerX - halfWidth, centerY - 12, centerX + halfWidth, centerY + 5];
        const clash = visible === "all" && occupied.some(r => !(box[2] < r[0] || box[0] > r[2] || box[3] < r[1] || box[1] > r[3]));
        f.labelEl.style.display = clash ? "none" : "";
        if (!clash) occupied.push(box);
      }
      // County labels must not linger when a local view is fully expanded.
      this.counties.forEach(f => {
        if (f.labelEl && level !== "county") f.labelEl.style.display = "none";
      });
      if (level !== "local") this.locals.forEach(f => { if (f.labelEl) f.labelEl.style.display = "none"; });
    }
    expandCounties() {
      if (!this.ready || this.busy || this.countyExpanded) return;
      this.countyExpanded = true;
      this._animate(this.config.duration, t => this._render(t), () => {
        this._updateLabels();
        this._updateLegend();
        this._syncKeyboardFocus();
        this.status.textContent = `${this.counties.length} ${this.meta.countyLabel} expanded. Select a region to explore ${this.meta.localLabel}.`;
      });
      this._refreshToolbar();
    }
    async expandLocal() {
      if (this.config.maxLevel === "county") return;
      if (!this.ready || this.busy || !this.countyExpanded || !this.selected || this.localExpanded) return;
      this.localExpanded = true;
      this.status.textContent = `Loading ${this.selected.__name} ${this.meta.localLabel}...`;
      this._refreshToolbar();
      try {
        const relative = `${this.meta.root}municipalities/${this.selected.__id}.geojson`;
        const inlineLocal = this.config.inlineGeometry?.local?.[this.selected.__id];
        const collection = inlineLocal ? this._readGeometry(inlineLocal) :
          (this.stateId === "custom" ? null : await this._getJSON(relative));
        if (this.destroyed || !this.localExpanded) return;
        if (!Array.isArray(collection?.features)) throw Error("Local-area boundaries could not be loaded.");
        this.locals = collection.features.map(f => this._prepare(f, "local"));
        // Move the complete local geography as one unit. Keep its own bloom
        // offsets unchanged so collision spacing and drag offsets are stable.
        this.localBaseShift = this.config.localOrigin === "expanded"
          ? { ...this._offset(this.selected) } : { x: 0, y: 0 };
        this._positionLocalLayers();
        const countBoost = Math.min(1.35, Math.max(0, (this.locals.length - 15) / 55));
        const spread = clamp(Number(this.config.bloomSpread) || 1, .5, 1.5);
        computeGeographicExpansion(this.locals, this.selected.__centroid, {
          scale: 1 + (2.25 + .95 * .95 + countBoost - 1) * spread,
          radialKick: (10 + .95 * 7 + countBoost * 5) * spread,
          gap: (4.5 + countBoost * 2.4) * spread, iterations: 240, cleanupIterations: 90,
          shapeScale: this.config.bloomScale,
          attraction: .072, maxBearingDrift: .24, offsetProperty: "__baseMunicipalityOffset"
        });
        this.localRefLayer.replaceChildren(); this.localLineLayer.replaceChildren();
        this.localDotLayer.replaceChildren(); this.localShapeLayer.replaceChildren();
        this.localLabelLayer.replaceChildren();
        this.locals.forEach((f, i) => {
          const line = elem("path", "bloomr-local-reference", this.localRefLayer);
          line.setAttribute("d", f.__path);
          f.trail = elem("path", "bloomr-connector bloomr-local-connector", this.localLineLayer);
          f.dot = elem("circle", "bloomr-origin-dot bloomr-local-dot", this.localDotLayer);
          f.pathEl = elem("path", "bloomr-local", this.localShapeLayer);
          f.pathEl.setAttribute("d", f.__path);
          f.pathEl.setAttribute("fill", this._color(f, "local", i));
          f.pathEl.setAttribute("role", "button");
          f.pathEl.setAttribute("aria-label", f.__name + ", select local area");
          f.pathEl.setAttribute("tabindex", "0");
          f.pathEl.addEventListener("pointerenter", e => this._tooltip(e, f));
          f.pathEl.addEventListener("pointermove", e => this._tooltip(e, f));
          f.pathEl.addEventListener("pointerleave", () => this._hideTip());
          f.pathEl.addEventListener("click", e => {
            if (f.__suppressClickUntil && performance.now() <= f.__suppressClickUntil) return;
            if (e.shiftKey) this._togglePinned(f);
            else this.select(f.__id, "local");
          });
          f.pathEl.addEventListener("keydown", e => this._regionKeydown(e, f, "local"));
          this._attachDrag(f, "local");
          this._makeLabel(f, this.localLabelLayer);
        });
        this._updateBoundaryVisibility();
        this._updateLabels();
        this.countyCamera = { ...this.camera };
        const localCamera = this._localCamera();
        this._animate(this.config.duration, (t, raw) => {
          this.locals.forEach(f => this._renderNode(f, t));
          const q = easeInOut(raw);
          this._countyAppearance(q);
          this._moveCamera(this.countyCamera, localCamera, q);
        }, () => {
          this._updateLabels();
          this._updateLegend();
          this._syncKeyboardFocus();
          this.status.textContent = `${this.selected.__name}: ${this.locals.length} ${this.meta.localLabel} expanded.`;
        });
      } catch (error) {
        this.localExpanded = false;
        this.localBaseShift = { x: 0, y: 0 };
        this._positionLocalLayers();
        this.status.textContent = error.message || "Unable to load local geography.";
        this._refreshToolbar();
      }
    }
    // All local layers share one translation, including the fixed origin
    // outlines and dotted guides. Local drag offsets remain relative to it.
    _positionLocalLayers() {
      const shift = this.localBaseShift || { x: 0, y: 0 };
      const transform = shift.x || shift.y ? `translate(${shift.x},${shift.y})` : "";
      [this.localRefLayer, this.localLineLayer, this.localDotLayer,
        this.localShapeLayer, this.localLabelLayer].forEach(layer => {
        if (layer) layer.setAttribute("transform", transform);
      });
    }
    _localCamera() {
      const f = this.selected;
      if (!f) return { ...this.camera };
      const shift = this.localBaseShift || { x: 0, y: 0 };
      const xs = [f.__bounds[0][0] + shift.x, f.__bounds[1][0] + shift.x];
      const ys = [f.__bounds[0][1] + shift.y, f.__bounds[1][1] + shift.y];
      this.locals.forEach(l => {
        const o = this._offset(l);
        const s = l.__bloom === false ? 1 : this.config.bloomScale;
        const halfWidth = (l.__bounds[1][0] - l.__bounds[0][0]) * s / 2;
        const halfHeight = (l.__bounds[1][1] - l.__bounds[0][1]) * s / 2;
        xs.push(l.__centroid[0] + o.x + shift.x - halfWidth,
          l.__centroid[0] + o.x + shift.x + halfWidth);
        ys.push(l.__centroid[1] + o.y + shift.y - halfHeight,
          l.__centroid[1] + o.y + shift.y + halfHeight);
      });
      const left = Math.min(...xs) - 28, right = Math.max(...xs) + 28;
      const top = Math.min(...ys) - 28, bottom = Math.max(...ys) + 28;
      const k = clamp(Math.min(WIDTH * .78 / (right - left), HEIGHT * .75 / (bottom - top)), 1, 2.6);
      return { k, x: WIDTH / 2 - k * (left + right) / 2,
        y: HEIGHT / 2 - k * (top + bottom) / 2 };
    }
    back(focusAfter = false) {
      if (!this.ready || this.busy) return;
      this._hideTip();
      if (this.localExpanded) {
        const localCamera = { ...this.camera };
        const countyCamera = this.countyCamera || { k: 1, x: 0, y: 0 };
        this._animate(this.config.duration, t => {
          const remaining = 1 - t;
          this.locals.forEach(f => {
            this._renderNode(f, remaining);
            f.pathEl.style.opacity = String(clamp(remaining * 3, 0, 1));
          });
          this._countyAppearance(remaining);
          this._moveCamera(localCamera, countyCamera, t);
        }, () => {
          this.localExpanded = false; this.selectedLocal = null; this.locals = [];
          this.localRefLayer.replaceChildren(); this.localLineLayer.replaceChildren();
          this.localDotLayer.replaceChildren(); this.localShapeLayer.replaceChildren();
          this.localLabelLayer.replaceChildren();
          this.localBaseShift = { x: 0, y: 0 };
          this._positionLocalLayers();
          this._restoreCountyAppearance();
          this._updateLabels();
          this._updateLegend();
          this._render(1);
          this.setCamera(countyCamera.k, countyCamera.x, countyCamera.y);
          this._syncKeyboardFocus();
          if (focusAfter) (this.selected?.pathEl || this.backButton).focus();
          this.status.textContent = "Parent region view restored.";
          this._refreshToolbar();
        }, easeInOut);
      } else if (this.countyExpanded) {
        this._animate(this.config.duration, t => this._render(1 - t), () => {
          this.countyExpanded = false; this.selected = null; this.focusCounty = null;
          this.counties.forEach(f => f.pathEl.classList.remove("bloomr-selected"));
          this._updateLabels();
          this._updateLegend();
          this._syncKeyboardFocus();
          if (focusAfter) this.statePath.focus();
          this.status.textContent = this.meta.name + " restored.";
          this._refreshToolbar();
        }, easeInOut);
      }
    }
    // One Tab stop for the active geography; arrows move between regions.
    _syncKeyboardFocus() {
      if (!this.statePath) return;
      this.statePath.setAttribute("tabindex", this.countyExpanded ? "-1" : "0");
      this.counties.forEach(f => f.pathEl.setAttribute("tabindex", "-1"));
      this.locals.forEach(f => f.pathEl.setAttribute("tabindex", "-1"));
      const pool = this.localExpanded ? this.locals : this.countyExpanded ? this.counties : [];
      const chosen = this.localExpanded ? this.focusLocal || this.selectedLocal : this.focusCounty || this.selected;
      const active = pool.includes(chosen) ? chosen : pool[0];
      if (active) active.pathEl.setAttribute("tabindex", "0");
    }
    _regionKeydown(e, f, level) {
      if (this.busy || (level === "local" ? !this.localExpanded : !this.countyExpanded || this.localExpanded)) return;
      if (e.key.toLowerCase() === "l" && !e.altKey && !e.ctrlKey && !e.metaKey) {
        e.preventDefault(); this._togglePinned(f); return;
      }
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        if (level === "county" && this.selected === f && this.config.maxLevel !== "county") this.expandLocal();
        else this.select(f.__id, level);
        return;
      }
      if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(e.key)) return;
      e.preventDefault();
      const pool = level === "local" ? this.locals : this.counties;
      const index = pool.indexOf(f);
      const next = e.key === "Home" ? 0 : e.key === "End" ? pool.length - 1 :
        (index + (e.key === "ArrowLeft" || e.key === "ArrowUp" ? -1 : 1) + pool.length) % pool.length;
      if (level === "local") this.focusLocal = pool[next];
      else this.focusCounty = pool[next];
      this._syncKeyboardFocus();
      pool[next].pathEl.focus();
    }
    _refreshToolbar() {
      if (!this.bloomButton) return;
      if (this.localOriginOption) this.localOriginOption.control.disabled = !!this.localExpanded || !!this.busy;
      this.backButton.hidden = !(this.countyExpanded || this.localExpanded);
      this.bloomButton.hidden = this.countyExpanded;
      this.localButton.hidden = this.config.maxLevel === "county" || !(this.countyExpanded && !this.localExpanded && this.selected);
      for (const button of [this.backButton, this.bloomButton, this.localButton]) button.disabled = !!this.busy;
      if (this.localButton && this.selected) this.localButton.textContent = `Bloom ${this.meta.localLabel}`;
      if (this.minimalNav) {
        const canBack = this.countyExpanded || this.localExpanded;
        const canExplore = this.config.maxLevel !== "county" && this.countyExpanded && !this.localExpanded && !!this.selected;
        this.minimalNav.hidden = !!this.config.controls || (!canBack && !canExplore);
        this.minimalBack.hidden = !canBack;
        this.minimalExplore.hidden = !canExplore;
        this.minimalBack.disabled = this.minimalExplore.disabled = !!this.busy;
        if (canExplore) this.minimalExplore.textContent = `Explore ${this.meta.localLabel}`;
      }
    }
    _tooltip(e, f) {
      if (this.drag) return;
      const key = this.tooltipDetails.has(f.__geoid) ? f.__geoid : f.__id;
      // Pointer movement only repositions the existing tooltip, avoiding
      // repeated DOM rebuilding during ordinary hover movement.
      if (this.activeTipKey !== key || this.tip.hidden) {
        this.tip.replaceChildren();
        const v = this.values.has(f.__geoid) ? this.values.get(f.__geoid) : this.values.get(f.__id);
        const number = v === undefined || v === null ? "" : ` · ${this._formatValue(v)}`;
        html("div", "bloomr-tooltip-heading", this.tip, `${f.__name}${number}`);
        const entries = this.tooltipDetails.get(key) || [];
        if (entries.length) {
          const grid = html("div", "bloomr-tooltip-fields", this.tip);
          entries.forEach(row => {
            if (!row || row.value == null) return;
            html("span", "bloomr-tooltip-field-label", grid, String(row.label));
            html("span", "bloomr-tooltip-field-value", grid, String(row.value));
          });
        }
        this.activeTipKey = key;
      }
      this.tip.hidden = false;
      const bounds = this.stage.getBoundingClientRect();
      const maxX = Math.max(6, bounds.width - this.tip.offsetWidth - 6);
      const maxY = Math.max(6, bounds.height - this.tip.offsetHeight - 6);
      this.tip.style.left = `${clamp(e.clientX - bounds.left + 12, 6, maxX)}px`;
      this.tip.style.top = `${clamp(e.clientY - bounds.top + 12, 6, maxY)}px`;
    }
    _hideTip() { if (this.tip) this.tip.hidden = true; this.activeTipKey = null; }
    select(id, level = "county") {
      const pool = level === "local" ? this.locals : this.counties;
      const f = pool.find(f => f.__id === String(id) || f.__geoid === String(id));
      if (!f) return;
      if (level === "county") { this.selected = f; this.focusCounty = f; }
      else { this.selectedLocal = f; this.focusLocal = f; }
      pool.forEach(x => x.pathEl.classList.toggle("bloomr-selected", x === f));
      this._updateLabels();
      this._syncKeyboardFocus();
      this._refreshToolbar();
      this.status.textContent = `Selected ${f.__name}.`;
      const selection = { id: f.__id, geoid: f.__geoid, name: f.__name, level, parent_id: level === "local" ? this.selected?.__id || null : this.stateId };
      this.el.dispatchEvent(new CustomEvent("bloomr:selection", { bubbles: true, detail: selection }));
      if (global.Shiny && typeof global.Shiny.setInputValue === "function") {
        global.Shiny.setInputValue(this.id + "_selected", selection, { priority: "event" });
      }
    }
    _attachDrag(f, level) {
      if (!this.config.draggable || f.__bloom === false) return;
      f.pathEl.addEventListener("pointerdown", e => {
        if (this.busy || (level === "county" && !this.countyExpanded) || (level === "local" && !this.localExpanded)) return;
        if (e.button !== 0) return;
        const manual = level === "county" ? this.manualCounty : this.manualLocal;
        const prev = manual.get(f.__id) || { x: 0, y: 0 };
        this.drag = { pointerId: e.pointerId, feature: f, level, startX: e.clientX, startY: e.clientY, previous: { ...prev }, moved: false };
        f.pathEl.setPointerCapture(e.pointerId);
        this._hideTip();
      });
      f.pathEl.addEventListener("pointermove", e => {
        const d = this.drag;
        if (!d || d.feature !== f || d.pointerId !== e.pointerId) return;
        const rect = this.svg.getBoundingClientRect();
        const pixelScale = Math.max(1e-6, Math.min(rect.width / WIDTH, rect.height / HEIGHT));
        const px = 1 / (pixelScale * this.camera.k);
        const py = px;
        const dx = (e.clientX - d.startX) * px, dy = (e.clientY - d.startY) * py;
        if (Math.abs(dx) + Math.abs(dy) > 1.5) d.moved = true;
        const manual = level === "county" ? this.manualCounty : this.manualLocal;
        manual.set(f.__id, add(d.previous, { x: dx, y: dy }));
        if (!d.pending) {
          d.pending = true;
          requestAnimationFrame(() => {
            d.pending = false;
            if (!this.destroyed && (this.drag === d || d.finished)) this._renderNode(f, 1);
          });
        }
      });
      const finish = e => {
        const d = this.drag;
        if (!d || d.feature !== f || d.pointerId !== e.pointerId) return;
        d.finished = true;
        this.drag = null;
        if (d.moved) {
          // Suppress the click immediately following an actual drag.
          f.__suppressClickUntil = performance.now() + 300;
          this._updateLabels();
          this.status.textContent = `${f.__name} moved. Origin dot and connector remain anchored.`;
        }
      };
      f.pathEl.addEventListener("pointerup", finish);
      f.pathEl.addEventListener("pointercancel", finish);
    }
    zoom(factor) {
      const next = clamp(this.camera.k * factor, .65, 3.5);
      this.setCamera(next, WIDTH / 2 - next * (WIDTH / 2 - this.camera.x) / this.camera.k,
        HEIGHT / 2 - next * (HEIGHT / 2 - this.camera.y) / this.camera.k);
    }
    setCamera(k, x, y) {
      this.camera = { k, x, y };
      this.viewport?.setAttribute("transform", `translate(${x},${y}) scale(${k})`);
    }
    _resetCamera() {
      const k = clamp(Number(this.config.mapZoom) || 1, .65, 3.5);
      this.setCamera(k, WIDTH * (1 - k) / 2, HEIGHT * (1 - k) / 2);
    }
    _legendValues() {
      // Match the actual color domain of the currently visible geography.
      const pool = this.localExpanded ? this.locals : this.counties;
      return pool.map(f => this.values.get(this.values.has(f.__geoid) ? f.__geoid : f.__id)).filter(finite);
    }
    _formatValue(value) {
      return Number(value).toLocaleString(undefined, { maximumFractionDigits: 3 }) + (this.config.valueSuffix || "");
    }
    _updateLegend() {
      if (!this.legend) return;
      this.legend.replaceChildren();
      if (!this.config.showLegend) return;
      const vals = this._legendValues();
      if (!vals.length) return;
      const label = html("div", "bloomr-legend-title", this.legend, this.config.valueLabel || "Indicator value");
      label.setAttribute("aria-label", "Numeric indicator color gradient");
      html("div", "bloomr-legend-ramp", this.legend);
      const range = html("div", "bloomr-legend-range", this.legend);
      const min = Math.min(...vals), max = Math.max(...vals);
      html("span", "", range, this._formatValue(min));
      html("span", "", range, this._formatValue(max));
    }
    updateTooltipRows(rows) {
      this.tooltipDetails = new Map();
      (rows || []).forEach(row => {
        if (row && row.id != null && Array.isArray(row.fields)) {
          this.tooltipDetails.set(String(row.id), row.fields);
        }
      });
      this._hideTip();
    }
    updateValues(rows) {
      this._hideTip();
      this.values = new Map();
      (rows || []).forEach(row => this.values.set(String(row.id), row.value == null ? null : Number(row.value)));
      this._updateLegend();
      if (this.ready) {
        this.counties.forEach((f, i) => f.pathEl.setAttribute("fill", this._color(f, "county", i)));
        this.locals.forEach((f, i) => f.pathEl.setAttribute("fill", this._color(f, "local", i)));
        this.status.textContent = "Indicator values updated; map positions preserved.";
      }
    }
    reset() {
      if (this.busy) return;
      this.manualCounty.clear(); this.manualLocal.clear();
      if (this.localExpanded) {
        this.localExpanded = false; this.locals = [];
        this.localRefLayer.replaceChildren(); this.localLineLayer.replaceChildren();
        this.localDotLayer.replaceChildren(); this.localShapeLayer.replaceChildren();
        this.localLabelLayer.replaceChildren();
      }
      this.localBaseShift = { x: 0, y: 0 };
      this._positionLocalLayers();
      this.countyExpanded = false; this.selected = null; this.selectedLocal = null;
      this.focusCounty = null; this.focusLocal = null; this.countyCamera = null;
      this.counties.forEach(f => f.pathEl.classList.remove("bloomr-selected"));
      this._restoreCountyAppearance();
      this._render(0); this._resetCamera();
      this._updateLegend();
      this._updateLabels();
      this._syncKeyboardFocus();
      this.status.textContent = this.meta.name + " reset."; this._refreshToolbar();
    }
    exportSvg() {
      // Freeze the actual displayed colors and dotted-line styles into the SVG.
      // External dashboard CSS is not available when an exported SVG is opened.
      const clone = this.svg.cloneNode(true);
      clone.setAttribute("xmlns", NS);
      const backdrop = elem("rect");
      backdrop.setAttribute("width", WIDTH); backdrop.setAttribute("height", HEIGHT);
      backdrop.setAttribute("fill", getComputedStyle(this.stage).backgroundColor);
      clone.insertBefore(backdrop, clone.firstChild);
      const original = this.svg.querySelectorAll("path, circle, text");
      const copied = clone.querySelectorAll("path, circle, text");
      const properties = ["fill", "stroke", "stroke-width", "stroke-dasharray",
        "stroke-linecap", "stroke-linejoin", "opacity", "vector-effect",
        "paint-order", "font-family", "font-size", "font-weight"];
      original.forEach((element, i) => {
        const css = getComputedStyle(element);
        properties.forEach(name => copied[i].style.setProperty(name, css.getPropertyValue(name)));
      });
      const blob = new Blob([new XMLSerializer().serializeToString(clone)], { type: "image/svg+xml;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const a = html("a", "", this.stage);
      a.href = url; a.download = `bloom-${this.stateId}.svg`; a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
    command(command, args) {
      if (command === "select") this.select(args.id, this.localExpanded && this.locals.some(f => f.__id === args.id || f.__geoid === args.id) ? "local" : "county");
      if (command === "expand") args.level === "local" ? this.expandLocal() : this.expandCounties();
      if (command === "data") {
        this.updateValues(args.rows);
        if (Object.prototype.hasOwnProperty.call(args, "tooltipRows")) {
          this.updateTooltipRows(args.tooltipRows);
        }
      }
      if (command === "reset") this.reset();
    }
    resize() { /* The SVG viewBox is responsive; layout stays in fixed coordinates. */ }
    destroy() {
      this.destroyed = true;
      if (this.currentAnimation !== null) cancelAnimationFrame(this.currentAnimation);
      if (this.drag) this.drag = null;
      instances.delete(this.id);
      if (this.onEscape) this.el.removeEventListener("keydown", this.onEscape);
      this.el.replaceChildren();
      this.el.classList.remove("bloomr-widget");
      delete this.el.dataset.bloomTheme;
      delete this.el.dataset.bloomAppearance;
    }
  }
  global.Bloomr = { Map: BloomMap, instances };
  if (global.Shiny?.addCustomMessageHandler) {
    global.Shiny.addCustomMessageHandler("bloomr:command", message => {
      const instance = instances.get(message.id);
      if (instance) instance.command(message.command, message.args || {});
    });
  } else {
    document.addEventListener("shiny:connected", () => {
      if (global.Shiny?.addCustomMessageHandler) global.Shiny.addCustomMessageHandler("bloomr:command", message => {
        const instance = instances.get(message.id);
        if (instance) instance.command(message.command, message.args || {});
      });
    }, { once: true });
  }
})(window);
