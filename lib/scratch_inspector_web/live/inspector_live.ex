defmodule ScratchInspectorWeb.InspectorLive do
  use ScratchInspectorWeb, :live_view
  alias ScratchInspectorWeb.FlowDetailViewModel
  alias ScratchInspectorWeb.Live.InspectorComponents.Assets, as: AssetsComponents
  alias ScratchInspectorWeb.Live.InspectorComponents.ScratchBlocks, as: ScratchBlocksComponents
  alias ScratchInspectorWeb.Live.InspectorComponents.Variables, as: VariablesComponents
  alias ScratchInspectorWeb.Live.InspectorEvents
  alias ScratchInspectorWeb.Live.InspectorFlow
  alias ScratchInspectorWeb.Live.InspectorUI

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Scratch Inspector")
      |> assign(:project, nil)
      |> assign(:active_tab, :flow)
      |> assign(:selected_sprite, nil)
      |> assign(:selected_target_type, nil)
      |> assign(:upload_error, nil)
      |> assign(:processing, false)
      |> assign(:show_sprite_code, false)
      |> assign(:flow_detail, nil)
      |> assign(:expanded_variable_key, nil)
      |> allow_upload(:scratch_file,
        accept: :any,
        max_entries: 1,
        max_file_size: 200_000_000,
        chunk_size: 512_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    InspectorEvents.handle(event, params, socket)
  end

  # ---- helpers ----

  defp current_target(project, name, _type) do
    cond do
      project.stage && project.stage.name == name -> project.stage
      true -> Enum.find(project.sprites, &(&1.name == name))
    end
  end

  

  # ---- render ----

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-[#4C97FF] shadow-sm">
        <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <span class="text-2xl">🐱</span>
            <h1 class="text-xl font-bold text-white tracking-tight">Scratch Inspector</h1>
          </div>
          
          <%= if @project do %>
            <div class="flex items-center gap-3">
              <span class="text-sm text-white/80 font-medium">{@project.name}</span>
              <button
                phx-click="reset"
                class="text-xs bg-white/20 hover:bg-white/30 text-white px-3 py-1 rounded-full transition"
              >
                別のファイルを開く
              </button>
            </div>
          <% end %>
        </div>
      </header>
      
    <!-- Upload area -->
      <%= if is_nil(@project) do %>
        <div class="flex items-center justify-center min-h-[calc(100vh-56px)]">
          <div class="w-full max-w-lg px-4">
            <form phx-submit="upload" phx-change="validate">
              <div
                class={[
                  "border-2 border-dashed rounded-2xl p-12 text-center transition-colors",
                  if(Enum.any?(@uploads.scratch_file.entries),
                    do: "border-[#4C97FF] bg-blue-50",
                    else: "border-gray-300 bg-white hover:border-[#4C97FF] hover:bg-blue-50/40"
                  )
                ]}
                phx-drop-target={@uploads.scratch_file.ref}
              >
                <%= if @processing do %>
                  <div class="text-5xl mb-4 animate-spin inline-block">⚙️</div>
                  
                  <p class="text-base font-semibold text-[#4C97FF]">解析中...</p>
                <% else %>
                  <div class="text-5xl mb-4">🗂️</div>
                  
                  <p class="text-lg font-semibold text-gray-700 mb-1">
                    Scratch ファイルをドロップ
                  </p>
                  
                  <p class="text-sm text-gray-400 mb-6">.sb / .sb2 / .sb3 に対応</p>
                  
                  <label class="cursor-pointer inline-block bg-[#4C97FF] hover:bg-[#3d87ef] text-white font-medium px-6 py-2.5 rounded-full transition">
                    ファイルを選択 <.live_file_input upload={@uploads.scratch_file} class="sr-only" />
                  </label>
                  
                  <%= for entry <- @uploads.scratch_file.entries do %>
                    <div class="mt-4 text-sm text-gray-600 flex items-center justify-center gap-2">
                      <span>📄</span> <span>{entry.client_name}</span>
                    </div>
                    
                    <div class="mt-2 w-full bg-gray-200 rounded-full h-2">
                      <div
                        class="bg-[#4C97FF] h-2 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}
                      />
                    </div>
                    
                    <%= if entry.done? do %>
                      <p class="mt-1 text-xs text-green-500">アップロード完了</p>
                    <% else %>
                      <p class="mt-1 text-xs text-gray-400">アップロード中... {entry.progress}%</p>
                    <% end %>
                  <% end %>
                  
                  <%= if Enum.any?(@uploads.scratch_file.entries, & &1.done?) do %>
                    <div class="mt-4">
                      <button
                        type="submit"
                        class="bg-[#4C97FF] hover:bg-[#3d87ef] text-white font-semibold px-8 py-2.5 rounded-full transition"
                      >
                        解析する
                      </button>
                    </div>
                  <% end %>
                <% end %>
              </div>
              
              <%= if @upload_error do %>
                <p class="mt-3 text-sm text-red-500 text-center">{@upload_error}</p>
              <% end %>
              
              <%= for err <- upload_errors(@uploads.scratch_file) do %>
                <p class="mt-3 text-sm text-red-500 text-center">{InspectorUI.upload_error_text(err)}</p>
              <% end %>
            </form>
          </div>
        </div>
        
    <!-- Main UI -->
      <% else %>
        <div class="h-[calc(100vh-56px)] flex flex-col overflow-hidden">
          <!-- Sprite thumbnail strip -->
          <div class="bg-white border-b border-gray-200 flex gap-1 px-3 py-2 overflow-x-auto flex-shrink-0">
            <%= if @project.stage do %>
              <button
                phx-click="select_sprite"
                phx-value-name={@project.stage.name}
                phx-value-type="stage"
                class={[
                  "flex flex-col items-center gap-0.5 px-2 py-1 rounded-lg min-w-[52px] transition flex-shrink-0",
                  if(@selected_sprite == @project.stage.name,
                    do: "bg-[#4C97FF]/10 ring-2 ring-[#4C97FF]",
                    else: "hover:bg-gray-100"
                  )
                ]}
              >
                <AssetsComponents.sprite_thumbnail sprite={@project.stage} />
                <span class="text-[10px] text-gray-600 truncate max-w-[48px]">背景</span>
              </button>
            <% end %>
            
            <%= for sprite <- @project.sprites do %>
              <button
                phx-click="select_sprite"
                phx-value-name={sprite.name}
                phx-value-type="sprite"
                class={[
                  "flex flex-col items-center gap-0.5 px-2 py-1 rounded-lg min-w-[52px] transition flex-shrink-0",
                  if(@selected_sprite == sprite.name,
                    do: "bg-[#4C97FF]/10 ring-2 ring-[#4C97FF]",
                    else: "hover:bg-gray-100"
                  )
                ]}
              >
                <AssetsComponents.sprite_thumbnail sprite={sprite} />
                <span class="text-[10px] text-gray-600 truncate max-w-[48px]">{sprite.name}</span>
              </button>
            <% end %>
          </div>
          
    <!-- Tabs -->
          <div class="bg-white border-b border-gray-200 px-4 flex gap-1 pt-2 flex-shrink-0">
            <%= for {tab, label, _icon} <- InspectorUI.tabs() do %>
              <button
                phx-click="select_tab"
                phx-value-tab={tab}
                class={[
                  "px-4 py-2 text-sm font-medium rounded-t-lg transition border-b-2",
                  if(@active_tab == tab,
                    do: "border-[#4C97FF] text-[#4C97FF]",
                    else: "border-transparent text-gray-500 hover:text-gray-700"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
          
    <!-- Tab content -->
          <div class="flex-1 overflow-y-auto p-6">
            <% target =
              if(@project && @selected_sprite,
                do: current_target(@project, @selected_sprite, @selected_target_type),
                else: nil
              ) %>
            <%= case @active_tab do %>
              <% :flow -> %>
                <.flow_graph_panel project={@project} target={target} flow_detail={@flow_detail} />
              <% :variables -> %>
                <VariablesComponents.variables_panel
                  project={@project}
                  target={target}
                  selected_target_type={@selected_target_type}
                  expanded_variable_key={@expanded_variable_key}
                />
              <% :costumes -> %>
                <AssetsComponents.costumes_panel target={target} />
              <% :sounds -> %>
                <AssetsComponents.sounds_panel target={target} />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ---- sub-components ----

  # ---- Flow Panel ----

  attr :project, :map, required: true
  attr :target, :map, default: nil
  attr :flow_detail, :map, default: nil

  defp flow_graph_panel(assigns) do
    detail = FlowDetailViewModel.build(assigns.project, assigns.target, assigns.flow_detail)

    assigns =
      assigns
      |> assign(:detail_script, detail.detail_script)
      |> assign(:detail_title, detail.detail_title)
      |> assign(:detail_receivers, detail.detail_receivers)
      |> assign(
        :graph_chart,
        InspectorFlow.build_flow_mermaid(assigns.project, assigns.target, assigns.flow_detail)
      )

    flow_graph_panel_content(assigns)
  end

  defp flow_graph_panel_content(assigns) do
    ~H"""
    <div>
      <%= if @target do %>
        <%= if is_nil(@graph_chart) do %>
          <AssetsComponents.empty_state
            icon=""
            message="このスプライトにはスクリプトがありません"
          />
        <% else %>
          <div class="mb-4 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
            <div class="mb-3 flex items-center justify-between gap-3">
              <div>
                <h2 class="text-sm font-semibold text-gray-800">Flow Graph</h2>
                
                <p class="text-xs text-gray-500">Click a node to inspect its detail below.</p>
              </div>
               <span class="text-xs text-gray-400">{AssetsComponents.display_name(@target)}</span>
            </div>
            
            <div
              id={"flow-chart-#{flow_dom_id(@target)}"}
              phx-hook="MermaidChart"
              data-chart={@graph_chart}
              class="rounded-lg bg-slate-50"
            >
              <div class="flex items-center justify-between gap-3 border-b border-slate-200 px-3 py-2">
                <div class="flex items-center gap-2">
                  <button
                    type="button"
                    data-zoom-action="out"
                    class="inline-flex h-8 w-8 items-center justify-center rounded-md border border-slate-300 bg-white text-sm font-semibold text-slate-600 transition hover:border-slate-400 hover:text-slate-800"
                    aria-label="Zoom out"
                  >
                    -
                  </button>
                  
                  <button
                    type="button"
                    data-zoom-action="in"
                    class="inline-flex h-8 w-8 items-center justify-center rounded-md border border-slate-300 bg-white text-sm font-semibold text-slate-600 transition hover:border-slate-400 hover:text-slate-800"
                    aria-label="Zoom in"
                  >
                    +
                  </button>
                  
                  <button
                    type="button"
                    data-zoom-action="reset"
                    class="inline-flex h-8 items-center justify-center rounded-md border border-slate-300 bg-white px-2 text-xs font-medium text-slate-600 transition hover:border-slate-400 hover:text-slate-800"
                  >
                    100%
                  </button>
                </div>
                 <span data-zoom-label class="text-xs font-medium text-slate-500">100%</span>
              </div>
               <div data-role="viewport" class="min-h-[360px] overflow-auto px-2 py-4" />
            </div>
          </div>
        <% end %>
        
        <%= if @flow_detail && (@detail_script != nil || @detail_receivers != nil) do %>
          <div class="relative border border-gray-200 rounded-xl overflow-hidden bg-white">
            <div class="absolute right-3 top-3 z-10">
              <button
                phx-click="flow_select_detail"
                phx-value-kind={@flow_detail.kind}
                phx-value-id={@flow_detail.id}
                phx-value-sprite={@flow_detail.sprite}
                phx-value-type={@flow_detail.type}
                class="text-gray-400 hover:text-gray-600 text-lg leading-none"
              >
                ✕
              </button>
            </div>
            
            <div class="p-4 bg-gray-50">
              <%= if @detail_script do %>
                <%= if detail_blocks_present?(@detail_script) do %>
                  <ScratchBlocksComponents.scratch_script_detail detail={@detail_script} />
                <% else %>
                  <p class="text-xs text-gray-400 italic">ブロックなし</p>
                <% end %>
              <% else %>
                <%= if Enum.any?(@detail_receivers) do %>
                  <div class="space-y-2">
                    <%= for receiver <- @detail_receivers do %>
                      <button
                        phx-click="flow_select_detail"
                        phx-value-kind={receiver.detail.kind}
                        phx-value-id={receiver.detail.id}
                        phx-value-sprite={receiver.detail.sprite}
                        phx-value-type={receiver.detail.type}
                        class="flex items-center gap-3 w-full bg-white rounded-lg border border-gray-200 px-3 py-2 hover:bg-blue-50 hover:border-blue-200 transition text-left"
                      >
                        <AssetsComponents.sprite_thumbnail sprite={receiver.target} />
                        <span class="text-xs font-medium text-gray-700">{AssetsComponents.display_name(receiver.target)}</span>
                        <span class="text-xs text-gray-400">-></span>
                        <span class="text-xs text-gray-600">{receiver.script.hat_label}</span>
                      </button>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-xs text-gray-400 italic">このメッセージを受け取るスプライトはありません</p>
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <AssetsComponents.empty_state
          icon=""
          message="上のサムネイルからスプライトを選択してください"
        />
      <% end %>
    </div>
    """
  end

  

  defp flow_dom_id(target) do
    target
    |> AssetsComponents.display_name()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
  end

  defp detail_blocks_present?(%{header: header, blocks: blocks}),
    do: not is_nil(header) or Enum.any?(blocks || [])

  defp detail_blocks_present?(_), do: false
end
