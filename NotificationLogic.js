.pragma library

// Presentation-only helpers. This file deliberately owns no QML state and
// never mutates an Omarchy service model.

function text(value) {
  return String(value === undefined || value === null ? "" : value)
}

function plainBody(value) {
  // The built-in daemon safely handles markup in its toast renderer. The
  // center is plain-text by design: it never feeds sender-controlled HTML to
  // a rich-text item and consequently cannot load remote <img> sources.
  return text(value)
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/\s+/g, " ")
    .trim()
}

function searchable(row) {
  return (text(row.app) + "\n" + text(row.summary) + "\n" + plainBody(row.body)).toLocaleLowerCase()
}

function matches(row, query) {
  var needle = text(query).trim().toLocaleLowerCase()
  return needle.length === 0 || searchable(row).indexOf(needle) !== -1
}

function relativeTime(timestamp, now) {
  var value = Number(timestamp || 0)
  if (!isFinite(value) || value <= 0) return ""
  var seconds = Math.max(0, Math.floor((Number(now || Date.now()) - value) / 1000))
  if (seconds < 45) return "now"
  if (seconds < 3600) return Math.floor(seconds / 60) + "m"
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h"
  if (seconds < 604800) return Math.floor(seconds / 86400) + "d"
  return Math.floor(seconds / 604800) + "w"
}

function localImageSource(value) {
  var source = text(value)
  // Never allow the center itself to turn notification content into a network
  // request. The daemon persists accepted notification images locally.
  return source.indexOf("file://") === 0 || source.charAt(0) === "/" ? source : ""
}

function rowsFromModel(model, query) {
  var rows = []
  if (!model || typeof model.count !== "number" || typeof model.get !== "function") return rows
  for (var i = 0; i < model.count; ++i) {
    var source = model.get(i)
    if (!source || source.originalId < 0 || !matches(source, query)) continue
    rows.push({
      serviceIndex: i,
      app: text(source.app),
      appIcon: text(source.appIcon),
      summary: text(source.summary),
      body: plainBody(source.body),
      image: text(source.image),
      urgency: Number(source.urgency || 0),
      timestamp: Number(source.timestamp || 0),
      relativeTime: relativeTime(source.timestamp),
      hasDefaultAction: text(source.execArgv).length > 0
    })
  }
  return rows
}
