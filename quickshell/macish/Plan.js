.pragma library

// The floor plan: House Control's plan.json (docs/floor-plan.md there), read,
// turned into things to draw, and edited. No QML and no I/O, so the same file
// is loaded by tests/plan.test.js under node.
//
// Metres, seen from above: x grows east (right), z grows south (down), y is
// height. A plan document is kept as it was read: fields this plugin does not
// use (scenes, levels above the first, tuya links) survive an edit.

var GRID = 0.05
var WALL = 0.1
var MIN_ROOM = 0.6

var FLOORS = { oak: "#b08a5b", walnut: "#7a5a43", tile: "#c9ccd1", stone: "#8f9399" }
var FLOOR_NAMES = ["oak", "walnut", "tile", "stone"]
var WALL_NAMES = ["north", "east", "south", "west"]
var LIGHT_TYPES = ["ceiling", "pendant", "spots", "floor", "table", "strip"]
var LIGHT_HEIGHT = { ceiling: 2.3, pendant: 1.9, spots: 2.3, floor: 1.5, table: 0.75, strip: 0.3 }
var OPENING_TYPES = ["door", "window", "open"]

// type: [width, depth, height, colour], the footprints House Control uses.
// Width runs along x and the front faces south until the piece is rotated.
var FURNITURE = {
  sofa: [2.2, 0.95, 0.75, "#8b93a7"], armchair: [0.92, 0.88, 0.75, "#c28a5a"],
  coffeeTable: [1.1, 0.58, 0.4, "#8a6a4a"], rug: [2.0, 1.4, 0.02, "#3b4a66"],
  tv: [1.7, 0.4, 0.5, "#3a3d42"], sideboard: [1.6, 0.42, 0.76, "#9a7650"],
  dresser: [1.3, 0.45, 0.85, "#d8d5ce"], desk: [1.4, 0.65, 0.75, "#a98862"],
  vanity: [1.0, 0.5, 0.85, "#d5d7da"], diningSet: [1.8, 1.9, 0.76, "#a98862"],
  island: [2.0, 1.1, 0.93, "#4a5361"], kitchen: [3.0, 0.62, 0.9, "#cfccc5"],
  bed: [1.6, 2.14, 0.5, "#7f8fb5"], wardrobe: [1.6, 0.6, 2.1, "#d8d5ce"],
  bookshelf: [1.0, 0.32, 1.8, "#9a7650"], plant: [0.45, 0.45, 1.2, "#4f8a5b"],
  stairs: [1.0, 2.8, 1.3, "#a9a39a"], fridge: [0.7, 0.68, 1.92, "#cfd2d6"],
  nightstand: [0.46, 0.4, 0.5, "#9a7650"], bathtub: [1.7, 0.78, 0.56, "#e6e8ea"],
  toilet: [0.4, 0.66, 0.42, "#e6e8ea"]
}
var FURNITURE_TYPES = ["sofa", "armchair", "coffeeTable", "rug", "tv", "sideboard", "desk", "diningSet",
  "kitchen", "island", "fridge", "bed", "nightstand", "wardrobe", "dresser", "bookshelf", "plant",
  "vanity", "bathtub", "toilet", "stairs"]

function isNumber(v) { return typeof v === "number" && isFinite(v) }
function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)) }
function snap(v) { return Math.round(v / GRID) * GRID === 0 ? 0 : Math.round(Math.round(v / GRID) * GRID * 1000) / 1000 }
function clone(value) { return JSON.parse(JSON.stringify(value)) }
function list(plan, key) { return plan && Array.isArray(plan[key]) ? plan[key] : [] }
function isPoint(p) { return Array.isArray(p) && p.length >= 2 && isNumber(p[0]) && isNumber(p[1]) }
function isRect(r) {
  return Array.isArray(r) && r.length >= 4 && isNumber(r[0]) && isNumber(r[1])
    && isNumber(r[2]) && isNumber(r[3]) && r[2] > 0 && r[3] > 0
}

function empty(name) {
  return { version: 1, name: name || "Home", wallHeight: 2.6, interiorWallHeight: 1.25,
    camera: { azimuth: 34, elevation: 47 }, rooms: [], openings: [], furniture: [], lights: [], acs: [] }
}

// text -> { plan, error }. plan is null when there is no usable document.
function parse(text) {
  var source = String(text || "").trim()
  if (source === "") return { plan: null, error: "" }
  var doc
  try { doc = JSON.parse(source) } catch (e) { return { plan: null, error: "plan.json: " + e.message } }
  if (!doc || typeof doc !== "object" || Array.isArray(doc)) return { plan: null, error: "plan.json: not an object" }
  var keys = ["rooms", "openings", "furniture", "lights", "acs"]
  for (var i = 0; i < keys.length; i++) if (!Array.isArray(doc[keys[i]])) doc[keys[i]] = []
  return { plan: doc, error: "" }
}

function serialize(plan) { return JSON.stringify(plan, null, 2) + "\n" }

// This plugin draws one floor: the first of `levels`.
function groundLevel(plan) {
  var levels = list(plan, "levels")
  return levels.length > 0 && levels[0] ? levels[0].id : undefined
}
function onGround(plan, item) {
  var ground = groundLevel(plan)
  return ground === undefined || item.level === undefined || item.level === ground
}

function wallHeight(plan) { return plan && isNumber(plan.wallHeight) ? plan.wallHeight : 2.6 }
function interiorHeight(plan) { return plan && isNumber(plan.interiorWallHeight) ? plan.interiorWallHeight : 1.25 }
function cameraOf(plan) {
  var c = plan && plan.camera ? plan.camera : {}
  return { azimuth: isNumber(c.azimuth) ? c.azimuth : 34, elevation: isNumber(c.elevation) ? c.elevation : 47 }
}

function rooms(plan) {
  return list(plan, "rooms").filter(function(r) { return r && isRect(r.rect) && onGround(plan, r) })
}

function roomById(plan, id) {
  var all = list(plan, "rooms")
  for (var i = 0; i < all.length; i++) if (all[i] && all[i].id === id) return all[i]
  return null
}

function inRect(rect, x, z, margin) {
  var m = margin || 0
  return x >= rect[0] - m && x <= rect[0] + rect[2] + m && z >= rect[1] - m && z <= rect[1] + rect[3] + m
}

function roomAt(plan, x, z) {
  var all = rooms(plan)
  for (var i = 0; i < all.length; i++) if (inRect(all[i].rect, x, z, 1e-6)) return all[i]
  return null
}

function nearestRoom(plan, x, z) {
  var all = rooms(plan), best = null, bestDistance = Infinity
  for (var i = 0; i < all.length; i++) {
    var r = all[i].rect
    var dx = Math.max(r[0] - x, 0, x - r[0] - r[2]), dz = Math.max(r[1] - z, 0, z - r[1] - r[3])
    var distance = dx * dx + dz * dz
    if (distance < bestDistance) { bestDistance = distance; best = all[i] }
  }
  return best
}

// What is wrong with a plan, in words. Empty when it adds up.
function validate(plan) {
  var problems = []
  if (!plan) return problems
  var ids = {}, deviceIds = {}
  var all = list(plan, "rooms")
  for (var i = 0; i < all.length; i++) {
    var room = all[i] || {}
    if (!room.id) problems.push("rooms[" + i + "]: no id")
    else if (ids[room.id]) problems.push("rooms[" + i + "]: duplicate id " + room.id)
    ids[room.id] = true
    if (!isRect(room.rect)) problems.push("room " + (room.id || i) + ": rect must be [x, z, width, depth]")
  }
  function devices(key) {
    var items = list(plan, key)
    for (var j = 0; j < items.length; j++) {
      var item = items[j] || {}
      var label = key + "[" + j + "]"
      if (!item.id) problems.push(label + ": no id")
      else if (deviceIds[item.id]) problems.push(label + ": duplicate id " + item.id)
      deviceIds[item.id] = true
      if (!ids[item.room]) problems.push((item.id || label) + ": unknown room " + item.room)
      if (!isPoint(item.pos)) problems.push((item.id || label) + ": pos must be [x, z]")
      if (key === "acs" && item.wall !== undefined && WALL_NAMES.indexOf(item.wall) === -1) {
        problems.push((item.id || label) + ": wall must be north, east, south or west")
      }
    }
  }
  devices("lights")
  devices("acs")
  var openings = list(plan, "openings")
  for (var k = 0; k < openings.length; k++) {
    var o = openings[k] || {}
    if (!isPoint(o.from) || !isPoint(o.to)) problems.push("openings[" + k + "]: from and to must be [x, z]")
    else if (Math.abs(o.from[0] - o.to[0]) > 1e-6 && Math.abs(o.from[1] - o.to[1]) > 1e-6) {
      problems.push("openings[" + k + "]: must be horizontal or vertical")
    }
  }
  var furniture = list(plan, "furniture")
  for (var f = 0; f < furniture.length; f++) {
    if (!furniture[f] || !isPoint(furniture[f].pos)) problems.push("furniture[" + f + "]: pos must be [x, z]")
  }
  return problems
}

function bounds(plan, roomId) {
  var all = rooms(plan)
  var x0 = Infinity, z0 = Infinity, x1 = -Infinity, z1 = -Infinity
  for (var i = 0; i < all.length; i++) {
    if (roomId && all[i].id !== roomId) continue
    var r = all[i].rect
    x0 = Math.min(x0, r[0]); z0 = Math.min(z0, r[1])
    x1 = Math.max(x1, r[0] + r[2]); z1 = Math.max(z1, r[1] + r[3])
  }
  if (x0 === Infinity) return { x0: 0, z0: 0, x1: 6, z1: 4, empty: true }
  return { x0: x0, z0: z0, x1: x1, z1: z1, empty: false }
}

// --- walls ----------------------------------------------------------------

// Every stretch of wall, cut at room corners and openings and into pieces no
// longer than maxLength (short pieces sort correctly against furniture).
//   { o: "h"|"v", c, a, b, inner, n, y0, y1, glass }
// "h" runs along x at z = c, "v" along z at x = c, from a to b. n is the side
// the outside is on (-1 north/west, +1 south/east, 0 for a wall between two
// rooms). y1 null means up to the wall's full height.
function wallPieces(plan, maxLength) {
  var limit = maxLength > 0 ? maxLength : 0.75
  var lines = {}
  function line(o, c) {
    var key = o + ":" + c.toFixed(2)
    if (!lines[key]) lines[key] = { o: o, c: c, edges: [], openings: [] }
    return lines[key]
  }
  var all = rooms(plan)
  for (var i = 0; i < all.length; i++) {
    var r = all[i].rect
    line("h", r[1]).edges.push({ a: r[0], b: r[0] + r[2], n: -1 })
    line("h", r[1] + r[3]).edges.push({ a: r[0], b: r[0] + r[2], n: 1 })
    line("v", r[0]).edges.push({ a: r[1], b: r[1] + r[3], n: -1 })
    line("v", r[0] + r[2]).edges.push({ a: r[1], b: r[1] + r[3], n: 1 })
  }
  var openings = list(plan, "openings")
  for (var k = 0; k < openings.length; k++) {
    var o = openings[k]
    if (!o || !isPoint(o.from) || !isPoint(o.to) || !onGround(plan, o)) continue
    var horizontal = Math.abs(o.from[1] - o.to[1]) < 1e-6
    var vertical = Math.abs(o.from[0] - o.to[0]) < 1e-6
    if (!horizontal && !vertical) continue
    var key = horizontal ? "h:" + o.from[1].toFixed(2) : "v:" + o.from[0].toFixed(2)
    if (!lines[key]) continue
    var a = horizontal ? o.from[0] : o.from[1], b = horizontal ? o.to[0] : o.to[1]
    lines[key].openings.push({
      a: Math.min(a, b), b: Math.max(a, b), type: o.type || "door",
      sill: isNumber(o.sill) ? o.sill : 0.85, head: isNumber(o.head) ? o.head : 2.1
    })
  }

  var out = []
  for (var name in lines) {
    var l = lines[name]
    var cuts = []
    for (var e = 0; e < l.edges.length; e++) cuts.push(l.edges[e].a, l.edges[e].b)
    for (var q = 0; q < l.openings.length; q++) cuts.push(l.openings[q].a, l.openings[q].b)
    cuts.sort(function(x, y) { return x - y })
    for (var c = 0; c + 1 < cuts.length; c++) {
      var t0 = cuts[c], t1 = cuts[c + 1]
      if (t1 - t0 < 1e-6) continue
      var mid = (t0 + t1) / 2
      var north = false, south = false
      for (var e2 = 0; e2 < l.edges.length; e2++) {
        var edge = l.edges[e2]
        if (mid < edge.a || mid > edge.b) continue
        if (edge.n < 0) north = true
        else south = true
      }
      if (!north && !south) continue
      var opening = null
      for (var q2 = 0; q2 < l.openings.length; q2++) {
        if (mid > l.openings[q2].a && mid < l.openings[q2].b) { opening = l.openings[q2]; break }
      }
      if (opening && opening.type === "open") continue
      var inner = north && south
      var count = Math.max(1, Math.ceil((t1 - t0) / limit))
      for (var s = 0; s < count; s++) {
        var base = {
          o: l.o, c: l.c, a: t0 + (t1 - t0) * s / count, b: t0 + (t1 - t0) * (s + 1) / count,
          inner: inner, n: inner ? 0 : (south ? 1 : -1)
        }
        function piece(y0, y1, glass) {
          out.push({ o: base.o, c: base.c, a: base.a, b: base.b, inner: base.inner, n: base.n,
            y0: y0, y1: y1, glass: glass === true })
        }
        if (!opening) piece(0, null)
        else if (opening.type === "window") {
          piece(0, opening.sill)
          piece(opening.sill, opening.head, true)
          piece(opening.head, null)
        } else {
          // A door: the wall goes on above it.
          piece(2.05, null)
        }
      }
    }
  }
  return out
}

function footprint(item) {
  var def = FURNITURE[item.type] || [0.8, 0.8, 0.6, "#8a8f98"]
  var width = isNumber(item.width) ? item.width : def[0]
  var depth = isNumber(item.depth) ? item.depth : def[1]
  if (item.type === "rug" && Array.isArray(item.size) && item.size.length >= 2) {
    width = item.size[0]
    depth = item.size[1]
  }
  return {
    width: width, depth: depth,
    height: isNumber(item.height) ? item.height : def[2],
    color: typeof item.color === "string" && item.color !== "" ? item.color : def[3]
  }
}

function lightHeight(light) {
  if (isNumber(light.y)) return light.y
  var h = LIGHT_HEIGHT[light.type]
  return h === undefined ? 2.3 : h
}

function linkId(item) {
  return item && item.link && item.link.service === "homeassistant" && item.link.id ? String(item.link.id) : ""
}

// The Home Assistant entities the plan uses.
function linkedIds(plan) {
  var out = []
  var keys = ["lights", "acs"]
  for (var k = 0; k < keys.length; k++) {
    var items = list(plan, keys[k])
    for (var i = 0; i < items.length; i++) {
      var id = linkId(items[i])
      if (id !== "" && out.indexOf(id) === -1) out.push(id)
    }
  }
  return out
}

// Everything to draw, away from any camera. Lamps and ACs keep their index
// in the plan, so a click can be traced back.
function scene(plan) {
  var out = { floors: [], walls: [], boxes: [], lamps: [], acs: [],
    wallHeight: wallHeight(plan), interiorHeight: interiorHeight(plan), bounds: bounds(plan) }
  if (!plan) return out
  var all = rooms(plan)
  for (var i = 0; i < all.length; i++) {
    out.floors.push({ id: all[i].id, name: all[i].name || "", rect: all[i].rect,
      color: FLOORS[all[i].floor] || FLOORS.oak })
  }
  out.walls = wallPieces(plan, 0.75)
  var furniture = list(plan, "furniture")
  for (var f = 0; f < furniture.length; f++) {
    var item = furniture[f]
    if (!item || !isPoint(item.pos) || !onGround(plan, item)) continue
    var shape = footprint(item)
    out.boxes.push({ x: item.pos[0], z: item.pos[1], hx: shape.width / 2, hz: shape.depth / 2,
      rot: isNumber(item.rot) ? item.rot : 0, y0: 0, y1: shape.height, color: shape.color, flat: item.type === "rug" })
  }
  var lights = list(plan, "lights")
  for (var l = 0; l < lights.length; l++) {
    var light = lights[l]
    if (!light || !isPoint(light.pos)) continue
    var room = roomById(plan, light.room)
    if (!room || !isRect(room.rect) || !onGround(plan, room)) continue
    out.lamps.push({ index: l, id: light.id, name: light.name || "", room: light.room, rect: room.rect,
      type: light.type || "ceiling", x: light.pos[0], z: light.pos[1], y: lightHeight(light),
      rot: isNumber(light.rot) ? light.rot : 0, length: isNumber(light.length) ? light.length : 1.2,
      entity: linkId(light) })
  }
  var acs = list(plan, "acs")
  for (var a = 0; a < acs.length; a++) {
    var ac = acs[a]
    if (!ac || !isPoint(ac.pos)) continue
    var acRoom = roomById(plan, ac.room)
    if (!acRoom || !isRect(acRoom.rect) || !onGround(plan, acRoom)) continue
    var wallName = WALL_NAMES.indexOf(ac.wall) !== -1 ? ac.wall : "north"
    var alongX = wallName === "north" || wallName === "south"
    var inner = false
    for (var w = 0; w < out.walls.length; w++) {
      var piece = out.walls[w]
      if (piece.o !== (alongX ? "h" : "v") || Math.abs(piece.c - (alongX ? ac.pos[1] : ac.pos[0])) > 0.011) continue
      var t = alongX ? ac.pos[0] : ac.pos[1]
      if (t >= piece.a && t <= piece.b) { inner = piece.inner; break }
    }
    out.acs.push({ index: a, id: ac.id, name: ac.name || "", room: ac.room, rect: acRoom.rect,
      wall: wallName, inner: inner, x: ac.pos[0], z: ac.pos[1],
      y: isNumber(ac.y) ? ac.y : 2.2, entity: linkId(ac) })
  }
  return out
}

// --- camera -----------------------------------------------------------------

// An orthographic camera circling the home: azimuth turns it, elevation tilts
// it (90 looks straight down). project() gives screen x, screen y and a depth
// that grows towards the viewer.
function camera(azimuth, elevation, scale, originX, originY, centerX, centerZ) {
  var a = azimuth * Math.PI / 180, e = clamp(elevation, 5, 90) * Math.PI / 180
  var cosA = Math.cos(a), sinA = Math.sin(a), cosE = Math.cos(e), sinE = Math.sin(e)
  return {
    scale: scale, cosA: cosA, sinA: sinA, cosE: cosE, sinE: sinE,
    originX: originX, originY: originY, centerX: centerX, centerZ: centerZ,
    // The ground direction that points at the viewer.
    towardX: sinA, towardZ: cosA,
    project: function(x, y, z) {
      var dx = x - centerX, dz = z - centerZ
      var u = dx * cosA - dz * sinA, w = dx * sinA + dz * cosA
      return [originX + scale * u, originY + scale * (w * sinE - y * cosE), w * cosE + y * sinE]
    },
    // The point of the floor under a screen position.
    floorAt: function(sx, sy) {
      var u = (sx - originX) / scale, w = (sy - originY) / (scale * sinE)
      return [centerX + u * cosA + w * sinA, centerZ - u * sinA + w * cosA]
    },
    // Canvas transform that lays world (x, z) onto the floor: [a, b, c, d, e, f].
    floorMatrix: function() {
      var m11 = scale * cosA, m21 = -scale * sinA, m12 = scale * sinA * sinE, m22 = scale * cosA * sinE
      return [m11, m12, m21, m22, originX - m11 * centerX - m21 * centerZ, originY - m12 * centerX - m22 * centerZ]
    }
  }
}

// A camera that shows box b (x0, z0, x1, z1, up to `height`) whole in a
// width x height view, with `padding` around it.
function fit(b, height, azimuth, elevation, viewWidth, viewHeight, padding) {
  var cx = (b.x0 + b.x1) / 2, cz = (b.z0 + b.z1) / 2
  var probe = camera(azimuth, elevation, 1, 0, 0, cx, cz)
  var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
  var xs = [b.x0, b.x1], zs = [b.z0, b.z1], ys = [0, height]
  for (var i = 0; i < 2; i++) for (var j = 0; j < 2; j++) for (var k = 0; k < 2; k++) {
    var p = probe.project(xs[i], ys[k], zs[j])
    minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0])
    minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1])
  }
  var pad = padding || 0
  var scale = Math.min((viewWidth - 2 * pad) / Math.max(0.01, maxX - minX),
                       (viewHeight - 2 * pad) / Math.max(0.01, maxY - minY))
  scale = Math.max(1, scale)
  return camera(azimuth, elevation, scale,
    viewWidth / 2 - scale * (minX + maxX) / 2, viewHeight / 2 - scale * (minY + maxY) / 2, cx, cz)
}

// --- editing ----------------------------------------------------------------
// Every function returns a new plan and leaves the one it was given alone, so
// undo is a stack of plans. A ref names one thing: { kind, index } with kind
// "room", "light", "ac", "furniture" or "opening" and the index in its array.

var KEYS = { room: "rooms", light: "lights", ac: "acs", furniture: "furniture", opening: "openings" }

function itemAt(plan, ref) {
  if (!plan || !ref || !KEYS[ref.kind]) return null
  var items = list(plan, KEYS[ref.kind])
  return ref.index >= 0 && ref.index < items.length ? items[ref.index] : null
}

function sameRef(a, b) { return !!a && !!b && a.kind === b.kind && a.index === b.index }

function freshId(plan, prefix) {
  var taken = {}
  var keys = ["rooms", "lights", "acs"]
  for (var k = 0; k < keys.length; k++) {
    var items = list(plan, keys[k])
    for (var i = 0; i < items.length; i++) if (items[i] && items[i].id) taken[items[i].id] = true
  }
  for (var n = 1; ; n++) if (!taken[prefix + n]) return prefix + n
}

function freshName(plan, key, word) {
  var items = list(plan, key), taken = {}
  for (var i = 0; i < items.length; i++) if (items[i] && items[i].name) taken[items[i].name] = true
  for (var n = 1; ; n++) if (!taken[word + " " + n]) return word + " " + n
}

function withLevel(plan, item) {
  var ground = groundLevel(plan)
  if (ground !== undefined) item.level = ground
  return item
}

function addRoom(plan, x0, z0, x1, z1, word) {
  var next = clone(plan)
  var x = snap(Math.min(x0, x1)), z = snap(Math.min(z0, z1))
  var width = Math.max(MIN_ROOM, snap(Math.abs(x1 - x0))), depth = Math.max(MIN_ROOM, snap(Math.abs(z1 - z0)))
  next.rooms.push(withLevel(next, {
    id: freshId(next, "room"), name: freshName(next, "rooms", word || "Room"), rect: [x, z, width, depth], floor: "oak"
  }))
  return { plan: next, ref: { kind: "room", index: next.rooms.length - 1 } }
}

// Where an AC hangs when it is put at (x, z) in a room: its nearest wall.
function seatAc(rect, x, z) {
  var distances = [
    { wall: "north", d: Math.abs(z - rect[1]) }, { wall: "south", d: Math.abs(z - rect[1] - rect[3]) },
    { wall: "west", d: Math.abs(x - rect[0]) }, { wall: "east", d: Math.abs(x - rect[0] - rect[2]) }
  ]
  distances.sort(function(p, q) { return p.d - q.d })
  return seatOnWall(rect, distances[0].wall, x, z)
}

function seatOnWall(rect, wall, x, z) {
  var inset = Math.min(0.5, rect[2] / 2, rect[3] / 2)
  var px = snap(clamp(x, rect[0] + inset, rect[0] + rect[2] - inset))
  var pz = snap(clamp(z, rect[1] + inset, rect[1] + rect[3] - inset))
  if (wall === "north") return { wall: wall, pos: [px, rect[1]] }
  if (wall === "south") return { wall: wall, pos: [px, snap(rect[1] + rect[3])] }
  if (wall === "west") return { wall: wall, pos: [rect[0], pz] }
  return { wall: "east", pos: [snap(rect[0] + rect[2]), pz] }
}

// Keep a room's lamps inside it and its ACs on its walls.
function settle(plan, room) {
  var rect = room.rect, inset = Math.min(0.1, rect[2] / 2, rect[3] / 2)
  var lights = list(plan, "lights")
  for (var i = 0; i < lights.length; i++) {
    var light = lights[i]
    if (!light || light.room !== room.id || !isPoint(light.pos)) continue
    light.pos = [snap(clamp(light.pos[0], rect[0] + inset, rect[0] + rect[2] - inset)),
                 snap(clamp(light.pos[1], rect[1] + inset, rect[1] + rect[3] - inset))]
  }
  var acs = list(plan, "acs")
  for (var j = 0; j < acs.length; j++) {
    var ac = acs[j]
    if (!ac || ac.room !== room.id || !isPoint(ac.pos)) continue
    var seat = seatOnWall(rect, WALL_NAMES.indexOf(ac.wall) !== -1 ? ac.wall : "north", ac.pos[0], ac.pos[1])
    ac.wall = seat.wall
    ac.pos = seat.pos
  }
}

function onPerimeter(rect, p) {
  var onX = Math.abs(p[0] - rect[0]) < 0.011 || Math.abs(p[0] - rect[0] - rect[2]) < 0.011
  var onZ = Math.abs(p[1] - rect[1]) < 0.011 || Math.abs(p[1] - rect[1] - rect[3]) < 0.011
  return (onX && p[1] >= rect[1] - 0.011 && p[1] <= rect[1] + rect[3] + 0.011)
      || (onZ && p[0] >= rect[0] - 0.011 && p[0] <= rect[0] + rect[2] + 0.011)
}

// Move a room, with what is in it and the openings in its walls.
function moveRoom(plan, index, x, z) {
  var next = clone(plan)
  var room = next.rooms[index]
  if (!room || !isRect(room.rect)) return next
  var old = room.rect.slice()
  var dx = snap(x) - old[0], dz = snap(z) - old[1]
  if (dx === 0 && dz === 0) return next
  function shift(p) { return [snap(p[0] + dx), snap(p[1] + dz)] }
  room.rect = [snap(x), snap(z), old[2], old[3]]
  var keys = ["lights", "acs"]
  for (var k = 0; k < keys.length; k++) {
    var items = list(next, keys[k])
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i].room === room.id && isPoint(items[i].pos)) items[i].pos = shift(items[i].pos)
    }
  }
  var furniture = list(next, "furniture")
  for (var f = 0; f < furniture.length; f++) {
    var piece = furniture[f]
    if (piece && isPoint(piece.pos) && onGround(next, piece) && inRect(old, piece.pos[0], piece.pos[1])) piece.pos = shift(piece.pos)
  }
  var openings = list(next, "openings")
  for (var o = 0; o < openings.length; o++) {
    var opening = openings[o]
    if (!opening || !isPoint(opening.from) || !isPoint(opening.to) || !onGround(next, opening)) continue
    if (onPerimeter(old, opening.from) && onPerimeter(old, opening.to)) {
      opening.from = shift(opening.from)
      opening.to = shift(opening.to)
    }
  }
  return next
}

function resizeRoom(plan, index, x0, z0, x1, z1) {
  var next = clone(plan)
  var room = next.rooms[index]
  if (!room) return next
  var x = snap(Math.min(x0, x1)), z = snap(Math.min(z0, z1))
  room.rect = [x, z, Math.max(MIN_ROOM, snap(Math.abs(x1 - x0))), Math.max(MIN_ROOM, snap(Math.abs(z1 - z0)))]
  settle(next, room)
  return next
}

function addLight(plan, x, z, type, word) {
  var room = roomAt(plan, x, z)
  if (!room) return null
  var next = clone(plan)
  next.lights.push({
    id: freshId(next, "light"), name: freshName(next, "lights", word || "Lamp"), room: room.id,
    type: LIGHT_TYPES.indexOf(type) !== -1 ? type : "ceiling", pos: [snap(x), snap(z)]
  })
  settle(next, roomById(next, room.id))
  return { plan: next, ref: { kind: "light", index: next.lights.length - 1 } }
}

function addAc(plan, x, z, word) {
  var room = roomAt(plan, x, z) || nearestRoom(plan, x, z)
  if (!room) return null
  var next = clone(plan)
  var seat = seatAc(room.rect, x, z)
  next.acs.push({
    id: freshId(next, "ac"), name: freshName(next, "acs", word || "AC"), room: room.id, wall: seat.wall, pos: seat.pos
  })
  return { plan: next, ref: { kind: "ac", index: next.acs.length - 1 } }
}

function addFurniture(plan, type, x, z) {
  if (!FURNITURE[type]) return null
  var next = clone(plan)
  next.furniture.push(withLevel(next, { type: type, pos: [snap(x), snap(z)] }))
  return { plan: next, ref: { kind: "furniture", index: next.furniture.length - 1 } }
}

// The wall nearest to a point: { o, c, a, b } as in wallPieces, or null when
// none is within `reach`.
function nearestWall(plan, x, z, reach) {
  var all = rooms(plan), best = null, bestDistance = reach === undefined ? 0.6 : reach
  for (var i = 0; i < all.length; i++) {
    var r = all[i].rect
    var edges = [
      { o: "h", c: r[1], a: r[0], b: r[0] + r[2] }, { o: "h", c: r[1] + r[3], a: r[0], b: r[0] + r[2] },
      { o: "v", c: r[0], a: r[1], b: r[1] + r[3] }, { o: "v", c: r[0] + r[2], a: r[1], b: r[1] + r[3] }
    ]
    for (var e = 0; e < edges.length; e++) {
      var edge = edges[e]
      var along = edge.o === "h" ? x : z, across = edge.o === "h" ? z : x
      var distance = Math.max(Math.abs(across - edge.c), edge.a - along, along - edge.b)
      if (distance < bestDistance) { bestDistance = distance; best = edge }
    }
  }
  return best
}

// An opening on the wall nearest to (x0, z0), from there to (x1, z1) along
// it. A click without a drag gives the usual width.
function addOpening(plan, type, x0, z0, x1, z1) {
  var wall = nearestWall(plan, x0, z0)
  if (!wall) return null
  var kind = OPENING_TYPES.indexOf(type) !== -1 ? type : "door"
  var start = wall.o === "h" ? x0 : z0, end = wall.o === "h" ? x1 : z1
  if (Math.abs(end - start) < 0.3) {
    var usual = kind === "window" ? 1.2 : 0.9
    start -= usual / 2
    end = start + usual
  }
  var a = snap(clamp(Math.min(start, end), wall.a, wall.b)), b = snap(clamp(Math.max(start, end), wall.a, wall.b))
  if (b - a < 0.3) return null
  var next = clone(plan)
  var c = snap(wall.c)
  next.openings.push(withLevel(next, {
    type: kind, from: wall.o === "h" ? [a, c] : [c, a], to: wall.o === "h" ? [b, c] : [c, b]
  }))
  return { plan: next, ref: { kind: "opening", index: next.openings.length - 1 } }
}

// Put a thing's centre (a room's corner) at (x, z).
function moveItem(plan, ref, x, z) {
  if (ref.kind === "room") return moveRoom(plan, ref.index, x, z)
  var next = clone(plan)
  var item = itemAt(next, ref)
  if (!item) return next
  if (ref.kind === "light") {
    var room = roomAt(next, x, z) || roomById(next, item.room)
    if (!room) return next
    item.room = room.id
    item.pos = [snap(x), snap(z)]
    settle(next, room)
  } else if (ref.kind === "ac") {
    var acRoom = roomAt(next, x, z) || roomById(next, item.room)
    if (!acRoom) return next
    var seat = seatAc(acRoom.rect, x, z)
    item.room = acRoom.id
    item.wall = seat.wall
    item.pos = seat.pos
  } else if (ref.kind === "furniture") {
    item.pos = [snap(x), snap(z)]
  } else if (ref.kind === "opening" && isPoint(item.from) && isPoint(item.to)) {
    // Slides along its wall, or jumps to another wall the pointer is on.
    var horizontal = Math.abs(item.from[1] - item.to[1]) < 1e-6
    var length = horizontal ? Math.abs(item.to[0] - item.from[0]) : Math.abs(item.to[1] - item.from[1])
    var wall = nearestWall(next, x, z, 0.4) || nearestWall(next, (item.from[0] + item.to[0]) / 2, (item.from[1] + item.to[1]) / 2, 0.4)
    if (!wall) return next
    var size = Math.min(length, wall.b - wall.a)
    var a = snap(clamp((wall.o === "h" ? x : z) - size / 2, wall.a, wall.b - size))
    var c = snap(wall.c)
    item.from = wall.o === "h" ? [a, c] : [c, a]
    item.to = wall.o === "h" ? [snap(a + size), c] : [c, snap(a + size)]
  }
  return next
}

// Shallow change; a key set to null is removed.
function patchItem(plan, ref, patch) {
  var next = clone(plan)
  var item = itemAt(next, ref)
  if (!item) return next
  for (var key in patch) {
    if (patch[key] === null) delete item[key]
    else item[key] = patch[key]
  }
  if (ref.kind === "room" && patch.id === undefined) settle(next, item)
  return next
}

function setLink(plan, ref, entityId) {
  var id = String(entityId || "")
  return patchItem(plan, ref, { link: id === "" ? null : { service: "homeassistant", id: id } })
}

function removeItem(plan, ref) {
  var next = clone(plan)
  var item = itemAt(next, ref)
  if (!item) return next
  next[KEYS[ref.kind]].splice(ref.index, 1)
  if (ref.kind === "room") {
    next.lights = next.lights.filter(function(l) { return !l || l.room !== item.id })
    next.acs = next.acs.filter(function(a) { return !a || a.room !== item.id })
  }
  return next
}

// Turn (px, pz) about the vertical axis, the way House Control (three.js)
// turns furniture: positive angles are anticlockwise seen from above.
function rotatePoint(px, pz, degrees) {
  var r = degrees * Math.PI / 180
  return [px * Math.cos(r) + pz * Math.sin(r), -px * Math.sin(r) + pz * Math.cos(r)]
}

// What is under (x, z) in the top view, nearest the eye first. `reach` is
// how far off a small thing may be and still count.
function pick(plan, x, z, reach) {
  var r = reach || 0.15
  var i
  var lights = list(plan, "lights")
  for (i = lights.length - 1; i >= 0; i--) {
    var light = lights[i]
    if (light && isPoint(light.pos) && Math.abs(light.pos[0] - x) <= 0.18 + r && Math.abs(light.pos[1] - z) <= 0.18 + r) {
      return { kind: "light", index: i }
    }
  }
  var acs = list(plan, "acs")
  for (i = acs.length - 1; i >= 0; i--) {
    var ac = acs[i]
    if (!ac || !isPoint(ac.pos)) continue
    var along = ac.wall === "east" || ac.wall === "west"
    if (Math.abs(ac.pos[0] - x) <= (along ? 0.2 : 0.45) + r && Math.abs(ac.pos[1] - z) <= (along ? 0.45 : 0.2) + r) {
      return { kind: "ac", index: i }
    }
  }
  var openings = list(plan, "openings")
  for (i = openings.length - 1; i >= 0; i--) {
    var o = openings[i]
    if (!o || !isPoint(o.from) || !isPoint(o.to) || !onGround(plan, o)) continue
    if (x >= Math.min(o.from[0], o.to[0]) - r && x <= Math.max(o.from[0], o.to[0]) + r
        && z >= Math.min(o.from[1], o.to[1]) - r && z <= Math.max(o.from[1], o.to[1]) + r) {
      return { kind: "opening", index: i }
    }
  }
  var furniture = list(plan, "furniture")
  // Rugs lie under everything else.
  for (var pass = 0; pass < 2; pass++) {
    for (i = furniture.length - 1; i >= 0; i--) {
      var piece = furniture[i]
      if (!piece || !isPoint(piece.pos) || !onGround(plan, piece) || (piece.type === "rug") !== (pass === 1)) continue
      var shape = footprint(piece)
      var local = rotatePoint(x - piece.pos[0], z - piece.pos[1], -(isNumber(piece.rot) ? piece.rot : 0))
      if (Math.abs(local[0]) <= shape.width / 2 && Math.abs(local[1]) <= shape.depth / 2) return { kind: "furniture", index: i }
    }
  }
  var all = list(plan, "rooms")
  for (i = all.length - 1; i >= 0; i--) {
    if (all[i] && isRect(all[i].rect) && onGround(plan, all[i]) && inRect(all[i].rect, x, z)) return { kind: "room", index: i }
  }
  return null
}

// A first plan from what Home Assistant knows: one room per area, in rows,
// with its lamps and air conditioners already linked.
//   structure, entities: as HaClient publishes them.
function fromHome(structure, entities, homeName, otherName) {
  var plan = empty(homeName)
  var areas = structure && Array.isArray(structure.rooms) ? structure.rooms : []
  var perRow = Math.max(1, Math.ceil(Math.sqrt(areas.length)))
  var x = 0, z = 0, rowDepth = 0
  var floors = ["oak", "walnut", "tile", "stone"]
  for (var i = 0; i < areas.length; i++) {
    var area = areas[i]
    var lights = area.lights || [], climates = area.climates || []
    var columns = Math.max(1, Math.ceil(Math.sqrt(lights.length)))
    var rows = Math.max(1, Math.ceil(lights.length / columns))
    var width = Math.max(3, columns * 1.4 + 0.6), depth = Math.max(3, rows * 1.4 + 0.6)
    if (i > 0 && i % perRow === 0) { x = 0; z = snap(z + rowDepth); rowDepth = 0 }
    var roomId = freshId(plan, "room")
    plan.rooms.push({ id: roomId, name: area.name !== "" ? area.name : (otherName || "Other"),
      rect: [snap(x), snap(z), snap(width), snap(depth)], floor: floors[i % floors.length] })
    for (var l = 0; l < lights.length; l++) {
      var view = entities ? entities[lights[l]] : null
      plan.lights.push({
        id: freshId(plan, "light"), name: view ? view.name : lights[l], room: roomId, type: "ceiling",
        pos: [snap(x + width * ((l % columns) + 0.5) / columns), snap(z + depth * (Math.floor(l / columns) + 0.5) / rows)],
        link: { service: "homeassistant", id: lights[l] }
      })
    }
    for (var c = 0; c < climates.length; c++) {
      var climate = entities ? entities[climates[c]] : null
      plan.acs.push({
        id: freshId(plan, "ac"), name: climate ? climate.name : climates[c], room: roomId, wall: "north",
        pos: [snap(x + width * (c + 1) / (climates.length + 1)), snap(z)],
        link: { service: "homeassistant", id: climates[c] }
      })
    }
    x = snap(x + width)
    rowDepth = Math.max(rowDepth, depth)
  }
  return plan
}
