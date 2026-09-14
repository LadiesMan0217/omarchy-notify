# Minimal Omarchy API needed by Omarchy Notify

Omarchy Notify intentionally does not traverse private shell objects. On Omarchy 4.0.3, arbitrary `bar-widget` plugins receive a service-less `PluginShellApi`; only a full replacement bar (or a trusted `omarchy.indicators` clone) receives the narrow notifications proxy, and that proxy currently contains only DND state.

For a secure third-party notification center, the shell could expose a dedicated, capability-scoped facade to the widget that requested it:

```qml
// Modelo só de leitura. Linhas precisam ser snapshots, nunca QObjects vivos.
property var popupModel
property bool doNotDisturb

function setDoNotDisturb(value)
function showRecentHistory()
function dismissPopup(index)
function invokePopupDefault(index)
```

The service already owns these operations internally in Omarchy 4.0.3. The facade should retain the same validation and stale-row protections, avoid exposing `liveRefs`, filesystem paths, generic process execution, or the ShellRoot, and document whether `showRecentHistory()` replaces or supplements `popupModel`.

No upstream source is copied by this project, and this file is a proposal only; Omarchy Notify does not depend on it being implemented.
