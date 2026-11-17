.pragma library

// Home Assistant <-> panel translation. No QML and no I/O in here, so the
// same file is loaded by tests/ha.test.js under node.

var DOMAINS = ["light", "switch", "climate", "scene", "cover", "fan"]

// The REST API has no area endpoint: one template request names the area of
// every entity the panel can show.
var AREA_TEMPLATE =
  "{% for e in states.light %}{{ e.entity_id }}\t{{ area_name(e.entity_id) or '' }}\n{% endfor %}" +
  "{% for e in states.switch %}{{ e.entity_id }}\t{{ area_name(e.entity_id) or '' }}\n{% endfor %}" +
  "{% for e in states.climate %}{{ e.entity_id }}\t{{ area_name(e.entity_id) or '' }}\n{% endfor %}" +
  "{% for e in states.scene %}{{ e.entity_id }}\t{{ area_name(e.entity_id) or '' }}\n{% endfor %}" +
  "{% for e in states.cover %}{{ e.entity_id }}\t{{ area_name(e.entity_id) or '' }}\n{% endfor %}" +
  "{% for e in states.fan %}{{ e.entity_id }}\t{{ area_name(e.entity_id) or '' }}\n{% endfor %}"

var SWATCHES = [
  { name: "red", rgb: [255, 59, 48] },
  { name: "orange", rgb: [255, 149, 0] },
  { name: "yellow", rgb: [255, 214, 10] },
  { name: "green", rgb: [52, 199, 89] },
  { name: "cyan", rgb: [50, 200, 220] },
  { name: "blue", rgb: [0, 122, 255] },
  { name: "purple", rgb: [175, 82, 222] },
  { name: "pink", rgb: [255, 85, 150] }
]

var MODE_ORDER = ["heat_cool", "auto", "cool", "heat", "dry", "fan_only"]

function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)) }

function domainOf(id) {
  var s = String(id || "")
  var dot = s.indexOf(".")
  return dot > 0 ? s.slice(0, dot) : ""
}

function isNumber(v) { return typeof v === "number" && isFinite(v) }

// "homeassistant.local:8123/" -> "http://homeassistant.local:8123"; "" when
// it cannot be an address.
function normalizeUrl(raw) {
  var s = String(raw || "").trim()
  if (s === "") return ""
  if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(s)) s = "http://" + s
  if (!/^https?:\/\//i.test(s)) return ""
  s = s.replace(/[?#].*$/, "").replace(/\/+$/, "").replace(/\/api$/i, "")
  if (!/^https?:\/\/[^\s\/]+/i.test(s)) return ""
  return s
}

function wsUrl(base) {
  var b = normalizeUrl(base)
  if (b === "") return ""
  return b.replace(/^http/i, "ws") + "/api/websocket"
}

function parseAreas(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var tab = line.indexOf("\t")
    if (tab <= 0) continue
    var id = line.slice(0, tab).trim()
    var area = line.slice(tab + 1).trim()
    if (id !== "" && area !== "") out[id] = area
  }
  return out
}

// "light.*_led, switch.boiler" -> matchers. * is the only wildcard.
function parseExclude(text) {
  var out = []
  var parts = String(text || "").split(",")
  for (var i = 0; i < parts.length; i++) {
    var p = parts[i].trim()
    if (p === "") continue
    var rx = p.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*")
    out.push(new RegExp("^" + rx + "$"))
  }
  return out
}

function excluded(id, matchers) {
  for (var i = 0; i < matchers.length; i++) if (matchers[i].test(id)) return true
  return false
}

function hex2(n) {
  var s = Math.round(clamp(n, 0, 255)).toString(16)
  return s.length < 2 ? "0" + s : s
}

function rgbHex(rgb) { return "#" + hex2(rgb[0]) + hex2(rgb[1]) + hex2(rgb[2]) }

// Tanner Helland's black-body approximation; good enough to tint a tile.
function kelvinToRgb(kelvin) {
  var t = clamp(Number(kelvin) || 3000, 1000, 40000) / 100
  var r, g, b
  if (t <= 66) {
    r = 255
    g = 99.4708025861 * Math.log(t) - 161.1195681661
    b = t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307
  } else {
    r = 329.698727446 * Math.pow(t - 60, -0.1332047592)
    g = 288.1221695283 * Math.pow(t - 60, -0.0755148492)
    b = 255
  }
  return [Math.round(clamp(r, 0, 255)), Math.round(clamp(g, 0, 255)), Math.round(clamp(b, 0, 255))]
}

function friendlyName(state) {
  var a = state.attributes || {}
  if (a.friendly_name) return String(a.friendly_name)
  var id = String(state.entity_id || "")
  var name = id.slice(id.indexOf(".") + 1).replace(/_/g, " ")
  return name.charAt(0).toUpperCase() + name.slice(1)
}

function lightView(state, area) {
  var a = state.attributes || {}
  var domain = domainOf(state.entity_id)
  var modes = domain === "light" && Array.isArray(a.supported_color_modes) ? a.supported_color_modes : []
  var on = state.state === "on"
  var available = state.state === "on" || state.state === "off"
  var dim = false, temp = false, color = false
  for (var i = 0; i < modes.length; i++) {
    var m = modes[i]
    if (m !== "onoff") dim = true
    if (m === "color_temp") temp = true
    if (m === "hs" || m === "xy" || m === "rgb" || m === "rgbw" || m === "rgbww") color = true
  }
  var brightness = on && dim && isNumber(a.brightness) ? clamp(a.brightness / 255, 0.01, 1) : (on ? 1 : 0)
  var minK = isNumber(a.min_color_temp_kelvin) ? a.min_color_temp_kelvin : 2000
  var maxK = isNumber(a.max_color_temp_kelvin) ? a.max_color_temp_kelvin : 6500
  var kelvin = isNumber(a.color_temp_kelvin) ? clamp(a.color_temp_kelvin, minK, maxK) : 0
  var tint = "#ffd08a"
  var colored = false
  if (on && a.color_mode !== "color_temp" && Array.isArray(a.rgb_color) && a.rgb_color.length >= 3) {
    tint = rgbHex(a.rgb_color)
    colored = color && a.color_mode !== "brightness" && a.color_mode !== "onoff"
  } else if (on && kelvin > 0) {
    tint = rgbHex(kelvinToRgb(kelvin))
  }
  return {
    kind: "light", domain: domain, id: state.entity_id, name: friendlyName(state), area: area || "",
    on: on, available: available, brightness: brightness,
    dim: dim, temp: temp, color: color, colored: colored,
    kelvin: kelvin, minKelvin: minK, maxKelvin: maxK, tint: tint
  }
}

function climateView(state, area, unit) {
  var a = state.attributes || {}
  var modes = Array.isArray(a.hvac_modes) ? a.hvac_modes : []
  var available = state.state !== "unavailable" && state.state !== "unknown"
  var on = available && state.state !== "off"
  var fahrenheit = String(unit || "").indexOf("F") !== -1
  var step = isNumber(a.target_temp_step) && a.target_temp_step > 0 ? a.target_temp_step : (fahrenheit ? 1 : 0.5)
  var min = isNumber(a.min_temp) ? a.min_temp : (fahrenheit ? 45 : 7)
  var max = isNumber(a.max_temp) ? a.max_temp : (fahrenheit ? 95 : 35)
  var target = isNumber(a.temperature) ? a.temperature : null
  var low = isNumber(a.target_temp_low) ? a.target_temp_low : null
  var high = isNumber(a.target_temp_high) ? a.target_temp_high : null
  var activeModes = []
  for (var i = 0; i < modes.length; i++) if (modes[i] !== "off") activeModes.push(modes[i])
  return {
    kind: "climate", domain: "climate", id: state.entity_id, name: friendlyName(state), area: area || "",
    on: on, available: available, mode: available ? state.state : "",
    modes: activeModes, canTurnOff: modes.indexOf("off") !== -1,
    target: target, low: low, high: high, min: min, max: max, step: step,
    current: isNumber(a.current_temperature) ? a.current_temperature : null,
    fan: a.fan_mode ? String(a.fan_mode) : "", fans: Array.isArray(a.fan_modes) ? a.fan_modes : [],
    action: a.hvac_action ? String(a.hvac_action) : ""
  }
}

// Gates, shutters and fans: things that open/close or switch on/off, drawn as
// a plain tile. A cover counts as "on" unless it is closed.
function deviceView(state, area) {
  var a = state.attributes || {}
  var domain = domainOf(state.entity_id)
  var cover = domain === "cover"
  var available = state.state !== "unavailable" && state.state !== "unknown"
  var moving = cover && (state.state === "opening" || state.state === "closing")
  var on = cover ? (state.state === "open" || moving) : state.state === "on"
  return {
    kind: "device", domain: domain, id: state.entity_id, name: friendlyName(state), area: area || "",
    on: on, available: available, state: state.state, moving: moving,
    percent: !cover && on && isNumber(a.percentage) ? Math.round(a.percentage) : null
  }
}

function byName(x, y) {
  var a = x.name.toLowerCase(), b = y.name.toLowerCase()
  return a < b ? -1 : (a > b ? 1 : (x.id < y.id ? -1 : 1))
}

// statesById: entity_id -> Home Assistant state object.
// Returns the entities to draw (by id) and how they are arranged. `structure`
// carries ids only, so its JSON changes when a device comes or goes, not when
// a lamp is switched: the panel rebuilds its rows on the first and only
// rebinds on the second.
function buildModel(statesById, areas, options) {
  var opts = options || {}
  var matchers = parseExclude(opts.exclude)
  var unit = opts.unit || "°C"
  var entities = {}
  var rooms = {}
  var scenes = []
  var lightsOn = 0, lightCount = 0
  var climates = []

  function room(name) {
    if (!rooms[name]) rooms[name] = { name: name, lights: [], climates: [], devices: [] }
    return rooms[name]
  }

  for (var id in statesById) {
    var state = statesById[id]
    if (!state || excluded(id, matchers)) continue
    var domain = domainOf(id)
    var area = (areas && areas[id]) || ""
    if (domain === "light" || (domain === "switch" && opts.includeSwitches === true)) {
      var light = lightView(state, area)
      entities[id] = light
      room(area).lights.push(light)
      lightCount++
      if (light.on) lightsOn++
    } else if (domain === "climate") {
      var climate = climateView(state, area, unit)
      entities[id] = climate
      room(area).climates.push(climate)
      climates.push(climate)
    } else if (domain === "cover" || domain === "fan") {
      var device = deviceView(state, area)
      entities[id] = device
      room(area).devices.push(device)
    } else if (domain === "scene") {
      if (state.state === "unavailable") continue
      scenes.push({ kind: "scene", id: id, name: friendlyName(state), area: area })
    }
  }

  // What the floor plan uses is known even when the list hides it (a plug
  // while switches are off, an excluded lamp).
  var always = opts.always || []
  for (var p = 0; p < always.length; p++) {
    var pinned = statesById[always[p]]
    if (!pinned || entities[always[p]]) continue
    var kind = domainOf(always[p])
    if (kind === "light" || kind === "switch") entities[always[p]] = lightView(pinned, (areas && areas[always[p]]) || "")
    else if (kind === "cover" || kind === "fan") entities[always[p]] = deviceView(pinned, (areas && areas[always[p]]) || "")
    else if (kind === "climate") entities[always[p]] = climateView(pinned, (areas && areas[always[p]]) || "", unit)
  }

  scenes.sort(byName)
  climates.sort(byName)
  var names = Object.keys(rooms).sort(function(a, b) {
    if (a === "") return 1
    if (b === "") return -1
    return a.toLowerCase() < b.toLowerCase() ? -1 : 1
  })
  var structure = { scenes: [], rooms: [], lightCount: lightCount, climateCount: climates.length }
  for (var s = 0; s < scenes.length; s++) structure.scenes.push({ id: scenes[s].id, name: scenes[s].name })
  for (var n = 0; n < names.length; n++) {
    var r = rooms[names[n]]
    r.lights.sort(byName)
    r.climates.sort(byName)
    r.devices.sort(byName)
    structure.rooms.push({
      name: r.name,
      lights: r.lights.map(function(l) { return l.id }),
      climates: r.climates.map(function(c) { return c.id }),
      devices: r.devices.map(function(d) { return d.id })
    })
  }

  var running = null
  for (var c = 0; c < climates.length; c++) if (climates[c].on) { running = climates[c]; break }

  return {
    entities: entities,
    structure: structure,
    lightsOn: lightsOn,
    lightCount: lightCount,
    climateOn: running !== null,
    climateTarget: running && running.target !== null ? running.target : null,
    summaryText: summaryText(lightsOn, running)
  }
}

function formatTemp(value) {
  if (!isNumber(value)) return "–"
  var rounded = Math.round(value * 10) / 10
  return (rounded % 1 === 0 ? String(rounded) : rounded.toFixed(1)) + "°"
}

// What sits next to the bar icon: "6 · 23°", "6", "23°" or nothing.
function summaryText(lightsOn, running) {
  var parts = []
  if (lightsOn > 0) parts.push(String(lightsOn))
  if (running) parts.push(running.target !== null ? formatTemp(running.target) : formatTemp(running.current))
  return parts.join(" · ")
}

function call(domain, service, data) { return { domain: domain, service: service, data: data } }

// patch: { on, brightness (0..1), kelvin, rgb: [r, g, b] }
function lightCall(view, patch) {
  var domain = view.domain || domainOf(view.id)
  var data = { entity_id: view.id }
  if (patch.on === false) return call(domain, "turn_off", data)
  if (domain !== "light") return call(domain, "turn_on", data)
  if (isNumber(patch.brightness) && view.dim) {
    data.brightness_pct = Math.round(clamp(patch.brightness, 0.01, 1) * 100)
  }
  if (isNumber(patch.kelvin) && view.temp) {
    data.color_temp_kelvin = Math.round(clamp(patch.kelvin, view.minKelvin, view.maxKelvin))
  } else if (patch.rgb && patch.rgb.length >= 3 && view.color) {
    data.rgb_color = [Number(patch.rgb[0]), Number(patch.rgb[1]), Number(patch.rgb[2])]
  }
  return call(domain, "turn_on", data)
}

// One tap on a gate or a fan: open a closed cover, close an open one, stop
// one that is moving; switch a fan the other way.
function deviceCall(view) {
  var data = { entity_id: view.id }
  if (view.domain === "cover") {
    if (view.moving) return call("cover", "stop_cover", data)
    return call("cover", view.state === "closed" ? "open_cover" : "close_cover", data)
  }
  return call(view.domain, view.on ? "turn_off" : "turn_on", data)
}

function snapTarget(view, value) {
  var step = view.step > 0 ? view.step : 0.5
  var snapped = Math.round(value / step) * step
  return Math.round(clamp(snapped, view.min, view.max) * 100) / 100
}

function resumeMode(view, lastMode) {
  if (lastMode && view.modes.indexOf(lastMode) !== -1) return lastMode
  for (var i = 0; i < MODE_ORDER.length; i++) if (view.modes.indexOf(MODE_ORDER[i]) !== -1) return MODE_ORDER[i]
  return view.modes.length > 0 ? view.modes[0] : ""
}

// patch: { on, mode, target, fan }. One Home Assistant call per thing changed.
function climateCalls(view, patch, lastMode) {
  var out = []
  if (patch.on === false) {
    if (view.canTurnOff) out.push(call("climate", "set_hvac_mode", { entity_id: view.id, hvac_mode: "off" }))
    else out.push(call("climate", "turn_off", { entity_id: view.id }))
    return out
  }
  if (patch.mode && view.modes.indexOf(patch.mode) !== -1) {
    out.push(call("climate", "set_hvac_mode", { entity_id: view.id, hvac_mode: patch.mode }))
  } else if (patch.on === true && !view.on) {
    var mode = resumeMode(view, lastMode)
    if (mode !== "") out.push(call("climate", "set_hvac_mode", { entity_id: view.id, hvac_mode: mode }))
    else out.push(call("climate", "turn_on", { entity_id: view.id }))
  }
  if (isNumber(patch.target)) {
    out.push(call("climate", "set_temperature", { entity_id: view.id, temperature: snapTarget(view, patch.target) }))
  }
  if (patch.fan && view.fans.indexOf(patch.fan) !== -1) {
    out.push(call("climate", "set_fan_mode", { entity_id: view.id, fan_mode: patch.fan }))
  }
  return out
}

function copyState(state) {
  var attrs = {}
  var src = state.attributes || {}
  for (var k in src) attrs[k] = src[k]
  return { entity_id: state.entity_id, state: state.state, attributes: attrs }
}

// The state a call is expected to leave behind, shown until Home Assistant
// answers with the real one. null when the call changes nothing we draw.
function optimisticState(state, c) {
  if (!state || !c) return null
  var next = copyState(state)
  var a = next.attributes
  var d = c.data || {}
  if (c.domain === "light" || c.domain === "switch" || c.domain === "fan") {
    if (state.state !== "on" && state.state !== "off") return null
    if (c.service === "turn_off") { next.state = "off"; return next }
    if (c.service === "toggle") { next.state = state.state === "on" ? "off" : "on"; return next }
    if (c.service !== "turn_on") return null
    next.state = "on"
    if (isNumber(d.brightness_pct)) a.brightness = Math.round(d.brightness_pct * 255 / 100)
    if (isNumber(d.color_temp_kelvin)) { a.color_temp_kelvin = d.color_temp_kelvin; a.color_mode = "color_temp" }
    if (Array.isArray(d.rgb_color)) {
      a.rgb_color = d.rgb_color
      if (a.color_mode === "color_temp" || !a.color_mode) a.color_mode = "rgb"
    }
    return next
  }
  if (c.domain === "climate") {
    if (c.service === "set_hvac_mode") { next.state = d.hvac_mode; return next }
    if (c.service === "turn_off") { next.state = "off"; return next }
    if (c.service === "set_temperature") { a.temperature = d.temperature; return next }
    if (c.service === "set_fan_mode") { a.fan_mode = d.fan_mode; return next }
  }
  return null
}

// Keep only what the panel draws out of GET /api/states.
function indexStates(list) {
  var out = {}
  if (!Array.isArray(list)) return out
  for (var i = 0; i < list.length; i++) {
    var s = list[i]
    if (!s || !s.entity_id) continue
    if (DOMAINS.indexOf(domainOf(s.entity_id)) === -1) continue
    out[s.entity_id] = s
  }
  return out
}

function relevant(id) { return DOMAINS.indexOf(domainOf(id)) !== -1 }

// The lamps (lights, plugs, gates and fans) or the air conditioners a plan can link to.
function candidates(statesById, areas, kind) {
  var out = []
  for (var id in statesById) {
    var domain = domainOf(id)
    var wanted = kind === "light"
      ? (domain === "light" || domain === "switch" || domain === "cover" || domain === "fan")
      : domain === "climate"
    if (!wanted) continue
    out.push({ id: id, name: friendlyName(statesById[id]), area: (areas && areas[id]) || "" })
  }
  out.sort(byName)
  return out
}
