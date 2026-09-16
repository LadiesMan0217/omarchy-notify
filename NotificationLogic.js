.pragma library

// Só prepara dados para a tela. Estado fica no QML.

function text(value) {
  return String(value === undefined || value === null ? "" : value)
}

function decodeHtmlEntities(str) {
  return text(str)
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&nbsp;/gi, " ")
}

function cleanText(value) {
  // Limpeza visual de marcações HTML simples (<a>, <b>, etc.).
  // As entidades são decodificadas antes para que tags escapadas como &lt;b&gt; também sejam limpas.
  // A barreira real contra execução/rich text continua sendo textFormat: Text.PlainText nos Text do QML.
  var decoded = decodeHtmlEntities(text(value))
  return decoded
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
}

function plainBody(value) {
  return cleanText(value)
}

function sanitizeUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== "string") return ""
  var url = decodeHtmlEntities(rawUrl).trim()
  // Apenas esquemas http:// e https:// são permitidos
  if (!/^https?:\/\//i.test(url)) return ""
  // Rejeitar espaços, aspas, quebras de linha, tags, control chars ou barras invertidas
  if (/[\s<>"'\\`\x00-\x1f\x7f]/.test(url)) return ""
  // Verificar se possui host válido após o esquema
  var afterScheme = url.replace(/^https?:\/\//i, "")
  if (afterScheme.length === 0 || afterScheme.charAt(0) === "/" || afterScheme.charAt(0) === "?") return ""
  return url
}

function extractLinkUrl(value) {
  var str = decodeHtmlEntities(text(value))
  var match = str.match(/<a\b[^>]*\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^>\s]+))[^>]*>/i)
  if (!match) return ""
  var rawUrl = match[1] !== undefined ? match[1] : (match[2] !== undefined ? match[2] : match[3])
  return sanitizeUrl(rawUrl)
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
  // Só aceita imagem local; o drawer não abre rede por conteúdo de notificação.
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
      summary: cleanText(source.summary),
      body: plainBody(source.body),
      image: text(source.image),
      urgency: Number(source.urgency || 0),
      timestamp: Number(source.timestamp || 0),
      relativeTime: relativeTime(source.timestamp),
      hasDefaultAction: text(source.execArgv).length > 0,
      linkUrl: extractLinkUrl(source.body) || extractLinkUrl(source.summary)
    })
  }
  return rows
}

function rowsFromEntries(entries, query, unreadOnly, lastSeen) {
  var rows = []
  if (!Array.isArray(entries)) return rows
  for (var i = 0; i < entries.length; ++i) {
    var source = entries[i]
    if (!source || !matches(source, query)) continue
    if (unreadOnly && Number(source.timestamp || 0) <= Number(lastSeen || 0)) continue
    rows.push({
      key: text(source.key), app: text(source.app), appIcon: text(source.appIcon),
      summary: cleanText(source.summary), body: plainBody(source.body), image: text(source.image),
      urgency: Number(source.urgency || 0), timestamp: Number(source.timestamp || 0),
      relativeTime: relativeTime(source.timestamp), hasDefaultAction: false,
      linkUrl: extractLinkUrl(source.body) || extractLinkUrl(source.summary)
    })
  }
  return rows
}
