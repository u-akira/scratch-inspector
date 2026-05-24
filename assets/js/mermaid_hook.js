import mermaid from "mermaid"

mermaid.initialize({
  startOnLoad: false,
  theme: "default",
  flowchart: {
    curve: "linear",
    useMaxWidth: false,
    htmlLabels: true,
  },
  securityLevel: "loose",
})

let diagramCounter = 0
const MIN_SCALE = 0.5
const MAX_SCALE = 2.0
const SCALE_STEP = 0.1

// Global click handler: Mermaid calls this function when a node is clicked.
// The payload is encoded as Base64URL "script kind/id" JSON.
window.__mermaidNodeClick = function (arg1, arg2) {
  if (!window.__mermaidLiveHook) return

  const payload = typeof arg2 === "string" ? arg2 : typeof arg1 === "string" ? arg1 : null
  if (!payload) return

  try {
    const b64Raw = payload.replace(/-/g, "+").replace(/_/g, "/")
    const paddingLength = (4 - (b64Raw.length % 4)) % 4
    const b64 = b64Raw + "=".repeat(paddingLength)
    const decoded = decodeURIComponent(
      atob(b64)
        .split("")
        .map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2))
        .join("")
    )

    const detail = JSON.parse(decoded)
    window.__mermaidLiveHook.pushEvent("flow_select_detail", detail)
  } catch (e) {
    console.error("mermaid click decode error", e)
  }
}

export const MermaidHook = {
  mounted() {
    this._lastChart = null
    this._scale = 1
    this._baseSize = null
    this.viewport = this.el.querySelector('[data-role="viewport"]')
    this.zoomLabel = this.el.querySelector("[data-zoom-label]")
    this.handleZoomClick = this.handleZoomClick.bind(this)

    this.el.addEventListener("click", this.handleZoomClick)
    window.__mermaidLiveHook = this
    this.renderDiagram()
  },

  updated() {
    const chartDef = this.el.getAttribute("data-chart")
    if (chartDef !== this._lastChart) {
      this._scale = 1
      this.renderDiagram()
    }
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleZoomClick)

    if (window.__mermaidLiveHook === this) {
      window.__mermaidLiveHook = null
    }
  },

  handleZoomClick(event) {
    const button = event.target.closest("[data-zoom-action]")
    if (!button || !this.el.contains(button)) return

    const action = button.dataset.zoomAction
    if (action === "in") {
      this.setScale(this._scale + SCALE_STEP)
    } else if (action === "out") {
      this.setScale(this._scale - SCALE_STEP)
    } else if (action === "reset") {
      this.setScale(1)
    }
  },

  setScale(nextScale) {
    this._scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, Number(nextScale.toFixed(2))))
    this.applyScale()
  },

  updateZoomLabel() {
    if (this.zoomLabel) {
      this.zoomLabel.textContent = `${Math.round(this._scale * 100)}%`
    }
  },

  applyScale() {
    this.updateZoomLabel()

    const svgEl = this.viewport?.querySelector("svg")
    if (!svgEl || !this._baseSize) return

    svgEl.style.width = `${this._baseSize.width * this._scale}px`
    svgEl.style.height = `${this._baseSize.height * this._scale}px`
  },

  parseNodeTranslate(nodeEl) {
    const raw = nodeEl.getAttribute("transform") || ""
    const m = raw.match(/translate\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)/)
    if (!m) return null
    return { x: Number(m[1]), y: Number(m[2]) }
  },

  extractEdgeEndpointIds(pathEl) {
    const classes = (pathEl.getAttribute("class") || "").split(/\s+/)
    const src = classes.find((c) => c.startsWith("LS-"))
    const dst = classes.find((c) => c.startsWith("LE-"))
    if (!src || !dst) return null
    return { src: src.slice(3), dst: dst.slice(3) }
  },

  // Mermaid/Dagre may choose top/bottom ports for fan-out edges.
  // For LR flow readability, force source at right edge and target at left edge.
  forceHorizontalAnchors(svgEl) {
    const nodeBoxes = new Map()

    svgEl.querySelectorAll("g.node[data-id]").forEach((nodeEl) => {
      const id = nodeEl.getAttribute("data-id")
      if (!id) return

      const t = this.parseNodeTranslate(nodeEl)
      if (!t) return

      const rect = nodeEl.querySelector("rect.label-container")
      if (!rect) return

      const rx = Number(rect.getAttribute("x") || 0)
      const ry = Number(rect.getAttribute("y") || 0)
      const rw = Number(rect.getAttribute("width") || 0)
      const rh = Number(rect.getAttribute("height") || 0)

      nodeBoxes.set(id, {
        left: t.x + rx,
        right: t.x + rx + rw,
        top: t.y + ry,
        bottom: t.y + ry + rh,
      })
    })

    const coordRe = /(-?\d*\.?\d+),(-?\d*\.?\d+)/g

    const edgePaths = svgEl.querySelectorAll("g.edgePaths path.flowchart-link, g.edgePaths path")

    edgePaths.forEach((pathEl) => {
      const ids = this.extractEdgeEndpointIds(pathEl)
      if (!ids) return

      const src = nodeBoxes.get(ids.src)
      const dst = nodeBoxes.get(ids.dst)
      if (!src || !dst) return

      const d = pathEl.getAttribute("d") || ""
      const matches = [...d.matchAll(coordRe)]
      if (matches.length < 2) return

      const first = matches[0]
      const last = matches[matches.length - 1]
      const x1 = Number(first[1])
      const y1raw = Number(first[2])
      const x2 = Number(last[1])
      const y2raw = Number(last[2])

      const y1 = Math.max(src.top + 4, Math.min(y1raw, src.bottom - 4))
      const y2 = Math.max(dst.top + 4, Math.min(y2raw, dst.bottom - 4))
      const sx = src.right
      const tx = dst.left
      const midX = Number(((sx + tx) / 2).toFixed(3))

      // Always rebuild path so start/end anchors are deterministic.
      // Preserve near-straight look for same-row links.
      const rebuilt =
        Math.abs(y1 - y2) < 1
          ? `M${sx},${y1}L${tx},${y2}`
          : `M${sx},${y1}L${midX},${y1}L${midX},${y2}L${tx},${y2}`

      pathEl.setAttribute("d", rebuilt)
    })

    svgEl.setAttribute("data-anchor-patched", "1")
    svgEl.setAttribute("data-anchor-path-count", String(edgePaths.length))
  },

  measureBaseSize(svgEl) {
    const viewBox = svgEl.viewBox?.baseVal
    if (viewBox && viewBox.width > 0 && viewBox.height > 0) {
      return { width: viewBox.width, height: viewBox.height }
    }

    const rect = svgEl.getBoundingClientRect()
    return {
      width: rect.width || svgEl.clientWidth || 0,
      height: rect.height || svgEl.clientHeight || 0,
    }
  },

  async renderDiagram() {
    const chartDef = this.el.getAttribute("data-chart")
    if (!chartDef || chartDef === "" || !this.viewport) return

    this._lastChart = chartDef
    this._baseSize = null
    this.viewport.innerHTML = ""
    this.updateZoomLabel()

    const id = `mermaid-diagram-${diagramCounter++}`

    try {
      const { svg, bindFunctions } = await mermaid.render(id, chartDef)
      this.viewport.innerHTML = svg
      if (bindFunctions) bindFunctions(this.viewport)

      const svgEl = this.viewport.querySelector("svg")
      if (svgEl) {
        this.forceHorizontalAnchors(svgEl)

        svgEl.style.maxWidth = "none"
        svgEl.style.width = "auto"
        svgEl.style.height = "auto"
        svgEl.style.display = "block"

        this._baseSize = this.measureBaseSize(svgEl)
        this.applyScale()
      }
    } catch (e) {
      console.error("Mermaid render error:", e)
      this.viewport.innerHTML =
        `<p style="color: #ef4444; font-size: 0.75rem; padding: 8px;">Failed to render the diagram.</p>`
    }
  },
}
