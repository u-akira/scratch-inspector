import mermaid from "mermaid"

mermaid.initialize({
  startOnLoad: false,
  theme: "default",
  flowchart: {
    curve: "basis",
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
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/")
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
