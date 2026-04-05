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

// グローバルクリックハンドラ: Mermaid の click ディレクティブから呼ばれる
// payload は Base64URL エンコードされた "スプライト名__関数名"
window.__mermaidNodeClick = function (arg1, arg2) {
  if (!window.__mermaidLiveHook) return

  const payload = typeof arg2 === "string" ? arg2 : typeof arg1 === "string" ? arg1 : null
  if (!payload) return
  try {
    // Base64URL → 通常 Base64 → decode
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
    window.__mermaidLiveHook = this
    this.renderDiagram()
  },

  updated() {
    const chartDef = this.el.getAttribute("data-chart")
    if (chartDef !== this._lastChart) {
      this.renderDiagram()
    }
  },

  destroyed() {
    if (window.__mermaidLiveHook === this) {
      window.__mermaidLiveHook = null
    }
  },

  async renderDiagram() {
    const chartDef = this.el.getAttribute("data-chart")
    if (!chartDef || chartDef === "") return
    this._lastChart = chartDef

    this.el.innerHTML = ""

    const id = `mermaid-diagram-${diagramCounter++}`

    try {
      const { svg, bindFunctions } = await mermaid.render(id, chartDef)
      this.el.innerHTML = svg
      if (bindFunctions) bindFunctions(this.el)

      // SVG をレスポンシブにする
      const svgEl = this.el.querySelector("svg")
      if (svgEl) {
        svgEl.style.maxWidth = "none"
        svgEl.style.width = "max-content"
        svgEl.style.height = "max-content"
        svgEl.style.display = "block"
      }
    } catch (e) {
      console.error("Mermaid render error:", e)
      this.el.innerHTML =
        `<p style="color: #ef4444; font-size: 0.75rem; padding: 8px;">ダイアグラムの描画に失敗しました</p>`
    }
  },
}
