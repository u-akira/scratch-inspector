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

  window.__mermaidLiveHook.pushDetailFromPayload(payload, "mermaid")
}

export const MermaidHook = {
  mounted() {
    this._lastChart = null
    this._scale = 1
    this._baseSize = null
    this._diagramSvg = null
    this._lastClickedNodeId = null
    this.viewport = this.el.querySelector('[data-role="viewport"]')
    this.inlineDetail = this.el.querySelector('[data-role="flow-inline-detail"]')
    this.zoomLabel = this.el.querySelector("[data-zoom-label]")
    this.handleZoomClick = this.handleZoomClick.bind(this)
    this.handleNodeClick = this.handleNodeClick.bind(this)
    this.handleViewportScroll = this.positionInlineDetail.bind(this)
    this.handleWindowResize = this.positionInlineDetail.bind(this)

    this.el.addEventListener("click", this.handleZoomClick)
    this.viewport?.addEventListener("click", this.handleNodeClick)
    this.viewport?.addEventListener("scroll", this.handleViewportScroll)
    window.addEventListener("resize", this.handleWindowResize)
    window.__mermaidLiveHook = this
    this.renderDiagram()
  },

  updated() {
    this.inlineDetail = this.el.querySelector('[data-role="flow-inline-detail"]')
    const chartDef = this.el.getAttribute("data-chart")
    if (chartDef !== this._lastChart) {
      this._scale = 1
      this.renderDiagram()
      return
    }

    this.positionInlineDetail()
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleZoomClick)
    this.viewport?.removeEventListener("click", this.handleNodeClick)
    this.viewport?.removeEventListener("scroll", this.handleViewportScroll)
    window.removeEventListener("resize", this.handleWindowResize)

    if (window.__mermaidLiveHook === this) {
      window.__mermaidLiveHook = null
    }
  },

  parsePayloadMap(chartDef) {
    const map = new Map()
    if (!chartDef) return map

    const re = /^click\s+([^\s]+)\s+call\s+__mermaidNodeClick\("([^"]+)"\)/gm
    let m
    while ((m = re.exec(chartDef)) !== null) {
      map.set(m[1], m[2])
    }
    return map
  },

  pushDetailFromPayload(payload, source = "fallback") {
    if (!payload) return

    const now = Date.now()
    if (
      this._lastPushedPayload === payload &&
      now - (this._lastPushedAt || 0) < 250
    ) {
      return
    }

    this._lastPushedPayload = payload
    this._lastPushedAt = now

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
      this.pushEvent("flow_select_detail", detail)
    } catch (e) {
      console.error("mermaid click decode error", e)
    }
  },

  handleNodeClick(event) {
    if (!this.viewport) return

    let nodeId = null
    const path = typeof event.composedPath === "function" ? event.composedPath() : []

    for (const el of path) {
      if (!el || typeof el !== "object") continue

      const dataId =
        typeof el.getAttribute === "function" ? el.getAttribute("data-id") : null
      if (dataId) {
        nodeId = dataId
        break
      }

      const domId =
        typeof el.getAttribute === "function" ? el.getAttribute("id") : null
      if (!domId) continue

      const m = domId.match(/^flowchart-(.+)-\d+$/)
      if (m && m[1]) {
        nodeId = m[1]
        break
      }
    }

    if (!nodeId || !this._payloadMap) return

    this._lastClickedNodeId = nodeId
    const payload = this._payloadMap.get(nodeId)
    if (!payload) return
    this.pushDetailFromPayload(payload, "fallback")
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

    const svgEl = this._diagramSvg
    if (!svgEl || !this._baseSize) return

    svgEl.style.width = `${this._baseSize.width * this._scale}px`
    svgEl.style.height = `${this._baseSize.height * this._scale}px`
    this.positionInlineDetail()
  },

  findSelectedNode(svgEl) {
    const direct = svgEl.querySelector("g.node.selectedNode")
    if (direct) return direct

    const inner = svgEl.querySelector("g.node .selectedNode")
    if (inner) return inner.closest("g.node")

    // Fallback for Mermaid variants where selected class is attached elsewhere.
    const loose = svgEl.querySelector(".selectedNode")
    if (!loose) return null
    return loose.closest("g[data-node='true']") || loose.closest("g.node")
  },

  positionInlineDetail() {
    if (!this.viewport) return
    const panel = this.inlineDetail
    if (!panel) return

    const svgEl = this._diagramSvg
    let selectedNode = svgEl ? this.findSelectedNode(svgEl) : null
    if (!selectedNode && svgEl && this._lastClickedNodeId) {
      selectedNode = svgEl.querySelector(`g.node[data-id="${CSS.escape(this._lastClickedNodeId)}"]`)
    }

    if (!svgEl) {
      panel.style.display = "none"
      return
    }

    if (!selectedNode) {
      // Keep detail visible even if selected node lookup fails.
      panel.style.display = "block"
      panel.style.visibility = "visible"
      panel.style.left = `${this.viewport.scrollLeft + 8}px`
      panel.style.top = `${this.viewport.scrollTop + 8}px`
      return
    }

    const viewportRect = this.viewport.getBoundingClientRect()
    const nodeRect = selectedNode.getBoundingClientRect()
    const padding = 8
    const viewportWidth = this.viewport.clientWidth
    const panelWidth = Math.min(560, Math.max(260, viewportWidth - 16))
    const desiredLeft =
      this.viewport.scrollLeft + (nodeRect.left - viewportRect.left) + nodeRect.width / 2 - panelWidth / 2
    const minLeft = this.viewport.scrollLeft + 8
    const maxLeft = this.viewport.scrollLeft + Math.max(0, viewportWidth - panelWidth - 8)
    const nextLeft = Math.max(minLeft, Math.min(desiredLeft, maxLeft))

    // Measure panel height before clamping vertical position.
    panel.style.width = `${panelWidth}px`
    panel.style.left = `${nextLeft}px`
    panel.style.top = "0px"
    panel.style.visibility = "hidden"
    panel.style.display = "block"
    const panelHeight = panel.offsetHeight || 0

    const viewportTop = this.viewport.scrollTop
    const viewportBottom = viewportTop + this.viewport.clientHeight
    const nodeBottomInViewport =
      this.viewport.scrollTop + (nodeRect.bottom - viewportRect.top)
    const nodeTopInViewport =
      this.viewport.scrollTop + (nodeRect.top - viewportRect.top)

    // Prefer below node, fallback to above node when it would be clipped.
    const preferredTop = nodeBottomInViewport + padding
    const aboveTop = nodeTopInViewport - panelHeight - padding
    const fitsBelow = preferredTop + panelHeight <= viewportBottom - 4
    const rawTop = fitsBelow ? preferredTop : aboveTop
    const minTop = viewportTop + 4
    const maxTop = Math.max(minTop, viewportBottom - panelHeight - 4)
    const nextTop = Math.max(minTop, Math.min(rawTop, maxTop))

    panel.style.left = `${nextLeft}px`
    panel.style.top = `${nextTop}px`
    panel.style.visibility = "visible"
    panel.style.display = "block"
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
    this._diagramSvg = null
    const preservedDetail = this.viewport.querySelector('[data-role="flow-inline-detail"]')
    this.viewport.innerHTML = ""
    if (preservedDetail) {
      this.viewport.appendChild(preservedDetail)
      this.inlineDetail = preservedDetail
    }
    this.updateZoomLabel()

    const id = `mermaid-diagram-${diagramCounter++}`
    this._payloadMap = this.parsePayloadMap(chartDef)

    try {
      const { svg, bindFunctions } = await mermaid.render(id, chartDef)
      const diagramHost = document.createElement("div")
      diagramHost.setAttribute("data-role", "diagram-host")
      diagramHost.innerHTML = svg
      this.viewport.appendChild(diagramHost)
      if (bindFunctions) bindFunctions(diagramHost)

      const svgEl = diagramHost.querySelector("svg")
      if (svgEl) {
        this._diagramSvg = svgEl
        this.forceHorizontalAnchors(svgEl)

        svgEl.style.maxWidth = "none"
        svgEl.style.width = "auto"
        svgEl.style.height = "auto"
        svgEl.style.display = "block"

        this._baseSize = this.measureBaseSize(svgEl)
        this.applyScale()
        this.positionInlineDetail()
      }
    } catch (e) {
      console.error("Mermaid render error:", e)
      const err = document.createElement("p")
      err.style.color = "#ef4444"
      err.style.fontSize = "0.75rem"
      err.style.padding = "8px"
      err.textContent = "Failed to render the diagram."
      this.viewport.appendChild(err)
    }
  },
}
