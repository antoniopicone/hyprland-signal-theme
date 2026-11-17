import QtQuick
import QtWebSockets

// Home Assistant's WebSocket API, used for one thing: hearing about a state
// the moment it changes. Loaded through a Loader by HaClient, so a system
// without the QtWebSockets module (qt6-websockets) still works, by polling.
Item {
  id: root

  property string url: ""
  property string token: ""
  // True once the event subscription is confirmed.
  property bool ready: false

  // Not "stateChanged": Item already has that signal, for its own `state`.
  signal entityChanged(string entityId, var newState)
  signal authInvalid()

  readonly property bool wanted: url !== "" && token !== ""
  property int backoffMs: 2000

  onWantedChanged: restart()
  onUrlChanged: restart()
  Component.onCompleted: restart()

  function restart() {
    retry.stop()
    ready = false
    ws.active = false
    backoffMs = 2000
    if (wanted) Qt.callLater(function() { if (root.wanted) ws.active = true })
  }

  function send(object) { ws.sendTextMessage(JSON.stringify(object)) }

  function handle(text) {
    var msg
    try { msg = JSON.parse(text) } catch (e) { return }
    if (!msg || typeof msg !== "object") return
    if (msg.type === "auth_required") {
      send({ type: "auth", access_token: root.token })
    } else if (msg.type === "auth_ok") {
      send({ id: 1, type: "subscribe_events", event_type: "state_changed" })
    } else if (msg.type === "auth_invalid") {
      root.ready = false
      root.authInvalid()
    } else if (msg.type === "result" && msg.id === 1) {
      root.ready = msg.success === true
      if (root.ready) root.backoffMs = 2000
    } else if (msg.type === "event" && msg.event && msg.event.data) {
      var data = msg.event.data
      if (data.entity_id) root.entityChanged(String(data.entity_id), data.new_state || null)
    }
  }

  WebSocket {
    id: ws
    url: root.url
    active: false
    onTextMessageReceived: function(message) { root.handle(message) }
    onStatusChanged: {
      if (ws.status !== WebSocket.Closed && ws.status !== WebSocket.Error) return
      root.ready = false
      if (!root.wanted) return
      ws.active = false
      retry.interval = root.backoffMs
      root.backoffMs = Math.min(30000, root.backoffMs * 2)
      retry.restart()
    }
  }

  Timer {
    id: retry
    onTriggered: if (root.wanted) ws.active = true
  }
}
