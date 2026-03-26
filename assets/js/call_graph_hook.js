import {
  Workspace,
  Container,
  Connector,
  Edge,
  Position,
  SvgRenderer,
  InteractionManager,
  bindWheelZoom
} from "headless-vpl"

// Simple hierarchical layout for DAGs
function layoutGraph(nodes, edges) {
  const outgoing = {}
  const incoming = {}
  nodes.forEach(n => {
    outgoing[n.id] = []
    incoming[n.id] = []
  })
  edges.forEach(e => {
    if (outgoing[e.from]) outgoing[e.from].push(e.to)
    if (incoming[e.to]) incoming[e.to].push(e.from)
  })

  // Assign layers via BFS
  const layers = {}
  const visited = new Set()
  const roots = nodes.filter(n => incoming[n.id].length === 0)
  if (roots.length === 0 && nodes.length > 0) {
    roots.push(nodes[0])
  }

  const queue = roots.map(r => ({ id: r.id, layer: 0 }))
  while (queue.length > 0) {
    const { id, layer } = queue.shift()
    if (visited.has(id)) {
      layers[id] = Math.max(layers[id] || 0, layer)
      continue
    }
    visited.add(id)
    layers[id] = layer
    for (const child of (outgoing[id] || [])) {
      queue.push({ id: child, layer: layer + 1 })
    }
  }
  nodes.forEach(n => {
    if (!(n.id in layers)) layers[n.id] = 0
  })

  // Group by layer
  const layerGroups = {}
  for (const [id, layer] of Object.entries(layers)) {
    if (!layerGroups[layer]) layerGroups[layer] = []
    layerGroups[layer].push(id)
  }

  const NODE_W = 200
  const NODE_H = 64
  const H_GAP = 50
  const V_GAP = 80
  const positions = {}

  const sortedLayers = Object.keys(layerGroups).map(Number).sort((a, b) => a - b)
  const maxNodesInLayer = Math.max(...sortedLayers.map(l => layerGroups[l].length))
  const totalWidth = maxNodesInLayer * (NODE_W + H_GAP)

  for (const layer of sortedLayers) {
    const group = layerGroups[layer]
    const layerWidth = group.length * (NODE_W + H_GAP) - H_GAP
    const startX = (totalWidth - layerWidth) / 2 + 40
    const y = layer * (NODE_H + V_GAP) + 40

    group.forEach((id, idx) => {
      positions[id] = { x: startX + idx * (NODE_W + H_GAP), y }
    })
  }

  return { positions, NODE_W, NODE_H, totalWidth, totalHeight: (sortedLayers.length) * (NODE_H + V_GAP) + 40 }
}

// Sprite color palette
const SPRITE_COLORS = [
  "#4C97FF", "#9966FF", "#CF63CF", "#FFAB19",
  "#FF6680", "#40BF4A", "#4CBFE6", "#FF8C1A"
]

function spriteColor(spriteName, spriteNames) {
  const idx = spriteNames.indexOf(spriteName)
  return SPRITE_COLORS[idx % SPRITE_COLORS.length]
}

function escapeHtml(str) {
  const div = document.createElement("div")
  div.textContent = str
  return div.innerHTML
}

export const CallGraphHook = {
  mounted() {
    this.renderGraph()
  },

  updated() {
    // phx-update="ignore" prevents re-render, but we handle manual updates
  },

  destroyed() {
    if (this._animFrame) cancelAnimationFrame(this._animFrame)
  },

  renderGraph() {
    if (this._animFrame) cancelAnimationFrame(this._animFrame)

    const dataAttr = this.el.getAttribute("data-graph")
    if (!dataAttr || dataAttr === "null") return

    let graphData
    try {
      graphData = JSON.parse(dataAttr)
    } catch (e) {
      console.error("Failed to parse graph data:", e)
      return
    }

    const { nodes, edges: edgeData, sprites: spriteNames } = graphData
    if (!nodes || nodes.length === 0) {
      this.el.innerHTML = '<p class="text-gray-400 text-sm text-center py-8">関数が見つかりません</p>'
      return
    }

    // Clear
    this.el.innerHTML = ""

    // Create SVG
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.style.width = "100%"
    svg.style.height = "100%"
    this.el.appendChild(svg)

    // Workspace + renderer
    const workspace = new Workspace()
    const renderer = new SvgRenderer(workspace, svg)

    // Layout
    const { positions, NODE_W, NODE_H, totalWidth, totalHeight } = layoutGraph(nodes, edgeData)

    // Create containers
    const containerMap = {}
    for (const node of nodes) {
      const pos = positions[node.id]
      const container = new Container(workspace, new Position(pos.x, pos.y), {
        width: NODE_W,
        height: NODE_H
      })
      containerMap[node.id] = container

      // Connectors: output at bottom, input at top
      new Connector(container, new Position(NODE_W / 2, NODE_H), {
        type: "output",
        direction: "south"
      })
      new Connector(container, new Position(NODE_W / 2, 0), {
        type: "input",
        direction: "north"
      })
    }

    // Create edges
    for (const e of edgeData) {
      const fromC = containerMap[e.from]
      const toC = containerMap[e.to]
      if (!fromC || !toC) continue

      const fromConn = fromC.children.find(c => c.type === "output")
      const toConn = toC.children.find(c => c.type === "input")
      if (!fromConn || !toConn) continue

      new Edge(workspace, fromConn, toConn, { pathType: "bezier" })
    }

    // Interactions
    try {
      new InteractionManager(workspace, svg)
    } catch (e) {
      // Fallback: just wheel zoom
      try { bindWheelZoom(workspace, svg) } catch (_) {}
    }

    // Create DOM overlay for labels
    const overlay = document.createElement("div")
    overlay.style.position = "absolute"
    overlay.style.top = "0"
    overlay.style.left = "0"
    overlay.style.width = "100%"
    overlay.style.height = "100%"
    overlay.style.pointerEvents = "none"
    overlay.style.overflow = "hidden"
    this.el.style.position = "relative"
    this.el.appendChild(overlay)

    // Render loop
    const renderLoop = () => {
      renderer.render()
      this.updateLabels(overlay, svg, workspace, nodes, containerMap, spriteNames, NODE_W, NODE_H)
      this._animFrame = requestAnimationFrame(renderLoop)
    }
    this._animFrame = requestAnimationFrame(renderLoop)
  },

  updateLabels(overlay, svg, workspace, nodes, containerMap, spriteNames, NODE_W, NODE_H) {
    overlay.innerHTML = ""

    for (const node of nodes) {
      const container = containerMap[node.id]
      if (!container) continue

      const pos = container.position
      const zoom = workspace.zoom ?? 1
      const panX = workspace.pan?.x ?? 0
      const panY = workspace.pan?.y ?? 0
      const sx = pos.x * zoom + panX
      const sy = pos.y * zoom + panY
      const sw = NODE_W * zoom
      const sh = NODE_H * zoom

      const color = spriteColor(node.sprite, spriteNames)

      const label = document.createElement("div")
      label.style.cssText = `
        position:absolute; left:${sx}px; top:${sy}px; width:${sw}px; height:${sh}px;
        display:flex; flex-direction:column; align-items:center; justify-content:center;
        pointer-events:none; overflow:hidden;
      `
      label.innerHTML = `
        <div style="font-size:${Math.max(8, 10 * zoom)}px;color:${color};font-weight:600;opacity:0.8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%;padding:0 6px;">
          ${escapeHtml(node.sprite)}
        </div>
        <div style="font-size:${Math.max(10, 12 * zoom)}px;font-family:ui-monospace,monospace;font-weight:700;color:#1e293b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%;padding:0 6px;">
          ${escapeHtml(node.label)}
        </div>
        <div style="font-size:${Math.max(8, 9 * zoom)}px;color:#94a3b8;">
          ${node.callCount} 呼び出し
        </div>
      `
      overlay.appendChild(label)
    }
  }
}
