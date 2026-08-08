import mermaid from "mermaid"

mermaid.initialize({
  startOnLoad: false,
  theme: "default",
  flowchart: {
    curve: "linear",
    useMaxWidth: false,
    htmlLabels: true,
    nodeSpacing: 48,
    rankSpacing: 84,
  },
  securityLevel: "loose",
})

let diagramCounter = 0
const MIN_SCALE = 0.5
const MAX_SCALE = 2.0
const SCALE_STEP = 0.1
const EDGE_TARGET_GAP = 11
const EDGE_LANE_STEP = 14

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
    this._lastClickPoint = null
    this._selectedDetailKey = null
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

    if (!this.diagramIsMounted()) {
      this.renderDiagram()
      return
    }

    const selection = this.syncSelectedNode()
    this.positionInlineDetail()
    if (selection.changed) {
      this.ensureInlineDetailVisible(selection.node)
    }
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

  diagramIsMounted() {
    return Boolean(
      this.viewport &&
        this._diagramSvg &&
        this._diagramSvg.isConnected &&
        this.viewport.querySelector('[data-role="diagram-host"] svg')
    )
  },

  decodePayload(payload) {
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
      return JSON.parse(decoded)
    } catch (_e) {
      return null
    }
  },

  selectedDetail() {
    const raw = this.el.getAttribute("data-selected-detail")
    if (!raw) return null

    try {
      return JSON.parse(raw)
    } catch (_e) {
      return null
    }
  },

  detailKey(detail) {
    if (!detail) return null
    const kind = detail.kind ?? detail["kind"]
    const id = detail.id ?? detail["id"]
    if (kind == null || id == null) return null

    const sprite = detail.sprite ?? detail["sprite"] ?? ""
    const type = detail.type ?? detail["type"] ?? ""
    return [kind, id, sprite, type].map((value) => String(value)).join("\u001f")
  },

  selectedNodeFromDetail() {
    if (!this._diagramSvg || !this._payloadMap) return { key: null, node: null }

    const key = this.detailKey(this.selectedDetail())
    if (!key) return { key: null, node: null }

    for (const [nodeId, payload] of this._payloadMap.entries()) {
      if (this.detailKey(this.decodePayload(payload)) !== key) continue
      const node = this._diagramSvg.querySelector(`g.node[data-id="${CSS.escape(nodeId)}"]`)
      return { key, node }
    }

    return { key, node: null }
  },

  syncSelectedNode() {
    if (!this._diagramSvg) return { changed: false, node: null }

    this._diagramSvg.querySelectorAll(".selectedNode").forEach((el) => {
      el.classList.remove("selectedNode")
    })

    const { key, node } = this.selectedNodeFromDetail()
    if (node) {
      node.classList.add("selectedNode")
      this._lastClickedNodeId = node.getAttribute("data-id") || this._lastClickedNodeId
    }

    const changed = key !== this._selectedDetailKey
    this._selectedDetailKey = key
    return { changed, node }
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
      const detail = this.decodePayload(payload)
      if (!detail) return
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
    this._lastClickPoint = { x: event.clientX, y: event.clientY }
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
      panel.style.display = "flex"
      panel.style.visibility = "visible"
      panel.style.left = `${this.viewport.scrollLeft + 8}px`
      panel.style.top = `${this.viewport.scrollTop + 8}px`
      return
    }

    const viewportRect = this.viewport.getBoundingClientRect()
    const nodeRect = selectedNode.getBoundingClientRect()
    const padding = 10
    const viewportWidth = this.viewport.clientWidth
    const panelWidth = Math.min(560, Math.max(260, viewportWidth - 16))

    const anchorX =
      this._lastClickPoint &&
      this._lastClickPoint.x >= nodeRect.left - 4 &&
      this._lastClickPoint.x <= nodeRect.right + 4
        ? this._lastClickPoint.x
        : nodeRect.left + nodeRect.width / 2
    const anchorY =
      this._lastClickPoint &&
      this._lastClickPoint.y >= nodeRect.top - 4 &&
      this._lastClickPoint.y <= nodeRect.bottom + 4
        ? this._lastClickPoint.y
        : nodeRect.bottom

    const desiredLeft =
      this.viewport.scrollLeft + (anchorX - viewportRect.left) - panelWidth / 2
    const minLeft = this.viewport.scrollLeft + 8
    const maxLeft = this.viewport.scrollLeft + Math.max(0, viewportWidth - panelWidth - 8)
    const nextLeft = Math.max(minLeft, Math.min(desiredLeft, maxLeft))

    // Measure panel height before clamping vertical position.
    panel.style.width = `${panelWidth}px`
    panel.style.left = `${nextLeft}px`
    panel.style.top = "0px"
    panel.style.visibility = "hidden"
    panel.style.display = "flex"
    const panelHeight = panel.offsetHeight || 0

    const viewportTop = this.viewport.scrollTop
    const viewportBottom = viewportTop + this.viewport.clientHeight
    const anchorTopInViewport =
      this.viewport.scrollTop + (anchorY - viewportRect.top)
    const nodeTopInViewport = this.viewport.scrollTop + (nodeRect.top - viewportRect.top)

    // Prefer below node, fallback to above node when it would be clipped.
    const preferredTop = anchorTopInViewport + padding
    const aboveTop = nodeTopInViewport - panelHeight - padding
    const fitsBelow = preferredTop + Math.min(panelHeight, this.viewport.clientHeight * 0.72) <= viewportBottom - 4
    const rawTop = fitsBelow ? preferredTop : aboveTop
    const minTop = viewportTop + 4
    const maxTop = Math.max(minTop, viewportBottom - panelHeight - 4)
    const nextTop = Math.max(minTop, Math.min(rawTop, maxTop))

    panel.style.left = `${nextLeft}px`
    panel.style.top = `${nextTop}px`
    panel.style.visibility = "visible"
    panel.style.display = "flex"
  },

  ensureInlineDetailVisible(selectedNode) {
    if (!this.viewport || !selectedNode) return

    const viewportRect = this.viewport.getBoundingClientRect()
    const nodeRect = selectedNode.getBoundingClientRect()
    const padding = 32

    let dx = 0
    let dy = 0

    if (nodeRect.left < viewportRect.left + padding) {
      dx = nodeRect.left - viewportRect.left - padding
    } else if (nodeRect.right > viewportRect.right - padding) {
      dx = nodeRect.right - viewportRect.right + padding
    }

    if (nodeRect.top < viewportRect.top + padding) {
      dy = nodeRect.top - viewportRect.top - padding
    } else if (nodeRect.bottom > viewportRect.bottom - padding) {
      dy = nodeRect.bottom - viewportRect.bottom + padding
    }

    if (dx === 0 && dy === 0) return

    this.viewport.scrollBy({
      left: dx,
      top: dy,
      behavior: "smooth",
    })
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

  laneOffset(index, count) {
    if (count <= 1) return 0
    return (index - (count - 1) / 2) * EDGE_LANE_STEP
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
    const edgePaths = [...svgEl.querySelectorAll("g.edgePaths path.flowchart-link, g.edgePaths path")]

    const edgeInfos = edgePaths
      .map((pathEl, domIndex) => {
        const ids = this.extractEdgeEndpointIds(pathEl)
        if (!ids) return null

        const src = nodeBoxes.get(ids.src)
        const dst = nodeBoxes.get(ids.dst)
        if (!src || !dst) return null

        const d = pathEl.getAttribute("d") || ""
        const matches = [...d.matchAll(coordRe)]
        if (matches.length < 2) return null

        const first = matches[0]
        const last = matches[matches.length - 1]

        return {
          pathEl,
          ids,
          src,
          dst,
          y1raw: Number(first[2]),
          y2raw: Number(last[2]),
          domIndex,
        }
      })
      .filter(Boolean)

    const outgoingGroups = new Map()
    edgeInfos.forEach((edge) => {
      const key = edge.ids.src
      const group = outgoingGroups.get(key) || []
      group.push(edge)
      outgoingGroups.set(key, group)
    })

    outgoingGroups.forEach((group) => {
      group
        .sort((a, b) => {
          const ay = (a.dst.top + a.dst.bottom) / 2
          const by = (b.dst.top + b.dst.bottom) / 2
          return ay - by || a.domIndex - b.domIndex
        })
        .forEach((edge, index) => {
          edge.laneIndex = index
          edge.laneCount = group.length
        })
    })

    edgeInfos.forEach((edge) => {
      const { pathEl, ids, src, dst, y1raw, y2raw } = edge

      const y1 = Math.max(src.top + 4, Math.min(y1raw, src.bottom - 4))
      const y2 = Math.max(dst.top + 4, Math.min(y2raw, dst.bottom - 4))
      const sx = src.right
      const tx = Number((dst.left - EDGE_TARGET_GAP).toFixed(3))
      const baseMidX = (sx + tx) / 2
      const laneOffset = this.laneOffset(edge.laneIndex || 0, edge.laneCount || 1)
      const minLaneX = sx + 20
      const maxLaneX = tx - 20
      const rawLaneX = baseMidX + laneOffset
      const midX =
        minLaneX < maxLaneX
          ? Number(Math.max(minLaneX, Math.min(rawLaneX, maxLaneX)).toFixed(3))
          : Number(rawLaneX.toFixed(3))

      pathEl.dataset.src = ids.src
      pathEl.dataset.dst = ids.dst
      pathEl.classList.add("scratch-flow-edge")

      if (ids.src === ids.dst) {
        const nodeHeight = Math.max(12, src.bottom - src.top)
        const loopLift = Math.max(16, Math.round(nodeHeight * 0.75))
        const loopOut = 36
        const topY = Number((src.top - loopLift).toFixed(3))
        const rightX = Number((sx + loopOut).toFixed(3))
        const centerY = Number(((src.top + src.bottom) / 2).toFixed(3))
        const innerX = Number((sx + 26).toFixed(3))
        const entryY = Number((src.top + Math.max(6, Math.round(nodeHeight * 0.28))).toFixed(3))
        const rebuilt = `M${sx},${centerY}L${rightX},${centerY}L${rightX},${topY}L${innerX},${topY}L${innerX},${entryY}L${sx},${entryY}`
        pathEl.setAttribute("d", rebuilt)
        return
      }

      // Always rebuild path so start/end anchors are deterministic.
      // Preserve near-straight look for same-row links.
      const rebuilt =
        Math.abs(y1 - y2) < 1
          ? `M${sx},${y1}L${tx},${y2}`
          : `M${sx},${y1}L${midX},${y1}L${midX},${y2}L${tx},${y2}`

      pathEl.setAttribute("d", rebuilt)
    })

    svgEl.setAttribute("data-anchor-patched", "1")
    svgEl.setAttribute("data-anchor-path-count", String(edgeInfos.length))
  },

  bindEdgeHover(svgEl) {
    const edgePaths = [...svgEl.querySelectorAll("path.scratch-flow-edge")]
    if (edgePaths.length === 0) return

    const clear = () => {
      edgePaths.forEach((pathEl) => {
        pathEl.classList.remove("scratch-flow-edge-highlight")
        pathEl.classList.remove("scratch-flow-edge-dim")
      })
    }

    svgEl.querySelectorAll("g.node[data-id]").forEach((nodeEl) => {
      const nodeId = nodeEl.getAttribute("data-id")
      if (!nodeId) return

      nodeEl.addEventListener("mouseenter", () => {
        edgePaths.forEach((pathEl) => {
          const connected = pathEl.dataset.src === nodeId || pathEl.dataset.dst === nodeId
          pathEl.classList.toggle("scratch-flow-edge-highlight", connected)
          pathEl.classList.toggle("scratch-flow-edge-dim", !connected)
        })
      })
      nodeEl.addEventListener("mouseleave", clear)
    })
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

  expandViewBoxToFitContent(svgEl) {
    const root = svgEl.querySelector("g.root")
    if (!root || typeof root.getBBox !== "function") return

    const box = root.getBBox()
    if (!Number.isFinite(box.x) || !Number.isFinite(box.y) || box.width <= 0 || box.height <= 0) return

    const pad = 12
    const vx = Math.floor(box.x - pad)
    const vy = Math.floor(box.y - pad)
    const vw = Math.ceil(box.width + pad * 2)
    const vh = Math.ceil(box.height + pad * 2)

    svgEl.setAttribute("viewBox", `${vx} ${vy} ${vw} ${vh}`)
    svgEl.setAttribute("width", String(vw))
    svgEl.setAttribute("height", String(vh))
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
        this.bindEdgeHover(svgEl)
        this.expandViewBoxToFitContent(svgEl)

        svgEl.style.maxWidth = "none"
        svgEl.style.width = "auto"
        svgEl.style.height = "auto"
        svgEl.style.display = "block"

        this._baseSize = this.measureBaseSize(svgEl)
        this.applyScale()
        this.syncSelectedNode()
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
