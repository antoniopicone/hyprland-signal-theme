import QtQuick
import "Ha.js" as Ha
import "Plan.js" as Plan

// The connection to one Home Assistant server and the home it describes.
// Plain QtQuick on purpose: Service.qml adds the Quickshell parts (config
// file, IPC), and tests/client_test.py drives this file against a pretend
// server.
//
// Reading: GET /api/states, areas through one POST /api/template, then a
// WebSocket subscription for changes. Without QtWebSockets it polls.
// Writing: POST /api/services/<domain>/<service>.
Item {
  id: root
  visible: false

  // --- in -------------------------------------------------------------
  property string url: ""
  property string token: ""
  property int pollIntervalSec: 5
  property bool includeSwitches: false
  property string exclude: ""
  property bool useWebSocket: true
  // How many panels are open; an open panel polls faster when not live.
  property int openCount: 0
  // The floor plan (see Plan.js), or null when there is none.
  property var plan: null
  property string planError: ""

  // --- out ------------------------------------------------------------
  // "unconfigured" | "connecting" | "online" | "auth" | "offline"
  property string status: "unconfigured"
  property string errorText: ""
  property string locationName: ""
  property string unit: "°C"
  property var structure: ({ scenes: [], rooms: [], lightCount: 0, climateCount: 0 })
  property var entities: ({})
  property int lightsOn: 0
  property int lightCount: 0
  property bool climateOn: false
  property string summaryText: ""
  property string activeScene: ""

  readonly property string baseUrl: Ha.normalizeUrl(url)
  readonly property bool configured: baseUrl !== "" && token !== ""
  readonly property bool online: status === "online"
  readonly property bool realtime: socketLoader.item ? socketLoader.item.ready === true : false
  readonly property bool socketSupported: !_socketUnavailable

  signal commandFailed(string entityId, string message)
  // The editor changed the plan; Service.qml writes it to its file.
  signal planEdited()

  function savePlan(next) {
    plan = next
    planError = ""
    planEdited()
  }

  // Lamps (lights and plugs) or air conditioners the plan can link to.
  function candidates(kind) { return Ha.candidates(_states, _areas, kind) }

  // --- private --------------------------------------------------------
  property var _states: ({})
  property var _areas: ({})
  property var _lastMode: ({})
  property string _structureSig: ""
  // Bumped whenever the connection settings change, so an answer to a
  // request made for the old server is dropped.
  property int _generation: 0
  property bool _loadingStates: false
  property double _statesAskedMs: 0
  property double _areasLoadedMs: 0
  property bool _socketUnavailable: false

  // Deferred: the address and the token usually change together, and the
  // bindings that depend on them must have caught up before reconnecting.
  onBaseUrlChanged: Qt.callLater(reconnect)
  onTokenChanged: Qt.callLater(reconnect)
  onIncludeSwitchesChanged: rebuild()
  onExcludeChanged: rebuild()
  onPlanChanged: rebuild()
  Component.onCompleted: Qt.callLater(reconnect)

  function request(method, path, body, done) {
    var gen = _generation
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (gen !== root._generation) return
      done(xhr.status, xhr.responseText)
    }
    xhr.open(method, baseUrl + path)
    xhr.setRequestHeader("Authorization", "Bearer " + token)
    if (body !== undefined && body !== null) {
      xhr.setRequestHeader("Content-Type", "application/json")
      xhr.send(JSON.stringify(body))
    } else {
      xhr.send()
    }
  }

  function reconnect() {
    _generation++
    _loadingStates = false
    _states = ({})
    _areas = ({})
    _areasLoadedMs = 0
    activeScene = ""
    rebuildNow()
    if (!configured) {
      status = "unconfigured"
      errorText = ""
      return
    }
    status = "connecting"
    errorText = ""
    hello()
  }

  // GET /api/config tells an unreachable server from a refused token, and
  // gives the home's name and temperature unit.
  function hello() {
    request("GET", "/api/config", null, function(code, text) {
      if (code === 401 || code === 403) {
        root.status = "auth"
        root.errorText = "token"
        return
      }
      if (code < 200 || code >= 300) {
        root.status = "offline"
        root.errorText = code === 0 ? "unreachable" : "HTTP " + code
        return
      }
      try {
        var config = JSON.parse(text)
        root.locationName = String(config.location_name || "")
        if (config.unit_system && config.unit_system.temperature) root.unit = String(config.unit_system.temperature)
      } catch (e) {}
      root.loadStates()
      root.loadAreas()
    })
  }

  function loadStates() {
    var now = Date.now()
    // A request that never answers must not block reading for good.
    if (_loadingStates && now - _statesAskedMs < 15000) return
    _loadingStates = true
    _statesAskedMs = now
    request("GET", "/api/states", null, function(code, text) {
      root._loadingStates = false
      if (code === 401 || code === 403) {
        root.status = "auth"
        root.errorText = "token"
        return
      }
      if (code < 200 || code >= 300) {
        root.status = "offline"
        root.errorText = code === 0 ? "unreachable" : "HTTP " + code
        return
      }
      var list
      try { list = JSON.parse(text) } catch (e) { return }
      root._states = Ha.indexStates(list)
      root.status = "online"
      root.errorText = ""
      root.rebuildNow()
    })
  }

  function loadAreas() {
    request("POST", "/api/template", { template: Ha.AREA_TEMPLATE }, function(code, text) {
      // Refused for a token without admin rights: everything lands in one room.
      if (code < 200 || code >= 300) return
      root._areas = Ha.parseAreas(text)
      root._areasLoadedMs = Date.now()
      root.rebuild()
    })
  }

  function refresh() {
    if (!configured) return
    if (status === "online" || status === "connecting") {
      loadStates()
      loadAreas()
    } else {
      reconnect()
    }
  }

  function rebuild() { rebuildTimer.restart() }

  function rebuildNow() {
    rebuildTimer.stop()
    var model = Ha.buildModel(_states, _areas, {
      includeSwitches: includeSwitches, exclude: exclude, unit: unit, always: Plan.linkedIds(plan)
    })
    for (var id in model.entities) {
      var e = model.entities[id]
      if (e.kind === "climate" && e.on) _lastMode[id] = e.mode
    }
    var sig = JSON.stringify(model.structure)
    if (sig !== _structureSig) {
      _structureSig = sig
      structure = model.structure
    }
    entities = model.entities
    lightsOn = model.lightsOn
    lightCount = model.lightCount
    climateOn = model.climateOn
    summaryText = model.summaryText
  }

  function applyState(id, state) {
    if (!Ha.relevant(id)) return
    var next = _states
    if (state) next[id] = state
    else delete next[id]
    _states = next
    rebuild()
  }

  function entity(id) { return entities[id] || null }

  // --- commands -------------------------------------------------------

  function send(c) {
    if (!c || !online) return
    var id = c.data && typeof c.data.entity_id === "string" ? c.data.entity_id : ""
    var expected = id !== "" ? Ha.optimisticState(_states[id], c) : null
    if (expected) {
      _states[id] = expected
      rebuildNow()
    }
    request("POST", "/api/services/" + c.domain + "/" + c.service, c.data, function(code, text) {
      if (code >= 200 && code < 300) {
        // The answer lists the states the call changed.
        try {
          var changed = JSON.parse(text)
          if (Array.isArray(changed)) {
            for (var i = 0; i < changed.length; i++) {
              if (changed[i] && changed[i].entity_id) root.applyState(String(changed[i].entity_id), changed[i])
            }
          }
        } catch (e) {}
      } else {
        root.commandFailed(id, code === 0 ? "unreachable" : "HTTP " + code)
        root.loadStates()
      }
    })
    // Whatever the device ended up doing, show that.
    settle.restart()
  }

  function setLight(id, patch) {
    var view = entity(id)
    if (!view || view.kind !== "light" || !view.available) return
    activeScene = ""
    send(Ha.lightCall(view, patch))
  }

  function toggleLight(id) {
    var view = entity(id)
    if (view) setLight(id, { on: !view.on })
  }

  // A gate, a shutter or a fan.
  function toggleDevice(id) {
    var view = entity(id)
    if (!view || view.kind !== "device" || !view.available) return
    activeScene = ""
    send(Ha.deviceCall(view))
  }

  function setClimate(id, patch) {
    var view = entity(id)
    if (!view || view.kind !== "climate" || !view.available) return
    activeScene = ""
    var calls = Ha.climateCalls(view, patch, _lastMode[id])
    for (var i = 0; i < calls.length; i++) send(calls[i])
  }

  function stepClimate(id, direction) {
    var view = entity(id)
    if (!view || view.target === null) return
    setClimate(id, { target: view.target + direction * view.step })
  }

  function activateScene(id) {
    if (!online) return
    activeScene = id
    send(Ha.call("scene", "turn_on", { entity_id: id }))
  }

  function roomLights(roomName) {
    var rooms = structure.rooms
    for (var i = 0; i < rooms.length; i++) if (rooms[i].name === roomName) return rooms[i].lights
    return []
  }

  function setLights(ids, on) {
    var byDomain = {}
    for (var i = 0; i < ids.length; i++) {
      var view = entity(ids[i])
      if (!view || !view.available || view.on === on) continue
      if (!byDomain[view.domain]) byDomain[view.domain] = []
      byDomain[view.domain].push(view.id)
      var expected = Ha.optimisticState(_states[view.id], Ha.call(view.domain, on ? "turn_on" : "turn_off", {}))
      if (expected) _states[view.id] = expected
    }
    activeScene = ""
    rebuildNow()
    for (var domain in byDomain) {
      send(Ha.call(domain, on ? "turn_on" : "turn_off", { entity_id: byDomain[domain] }))
    }
  }

  function allLightsOff() {
    var ids = []
    for (var id in entities) if (entities[id].kind === "light") ids.push(id)
    setLights(ids, false)
  }

  function toggleRoom(roomName) {
    var ids = roomLights(roomName)
    var anyOn = false
    for (var i = 0; i < ids.length; i++) {
      var view = entity(ids[i])
      if (view && view.on) anyOn = true
    }
    setLights(ids, !anyOn)
  }

  // Find a light, AC or scene by entity id or by its name, for IPC.
  function resolve(nameOrId, kinds) {
    var wanted = String(nameOrId || "").trim().toLowerCase()
    if (wanted === "") return ""
    for (var id in entities) {
      var e = entities[id]
      if (kinds.indexOf(e.kind) === -1) continue
      if (id.toLowerCase() === wanted || e.name.toLowerCase() === wanted) return id
    }
    if (kinds.indexOf("scene") !== -1) {
      var scenes = structure.scenes
      for (var i = 0; i < scenes.length; i++) {
        if (scenes[i].id.toLowerCase() === wanted || scenes[i].name.toLowerCase() === wanted) return scenes[i].id
      }
    }
    return ""
  }

  // --- timers and the live connection ---------------------------------

  Timer {
    id: rebuildTimer
    interval: 40
    onTriggered: root.rebuildNow()
  }

  Timer {
    id: settle
    interval: 2500
    onTriggered: root.loadStates()
  }

  Timer {
    id: poll
    running: root.configured && root.status !== "auth"
    repeat: true
    interval: {
      if (root.status !== "online") return 10000
      if (root.realtime) return 60000
      var seconds = Math.max(2, root.pollIntervalSec)
      return (root.openCount > 0 ? Math.min(seconds, 3) : seconds) * 1000
    }
    onTriggered: {
      if (root.status !== "online") { root.reconnect(); return }
      root.loadStates()
      if (Date.now() - root._areasLoadedMs > 600000) root.loadAreas()
    }
  }

  Loader {
    id: socketLoader
    active: root.useWebSocket && !root._socketUnavailable && root.configured && root.status === "online"
    source: "HaSocket.qml"
    onStatusChanged: if (status === Loader.Error) root._socketUnavailable = true
    onLoaded: {
      item.token = Qt.binding(function() { return root.token })
      item.url = Qt.binding(function() { return Ha.wsUrl(root.baseUrl) })
    }
  }

  Connections {
    target: socketLoader.item
    ignoreUnknownSignals: true
    function onEntityChanged(entityId, newState) { root.applyState(entityId, newState) }
    // Events may have been missed while the socket was down.
    function onReadyChanged() { if (socketLoader.item && socketLoader.item.ready) root.loadStates() }
  }
}
