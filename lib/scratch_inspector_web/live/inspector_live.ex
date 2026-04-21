defmodule ScratchInspectorWeb.InspectorLive do
  use ScratchInspectorWeb, :live_view
  alias ScratchInspectorWeb.FlowDetailViewModel
  alias ScratchInspectorWeb.Live.BlockLabelItems

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
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, :upload_error, nil)}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    do_process_upload(socket)
  end

  @impl true
  def handle_event("select_sprite", %{"name" => name, "type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:selected_sprite, name)
     |> assign(:selected_target_type, type)
     |> assign(:show_sprite_code, false)
     |> assign(:flow_detail, nil)
     |> assign(:expanded_variable_key, nil)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("toggle_sprite_code", _params, socket) do
    {:noreply, assign(socket, :show_sprite_code, !socket.assigns.show_sprite_code)}
  end

  @impl true
  def handle_event("flow_select_detail", %{"kind" => kind, "id" => id} = params, socket) do
    target_sprite = Map.get(params, "sprite")
    target_type = Map.get(params, "type")

    socket =
      case {target_sprite, target_type} do
        {sprite, type} when is_binary(sprite) and is_binary(type) ->
          socket
          |> assign(:selected_sprite, sprite)
          |> assign(:selected_target_type, type)

        _ ->
          socket
      end

    current = normalize_flow_detail(socket.assigns.flow_detail)
    next_detail = normalize_flow_detail(%{kind: kind, id: id, sprite: target_sprite, type: target_type})

    next =
      if flow_detail_same?(current, next_detail),
        do: nil,
        else: next_detail

    {:noreply, assign(socket, :flow_detail, next)}
  end

  @impl true
  def handle_event("toggle_variable_detail", %{"key" => key}, socket) do
    next = if socket.assigns.expanded_variable_key == key, do: nil, else: key
    {:noreply, assign(socket, :expanded_variable_key, next)}
  end

  @impl true
  def handle_event("jump_to_variable_usage", params, socket) do
    {:noreply,
     socket
     |> assign(:selected_sprite, params["sprite"])
     |> assign(:selected_target_type, params["type"])
     |> assign(:active_tab, :flow)
     |> assign(
       :flow_detail,
       normalize_flow_detail(%{
         kind: params["detail-kind"],
         id: params["detail-id"],
         sprite: params["sprite"],
         type: params["type"]
       })
     )}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:project, nil)
     |> assign(:selected_sprite, nil)
     |> assign(:selected_target_type, nil)
     |> assign(:upload_error, nil)
     |> assign(:active_tab, :flow)
     |> assign(:processing, false)
     |> assign(:show_sprite_code, false)
     |> assign(:flow_detail, nil)
     |> assign(:expanded_variable_key, nil)}
  end

  defp do_process_upload(socket) do
    result =
      consume_uploaded_entries(socket, :scratch_file, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name) |> String.downcase()

        parse_result =
          try do
            ScratchInspector.Parser.parse(path, ext)
          rescue
            e -> {:error, "パース中にエラー: #{Exception.message(e)}"}
          end

        {:ok, {parse_result, entry.client_name}}
      end)

    case result do
      [{parse_result, name} | _] ->
        case parse_result do
          {:ok, project} ->
            # デフォルトでステージを選択
            {:noreply,
             socket
             |> assign(:project, Map.put(project, :name, name))
             |> assign(:selected_sprite, if(project.stage, do: project.stage.name, else: nil))
             |> assign(:selected_target_type, if(project.stage, do: "stage", else: nil))
             |> assign(:upload_error, nil)
             |> assign(:processing, false)
             |> assign(:expanded_variable_key, nil)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:upload_error, reason)
             |> assign(:processing, false)}
        end

      [] ->
        {:noreply, assign(socket, :upload_error, "アップロードが完了していません。しばらく待ってから再試行してください。")}
    end
  end

  # ---- helpers ----

  defp current_target(project, name, _type) do
    cond do
      project.stage && project.stage.name == name -> project.stage
      true -> Enum.find(project.sprites, &(&1.name == name))
    end
  end

  defp normalize_flow_detail(nil), do: nil

  defp normalize_flow_detail(detail) when is_map(detail) do
    %{
      kind: Map.get(detail, :kind) || Map.get(detail, "kind"),
      id: Map.get(detail, :id) || Map.get(detail, "id"),
      sprite: Map.get(detail, :sprite) || Map.get(detail, "sprite"),
      type: Map.get(detail, :type) || Map.get(detail, "type")
    }
    |> then(fn normalized ->
      if is_binary(normalized.kind) and is_binary(normalized.id), do: normalized, else: nil
    end)
  end

  defp normalize_flow_detail(_), do: nil

  defp flow_detail_same?(nil, nil), do: true

  defp flow_detail_same?(left, right) when is_map(left) and is_map(right) do
    left.kind == right.kind and left.id == right.id and left.sprite == right.sprite and
      left.type == right.type
  end

  defp flow_detail_same?(_, _), do: false

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
                <p class="mt-3 text-sm text-red-500 text-center">{upload_error_text(err)}</p>
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
                <.sprite_thumbnail sprite={@project.stage} />
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
                <.sprite_thumbnail sprite={sprite} />
                <span class="text-[10px] text-gray-600 truncate max-w-[48px]">{sprite.name}</span>
              </button>
            <% end %>
          </div>
          
    <!-- Tabs -->
          <div class="bg-white border-b border-gray-200 px-4 flex gap-1 pt-2 flex-shrink-0">
            <%= for {tab, label, _icon} <- tabs() do %>
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
                <.variables_panel
                  project={@project}
                  target={target}
                  selected_target_type={@selected_target_type}
                  expanded_variable_key={@expanded_variable_key}
                />
              <% :costumes -> %>
                <.costumes_panel target={target} />
              <% :sounds -> %>
                <.sounds_panel target={target} />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ---- sub-components ----

  defp tabs,
    do: [
      {:flow, "フロー", ""},
      {:variables, "変数", ""},
      {:costumes, "コスチューム", ""},
      {:sounds, "サウンド", ""}
    ]

  defp upload_error_text(:too_large), do: "ファイルが大きすぎます（最大 50MB）"
  defp upload_error_text(:not_accepted), do: "対応していないファイル形式です"
  defp upload_error_text(:too_many_files), do: "ファイルは1つだけ選択してください"
  defp upload_error_text(_), do: "アップロードエラーが発生しました"

  # ---- Flow Panel ----

  defp blocks_called_by_script(custom_blocks, hat_label) do
    Enum.filter(custom_blocks, fn cb ->
      Enum.any?(cb.called_by, &(&1 == hat_label))
    end)
  end

  defp find_broadcast_receivers(project, msg) do
    all_targets = Enum.filter([project.stage | project.sprites], & &1)

    Enum.flat_map(all_targets, fn target ->
      target.top_scripts
      |> Enum.filter(fn s ->
        s.hat_opcode == "event_whenbroadcastreceived" &&
          script_receives_broadcast?(s.hat_label, msg)
      end)
      |> Enum.map(fn s -> {target, s} end)
    end)
  end

  defp broadcasts_sent_in_script(blocks) do
    blocks
    |> Enum.filter(fn b -> b.opcode in ["event_broadcast", "event_broadcastandwait"] end)
    |> Enum.flat_map(fn b -> b.params end)
    |> Enum.uniq()
  end

  defp script_receives_broadcast?(hat_label, msg)
       when is_binary(hat_label) and is_binary(msg) and msg != "" do
    String.contains?(hat_label, msg)
  end

  defp script_receives_broadcast?(_, _), do: false

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
        build_flow_mermaid(assigns.project, assigns.target, assigns.flow_detail)
      )

    flow_graph_panel_content(assigns)
  end

  defp flow_graph_panel_content(assigns) do
    ~H"""
    <div>
      <%= if @target do %>
        <%= if is_nil(@graph_chart) do %>
          <.empty_state
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
               <span class="text-xs text-gray-400">{display_name(@target)}</span>
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
          <div class="border border-gray-200 rounded-xl overflow-hidden bg-white">
            <div class="flex items-center justify-between px-4 py-2 bg-gray-50 border-b border-gray-200">
              <span class="text-sm font-semibold text-gray-700">{@detail_title}</span>
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
                  <.scratch_script_detail detail={@detail_script} />
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
                        <.sprite_thumbnail sprite={receiver.target} />
                        <span class="text-xs font-medium text-gray-700">{display_name(receiver.target)}</span>
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
        <.empty_state
          icon=""
          message="上のサムネイルからスプライトを選択してください"
        />
      <% end %>
    </div>
    """
  end

  defp build_flow_mermaid(_project, nil, _flow_detail), do: nil

  defp build_flow_mermaid(project, target, flow_detail) do
    scripts =
      target.top_scripts
      |> Enum.filter(&event_hat?(&1.hat_opcode))

    if Enum.empty?(scripts) do
      nil
    else
      custom_blocks = target.custom_blocks

      script_nodes =
        scripts
        |> Enum.with_index(1)
        |> Enum.map(fn {script, idx} ->
          %{
            id: "script_#{idx}",
            detail: flow_detail_payload(%{kind: "script", id: script.id}, target),
            label: script.hat_label,
            class: :script,
            script: script
          }
        end)

      script_node_ids = Map.new(script_nodes, fn node -> {node.script.id, node.id} end)

      block_nodes =
        custom_blocks
        |> Enum.with_index(1)
        |> Enum.map(fn {block_def, idx} ->
          %{
            id: "block_#{idx}",
            detail: flow_detail_payload(%{kind: "block_def", id: block_def.name}, target),
            label: block_def.name,
            class: :block_def,
            block_def: block_def
          }
        end)

      block_node_ids = Map.new(block_nodes, fn node -> {node.block_def.name, node.id} end)

      broadcast_messages =
        ((scripts |> Enum.flat_map(&broadcasts_sent_in_script(&1.blocks))) ++
           (custom_blocks |> Enum.flat_map(&broadcasts_sent_in_script(&1.code_blocks))))
        |> Enum.uniq()

      broadcast_nodes =
        broadcast_messages
        |> Enum.with_index(1)
        |> Enum.map(fn {msg, idx} ->
          %{
            id: "broadcast_#{idx}",
            detail: flow_detail_payload(%{kind: "broadcast", id: msg}, target),
            label: msg,
            class: :broadcast,
            message: msg
          }
        end)

      broadcast_node_ids = Map.new(broadcast_nodes, fn node -> {node.message, node.id} end)

      {receiver_nodes, receiver_node_ids} =
        broadcast_messages
        |> Enum.flat_map(&find_broadcast_receivers(project, &1))
        |> Enum.uniq_by(fn {receiver_target, script} ->
          {receiver_target.name, receiver_target.is_stage, script.id}
        end)
        |> Enum.with_index(1)
        |> Enum.map_reduce(%{}, fn {{receiver_target, script}, idx}, acc ->
          current_target? =
            receiver_target.name == target.name &&
              Map.get(receiver_target, :is_stage, false) == Map.get(target, :is_stage, false)

          node_id =
            if current_target? do
              Map.fetch!(script_node_ids, script.id)
            else
              "receiver_#{idx}"
            end

          node =
            if current_target? do
              nil
            else
              %{
                id: node_id,
                detail: flow_detail_payload(%{kind: "script", id: script.id}, receiver_target),
                label: "#{display_name(receiver_target)}<br/>#{script.hat_label}",
                class: :receiver_script
              }
            end

          key = {receiver_target.name, receiver_target.is_stage, script.id}
          {node, Map.put(acc, key, node_id)}
        end)

      script_edges =
        Enum.flat_map(script_nodes, fn node ->
          called_edges =
            blocks_called_by_script(custom_blocks, node.script.id)
            |> Enum.map(fn block_def -> {node.id, Map.get(block_node_ids, block_def.name)} end)

          broadcast_edges =
            broadcasts_sent_in_script(node.script.blocks)
            |> Enum.map(fn msg -> {node.id, Map.get(broadcast_node_ids, msg)} end)

          called_edges ++ broadcast_edges
        end)

      block_edges =
        Enum.flat_map(block_nodes, fn node ->
          call_edges =
            direct_calls_from_block_def(node.block_def, custom_blocks)
            |> Enum.map(fn sub_cb -> {node.id, Map.get(block_node_ids, sub_cb.name)} end)

          broadcast_edges =
            broadcasts_sent_in_script(node.block_def.code_blocks)
            |> Enum.map(fn msg -> {node.id, Map.get(broadcast_node_ids, msg)} end)

          call_edges ++ broadcast_edges
        end)

      receiver_edges =
        Enum.flat_map(broadcast_messages, fn msg ->
          from_id = Map.get(broadcast_node_ids, msg)

          find_broadcast_receivers(project, msg)
          |> Enum.map(fn {receiver_target, script} ->
            to_id =
              Map.get(
                receiver_node_ids,
                {receiver_target.name, receiver_target.is_stage, script.id}
              )

            {from_id, to_id}
          end)
        end)

      nodes =
        script_nodes ++ block_nodes ++ broadcast_nodes ++ Enum.reject(receiver_nodes, &is_nil/1)

      edges =
        (script_edges ++ block_edges ++ receiver_edges)
        |> Enum.reject(fn {from_id, to_id} -> is_nil(from_id) or is_nil(to_id) end)
        |> Enum.uniq()

      render_flow_mermaid(nodes, edges, flow_detail)
    end
  end

  defp direct_calls_from_block_def(cb, all_custom_blocks) do
    cb.code_blocks
    |> Enum.filter(fn b -> b.opcode == "procedures_call" end)
    |> Enum.map(fn b -> String.replace_prefix(b.label, "📞 ", "") end)
    |> Enum.uniq()
    |> Enum.map(fn name -> Enum.find(all_custom_blocks, &(&1.name == name)) end)
    |> Enum.reject(&is_nil/1)
  end

  defp render_flow_mermaid(nodes, edges, flow_detail) do
    header = [
      "flowchart TD",
      "classDef scriptNode fill:#FFAB19,stroke:#CC8813,color:#ffffff,stroke-width:2px;",
      "classDef blockNode fill:#FF6680,stroke:#D64C68,color:#ffffff,stroke-width:2px;",
      "classDef broadcastNode fill:#FFAB19,stroke:#CC8813,color:#ffffff,stroke-width:2px,stroke-dasharray: 6 3;",
      "classDef receiverNode fill:#ffffff,stroke:#4C97FF,color:#1f2937,stroke-width:2px;",
      "classDef selectedNode stroke:#2563EB,stroke-width:4px;"
    ]

    body =
      Enum.flat_map(nodes, fn node ->
        selected? = selected_flow_node?(flow_detail, node.detail)
        payload = mermaid_payload(node.detail)

        [
          ~s(#{node.id}["#{escape_mermaid_label(node.label)}"]),
          "class #{node.id} #{mermaid_class(node.class)};"
        ] ++
          if(selected?, do: ["class #{node.id} selectedNode;"], else: []) ++
          ["click #{node.id} call __mermaidNodeClick(\"#{payload}\")"]
      end)

    edge_lines = Enum.map(edges, fn {from_id, to_id} -> "#{from_id} --> #{to_id}" end)

    Enum.join(header ++ body ++ edge_lines, "\n")
  end

  defp selected_flow_node?(nil, _detail), do: false
  defp selected_flow_node?(current, detail),
    do: flow_detail_same?(normalize_flow_detail(current), normalize_flow_detail(detail))

  defp flow_detail_payload(detail, target) do
    normalize_flow_detail(%{
      kind: detail.kind,
      id: detail.id,
      sprite: target.name,
      type: target_type(target)
    })
  end

  defp target_type(%{is_stage: true}), do: "stage"
  defp target_type(_), do: "sprite"

  defp mermaid_payload(detail) do
    detail
    |> Enum.into(%{})
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp escape_mermaid_label(label) do
    label
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("&lt;br/&gt;", "<br/>")
    |> String.replace("\n", "<br/>")
  end

  defp mermaid_class(:script), do: "scriptNode"
  defp mermaid_class(:block_def), do: "blockNode"
  defp mermaid_class(:broadcast), do: "broadcastNode"
  defp mermaid_class(:receiver_script), do: "receiverNode"

  defp flow_dom_id(target) do
    target
    |> display_name()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
  end

  defp detail_blocks_present?(%{header: header, blocks: blocks}),
    do: not is_nil(header) or Enum.any?(blocks || [])

  defp detail_blocks_present?(_), do: false

  attr :detail, :map, required: true

  defp scratch_script_detail(assigns) do
    assigns =
      assigns
      |> assign(:header_block, assigns.detail.header)
      |> assign(:blocks, assigns.detail.blocks || [])
      |> assign(:custom_args, custom_block_arguments(assigns.detail))
      |> assign(:custom_signature, custom_block_signature(assigns.detail))
      |> assign(:header_field_count, length((assigns.detail.header || %{})[:fields] || []))
      |> assign(:header_input_count, length((assigns.detail.header || %{})[:inputs] || []))

    ~H"""
    <div class="scratch-detail-panel">
      <div class="min-w-full w-max">
        <%= if @detail.kind == :custom_block and custom_block_metadata_present?(@custom_args, @header_field_count, @header_input_count) do %>
          <div class="mb-3 rounded-2xl border border-pink-200/70 bg-pink-50/80 px-3 py-2 text-xs text-pink-900 shadow-sm">
            <p class="font-semibold">Custom block definition</p>
            <p class="mt-1 font-mono text-[11px] text-pink-800">{@custom_signature}</p>
            <p class="mt-1 text-pink-700">
              {length(@custom_args)} args, {@header_field_count} header fields, {@header_input_count} header inputs
            </p>
            <%= if Enum.any?(@custom_args) do %>
              <div class="mt-2 flex flex-wrap gap-1.5">
                <%= for arg <- @custom_args do %>
                  <span class="inline-flex items-center rounded-full border border-pink-300 bg-white px-2 py-0.5 text-[11px] text-pink-800">
                    {arg.name}
                    <%= if is_binary(arg.default) and arg.default != "" do %>
                      <span class="ml-1 text-pink-500">= {arg.default}</span>
                    <% end %>
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
        <%= if @header_block do %>
          <.scratch_block block={@header_block} />
        <% end %>
        <div class="scratch-block-stack-wrapper">
          <.scratch_stack blocks={@blocks} />
        </div>
      </div>
    </div>
    """
  end

  attr :blocks, :list, required: true

  defp scratch_stack(assigns) do
    ~H"""
    <div class="scratch-block-stack">
      <%= for block <- @blocks do %>
        <.scratch_block block={block} />
      <% end %>
    </div>
    """
  end

  defp custom_block_metadata_present?(custom_args, header_field_count, header_input_count) do
    Enum.any?(custom_args) or header_field_count > 0 or header_input_count > 0
  end

  attr :block, :map, required: true

  defp scratch_block(assigns) do
    assigns =
      assigns
      |> assign(:category_class, scratch_category_class(assigns.block.category))
      |> assign(:shape_class, scratch_shape_class(assigns.block.shape))
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))
      |> assign(:child_container_class, scratch_child_container_class(assigns.block.shape))
      |> assign(:c_block?, assigns.block.shape == :c_block)
      |> assign(:c_block_join_class, c_block_join_class(assigns.block))

    ~H"""
    <div class="flex flex-col items-start w-full min-w-0">
      <div class={[
        "scratch-block",
        @category_class,
        @shape_class,
        @c_block_join_class
      ]}>
        <%= for item <- @items do %>
          <.scratch_block_item item={item} />
        <% end %>
      </div>

      <%= if Enum.any?(@block.children || []) do %>
        <%= if @c_block? do %>
          <div class="scratch-c-block-frame">
            <div
              class="scratch-c-block-scope"
              style={"--c-block-accent: #{scratch_category_hex(assigns.block.category)}"}
            >
              <%= for child <- @block.children do %>
                <div class="mb-2 last:mb-0">
                  <%= if child_name = scratch_child_name(child.name) do %>
                    <div class="scratch-block-child-label">
                      {child_name}
                    </div>
                  <% end %>
                  <.scratch_stack blocks={child.blocks} />
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class={@child_container_class}>
            <%= for child <- @block.children do %>
              <div class="mb-2 last:mb-0">
                <%= if child_name = scratch_child_name(child.name) do %>
                  <div class="scratch-block-child-label">
                    {child_name}
                  </div>
                <% end %>
                <div class="scratch-block-child-inner">
                  <.scratch_stack blocks={child.blocks} />
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :item, :map, required: true

  defp scratch_block_item(assigns) do
    assigns = assign(assigns, :item_class, scratch_block_item_class(assigns.item))

    ~H"""
    <%= case @item.kind do %>
      <% :label -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :definition_name -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :field -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :input when is_map(@item.value) and @item.value.kind == :block -> %>
        <%= if inline_block_without_slot_wrapper?(@item) do %>
          <.scratch_inline_block block={@item.value.block} />
        <% else %>
          <span class={@item_class}>
            <.scratch_inline_block block={@item.value.block} />
          </span>
        <% end %>
      <% :input -> %>
        <span class={@item_class}>
          {scratch_input_text(@item.value)}
        </span>
    <% end %>
    """
  end

  attr :block, :map, required: true

  defp scratch_inline_block(assigns) do
    assigns =
      assigns
      |> assign(:category_class, scratch_category_class(assigns.block.category))
      |> assign(:shape_class, inline_shape_class(assigns.block.shape))
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))

    ~H"""
    <span class={[
      "scratch-inline-block",
      @category_class,
      @shape_class
    ]}>
      <%= for item <- @items do %>
        <.scratch_block_item item={item} />
      <% end %>
    </span>
    """
  end

  defp scratch_block_item_class(%{kind: :label}), do: "scratch-block-item-label"
  defp scratch_block_item_class(%{kind: :definition_name}), do: "scratch-block-item-definition-name"
  defp scratch_block_item_class(%{kind: :field}), do: "scratch-block-item-field"
  defp scratch_block_item_class(%{kind: :input, value: %{kind: :block}, slot: slot}),
    do: scratch_slot_class(slot, :block)

  defp scratch_block_item_class(%{kind: :input, slot: slot, value: value}) do
    [scratch_slot_class(slot, :literal), scratch_input_semantic_class(value), scratch_slot_category_semantic_class(slot, value, :input)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp scratch_slot_class(:boolean, :literal),
    do: "scratch-slot scratch-slot--boolean scratch-slot--literal"

  defp scratch_slot_class(:boolean, :block),
    do: "scratch-slot scratch-slot--boolean scratch-slot--block"

  defp scratch_slot_class(:round, :literal),
    do: "scratch-slot scratch-slot--round scratch-slot--literal"

  defp scratch_slot_class(:round, :block),
    do: "scratch-slot scratch-slot--round scratch-slot--block"

  defp scratch_slot_class(_, :literal),
    do: "scratch-slot scratch-slot--literal"

  defp scratch_slot_class(_, :block),
    do: "scratch-slot scratch-slot--block"

  # Scratch inline variable/list primitives (input_type 12/13) should be visually distinct
  # from literal values like numbers, so users can immediately spot data references.
  defp scratch_input_semantic_class(%{kind: :literal, input_type: input_type})
       when input_type in [12, 13],
       do: "scratch-slot--data-ref"

  defp scratch_input_semantic_class(%{"kind" => "literal", "input_type" => input_type})
       when input_type in [12, 13],
       do: "scratch-slot--data-ref"

  defp scratch_input_semantic_class(_), do: nil

  defp scratch_slot_category_semantic_class(:round, %{parent_category: :event}, :input),
    do: "scratch-slot--event-literal"

  defp scratch_slot_category_semantic_class(_, _, _), do: nil

  defp annotate_items(items, %{category: category}) when is_list(items) do
    Enum.map(items, &Map.put(&1, :parent_category, category))
  end

  defp annotate_items(items, _), do: items

  defp scratch_block_items(%{opcode: "procedures_definition"} = block) do
    label_items =
      case detail_block_label(block.label) do
        label when is_binary(label) and label != "" ->
          [
            %{kind: :label, value: "定義 "},
            %{kind: :definition_name, value: label}
          ]

        _ ->
          [%{kind: :label, value: "定義"}]
      end

    label_items
  end

  defp scratch_block_items(%{opcode: "data_setvariableto"} = block) do
    label = detail_block_label(block.label)
    if is_binary(label) and label != "" do
      BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{})
    else
      []
    end
  end

  defp scratch_block_items(block) do
    label = detail_block_label(block.label)
    if is_binary(label) and label != "" do
      BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{})
    else
      []
    end
  end

  defp find_custom_input(inputs, name) do
    Enum.find(inputs || [], fn input -> input.name == name end)
  end

  defp detail_block_label(label) when is_binary(label) do
    label
    |> String.trim_leading()
  end

  defp detail_block_label(label), do: label

  defp scratch_category_class(:motion), do: "bg-[#4C97FF]"
  defp scratch_category_class(:looks), do: "bg-[#9966FF]"
  defp scratch_category_class(:sound), do: "bg-[#CF63CF]"
  defp scratch_category_class(:event), do: "bg-[#FFBF00]"
  defp scratch_category_class(:control), do: "bg-[#FFAB19]"
  defp scratch_category_class(:sensing), do: "bg-[#5CB1D6]"
  defp scratch_category_class(:operator), do: "bg-[#59C059]"
  defp scratch_category_class(:data), do: "bg-[#FF8C1A]"
  defp scratch_category_class(:custom), do: "bg-[#FF6680]"
  defp scratch_category_class(:pen), do: "bg-[#0FBD8C]"
  defp scratch_category_class(_), do: "bg-slate-500"

  defp scratch_category_hex(:motion), do: "#4C97FF"
  defp scratch_category_hex(:looks), do: "#9966FF"
  defp scratch_category_hex(:sound), do: "#CF63CF"
  defp scratch_category_hex(:event), do: "#FFBF00"
  defp scratch_category_hex(:control), do: "#FFAB19"
  defp scratch_category_hex(:sensing), do: "#5CB1D6"
  defp scratch_category_hex(:operator), do: "#59C059"
  defp scratch_category_hex(:data), do: "#FF8C1A"
  defp scratch_category_hex(:custom), do: "#FF6680"
  defp scratch_category_hex(:pen), do: "#0FBD8C"
  defp scratch_category_hex(_), do: "#64748B"

  defp scratch_shape_class(:hat), do: "rounded-t-[1.4rem] rounded-b-lg"
  defp scratch_shape_class(:c_block), do: "rounded-t-lg rounded-b-md pb-2"
  defp scratch_shape_class(:cap), do: "rounded-t-lg rounded-b-[1.35rem]"
  defp scratch_shape_class(:reporter_boolean), do: "hexagon"
  defp scratch_shape_class(:reporter_round), do: "rounded-full"
  defp scratch_shape_class(_), do: "rounded-lg"

  defp inline_shape_class(:boolean), do: "hexagon"
  defp inline_shape_class(:reporter_boolean), do: "hexagon"
  defp inline_shape_class(:round), do: "rounded-full"
  defp inline_shape_class(:reporter_round), do: "rounded-full"
  defp inline_shape_class(_), do: "rounded-md"

  defp slot_shell_class(:boolean, :literal),
    do: "rounded-[1rem] bg-[#f7fffb] text-[#17643d] ring-1 ring-[#8dd8ad]"

  defp slot_shell_class(:boolean, :block),
    do: "rounded-[1rem] bg-[#f7fffb] ring-1 ring-[#8dd8ad]"

  defp slot_shell_class(:round, :literal),
    do: "rounded-[1rem] bg-[#fff7e6] text-[#7a4d00] ring-1 ring-[#ffd27a]"

  defp slot_shell_class(:round, :block),
    do: "rounded-[1rem] bg-[#fff7e6] ring-1 ring-[#ffd27a]"

  defp slot_shell_class(_, :literal),
    do: "rounded-md bg-white/95 text-slate-700 ring-1 ring-slate-300/70"

  defp slot_shell_class(_, :block),
    do: "rounded-md bg-white/95 ring-1 ring-slate-300/70"

  defp scratch_child_container_class(:c_block),
    do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem] rounded-b-[1.25rem] bg-inherit pr-1"

  defp scratch_child_container_class(_),
    do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem]"

  defp scratch_child_name("SUBSTACK"), do: nil
  defp scratch_child_name("SUBSTACK2"), do: "else"
  defp scratch_child_name(_), do: nil

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{shape: shape}}
       })
       when shape in [:round, :reporter_round],
       do: true

  defp inline_block_without_slot_wrapper?(_), do: false

  defp c_block_join_class(%{shape: :c_block, children: children}) when is_list(children) do
    if Enum.any?(children), do: "scratch-c-block-head-joined", else: nil
  end

  defp c_block_join_class(_), do: nil

  defp custom_block_signature(%{kind: :custom_block, header: header}) when is_map(header) do
    mutation = Map.get(header, :mutation, %{})
    Map.get(mutation, "proccode") || Map.get(header, :label) || "custom block"
  end

  defp custom_block_signature(_), do: "custom block"

  defp custom_block_arguments(%{kind: :custom_block, header: header}) when is_map(header) do
    mutation = Map.get(header, :mutation, %{})
    names = mutation_array(mutation, "argumentnames")
    defaults = mutation_array(mutation, "argumentdefaults")
    fields = Map.get(header, :fields, [])
    inputs = Map.get(header, :inputs, [])

    case names do
      [] ->
        fallback_custom_args(fields, inputs)

      _ ->
        names
        |> Enum.with_index()
        |> Enum.map(fn {name, index} ->
          %{
            name: normalize_custom_arg_name(name, index),
            default: Enum.at(defaults, index)
          }
        end)
    end
  end

  defp custom_block_arguments(_), do: []

  defp fallback_custom_args(fields, inputs) do
    field_args =
      Enum.map(fields, fn field ->
        %{name: "field:#{field.name}", default: field.value}
      end)

    input_args =
      Enum.map(inputs, fn input ->
        %{
          name: "input:#{input.name}",
          default: scratch_input_text(input.value)
        }
      end)

    field_args ++ input_args
  end

  defp mutation_array(mutation, key) when is_map(mutation) do
    case Map.get(mutation, key) do
      value when is_list(value) ->
        Enum.map(value, &to_string/1)

      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, list} when is_list(list) -> Enum.map(list, &to_string/1)
          _ -> []
        end

      _ ->
        []
    end
  end

  defp normalize_custom_arg_name(name, _index) when is_binary(name) and name != "", do: name
  defp normalize_custom_arg_name(_name, index), do: "arg#{index + 1}"

  # ---- Variables Panel ----

  attr :project, :map, required: true
  attr :target, :map, default: nil
  attr :selected_target_type, :string, default: nil
  attr :expanded_variable_key, :string, default: nil

  defp variables_panel(assigns) do
    # ステージ選択時: グローバル変数のみ / スプライト選択時: そのスプライトのローカル変数のみ
    filtered =
      if assigns.selected_target_type == "stage" do
        Enum.filter(assigns.project.variables, &(&1.scope == :global))
      else
        sprite_name = assigns.target && assigns.target.name

        assigns.project.variables
        |> Enum.filter(&(&1.scope == :local && &1.sprite == sprite_name))
      end

    assigns =
      assigns
      |> assign(:variables, Enum.filter(filtered, &(&1.kind == :variable)))
      |> assign(:lists, Enum.filter(filtered, &(&1.kind == :list)))

    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        変数参照マップ <span class="text-xs text-gray-400 font-normal ml-2">使用中の変数のみ表示</span>
      </h2>
      
      <%= if Enum.any?(@variables) or Enum.any?(@lists) do %>
        <div class="space-y-3">
          <.variable_group
            title="変数"
            items={@variables}
            expanded_variable_key={@expanded_variable_key}
          />
          <.variable_group
            title="リスト"
            items={@lists}
            expanded_variable_key={@expanded_variable_key}
          />
        </div>
      <% else %>
        <.empty_state
          icon=""
          message={
            if @selected_target_type == "stage",
              do: "使用中のグローバル変数が見つかりませんでした",
              else: "このスプライトにローカル変数はありません"
          }
        />
      <% end %>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true
  attr :expanded_variable_key, :string, default: nil

  defp variable_group(assigns) do
    ~H"""
    <%= if Enum.any?(@items) do %>
      <section class="space-y-3">
        <div class="flex items-center gap-2 px-1">
          <h3 class="text-sm font-semibold text-gray-700">{@title}</h3>
           <span class="text-xs text-gray-400">{length(@items)} items</span>
        </div>
        
        <%= for item <- @items do %>
          <.variable_card item={item} expanded?={@expanded_variable_key == variable_key(item)} />
        <% end %>
      </section>
    <% end %>
    """
  end

  attr :item, :map, required: true
  attr :expanded?, :boolean, required: true

  defp variable_card(assigns) do
    assigns = assign(assigns, :usage_groups, grouped_variable_usages(assigns.item))

    ~H"""
    <div class="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <button
        type="button"
        phx-click="toggle_variable_detail"
        phx-value-key={variable_key(@item)}
        class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition hover:bg-slate-50"
      >
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <span class="truncate text-sm font-medium text-gray-800">{@item.name}</span>
            <span class={scope_badge_class(@item.scope)}>{scope_label(@item.scope)}</span>
          </div>
          
          <p class="mt-1 text-xs text-gray-400">{variable_usage_count_text(@item)}</p>
        </div>
        
        <span class="text-xs font-medium text-slate-400">
          {if @expanded?, do: "Hide", else: "Usage"}
        </span>
      </button>
      
      <%= if @expanded? do %>
        <div class="border-t border-gray-200 bg-slate-50 px-4 py-3">
          <%= if Enum.any?(@usage_groups) do %>
            <div class="space-y-3">
              <%= for group <- @usage_groups do %>
                <div>
                  <div class="mb-2 flex items-center gap-2">
                    <span class="text-sm font-medium text-slate-700">{group.sprite}</span>
                    <span class="text-xs text-slate-400">
                      {if group.type == "stage", do: "Stage", else: "Sprite"}
                    </span>
                  </div>
                  
                  <div class="space-y-2">
                    <%= for usage <- group.usages do %>
                      <button
                        type="button"
                        phx-click="jump_to_variable_usage"
                        phx-value-sprite={usage.sprite}
                        phx-value-type={usage.type}
                        phx-value-detail-kind={usage.detail_kind}
                        phx-value-detail-id={usage.detail_id}
                        class="flex w-full items-center justify-between gap-3 rounded-lg border border-slate-200 bg-white px-3 py-2 text-left transition hover:border-blue-200 hover:bg-blue-50"
                      >
                        <div class="min-w-0">
                          <div class="flex items-center gap-2">
                            <%= for access <- usage.accesses do %>
                              <span class={access_badge_class(access)}>{access_label(access)}</span>
                            <% end %>
                            
                            <span class="truncate text-xs font-medium text-slate-700">
                              {usage.detail_label}
                            </span>
                          </div>
                        </div>
                         <span class="text-xs text-slate-400">Open</span>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-xs italic text-slate-400">No usage found.</p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp variable_key(item) do
    [Atom.to_string(item.kind), item.scope, item.sprite || "", item.name]
    |> Enum.map(&to_string/1)
    |> Enum.join("::")
  end

  defp grouped_variable_usages(item) do
    (item.readers ++ item.writers)
    |> Enum.group_by(fn ref ->
      {ref.sprite, ref.type, ref.detail_kind, ref.detail_id, ref.detail_label}
    end)
    |> Enum.map(fn {{sprite, type, detail_kind, detail_id, detail_label}, refs} ->
      %{
        sprite: sprite,
        type: type,
        detail_kind: detail_kind,
        detail_id: detail_id,
        detail_label: detail_label,
        accesses: refs |> Enum.map(& &1.access) |> Enum.uniq() |> Enum.sort()
      }
    end)
    |> Enum.group_by(fn usage -> {usage.sprite, usage.type} end)
    |> Enum.map(fn {{sprite, type}, usages} ->
      %{
        sprite: sprite,
        type: type,
        usages: Enum.sort_by(usages, &String.downcase(&1.detail_label))
      }
    end)
    |> Enum.sort_by(fn group -> {group.type != "stage", String.downcase(group.sprite)} end)
  end

  defp variable_usage_count_text(item) do
    total = length(item.readers) + length(item.writers)
    "#{total} usage entries"
  end

  defp scope_label(:global), do: "Global"
  defp scope_label(:local), do: "Local"

  defp scope_badge_class(:global),
    do: "rounded-full bg-purple-100 px-2 py-0.5 text-xs text-purple-700"

  defp scope_badge_class(:local),
    do: "rounded-full bg-orange-100 px-2 py-0.5 text-xs text-orange-700"

  defp access_label(:read), do: "読む"
  defp access_label(:write), do: "書く"

  defp access_badge_class(:read),
    do: "rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-medium text-emerald-700"

  defp access_badge_class(:write),
    do: "rounded-full bg-rose-100 px-2 py-0.5 text-[10px] font-medium text-rose-700"

  # ---- Costumes Panel ----

  attr :target, :map, default: nil

  defp costumes_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        コスチューム
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— {display_name(@target)}</span>
        <% end %>
      </h2>
      
      <%= if @target && Enum.any?(@target.costumes) do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          <%= for {costume, idx} <- Enum.with_index(@target.costumes) do %>
            <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <div
                class="aspect-square bg-gray-50 flex items-center justify-center p-2 border-b border-gray-100"
                style="background-image: linear-gradient(45deg, #f0f0f0 25%, transparent 25%), linear-gradient(-45deg, #f0f0f0 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f0f0f0 75%), linear-gradient(-45deg, transparent 75%, #f0f0f0 75%); background-size: 16px 16px; background-position: 0 0, 0 8px, 8px -8px, -8px 0px;"
              >
                <%= if costume.base64 do %>
                  <img
                    src={"data:#{costume.mime};base64,#{costume.base64}"}
                    alt={costume.name}
                    class="max-w-full max-h-full object-contain"
                  />
                <% else %>
                  <span class="text-3xl text-gray-300">🖼️</span>
                <% end %>
              </div>
              
              <div class="p-2 text-center">
                <p class="text-xs font-medium text-gray-700 truncate">{costume.name}</p>
                
                <p class="text-[10px] text-gray-400 uppercase">{costume.data_format} #{idx + 1}</p>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="👔" message="コスチュームがありません" />
      <% end %>
    </div>
    """
  end

  # ---- Sounds Panel ----

  attr :target, :map, default: nil

  defp sounds_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        サウンド
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— {display_name(@target)}</span>
        <% end %>
      </h2>
      
      <%= if @target && Enum.any?(@target.sounds) do %>
        <div class="space-y-3">
          <%= for sound <- @target.sounds do %>
            <div class="bg-white rounded-xl border border-gray-200 p-4">
              <div class="flex items-center gap-3">
                <span class="text-2xl">🔊</span>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-gray-800 text-sm">{sound.name}</p>
                  
                  <p class="text-[10px] text-gray-400 uppercase mt-0.5">
                    {sound.data_format}
                    <%= if sound.rate do %>
                      · {div(sound.rate, 1000)}kHz
                    <% end %>
                    
                    <%= if sound.sample_count && sound.rate do %>
                      · {Float.round(sound.sample_count / sound.rate, 1)}秒
                    <% end %>
                  </p>
                </div>
              </div>
              
              <%= if sound.base64 do %>
                <div class="mt-3">
                  <audio controls class="w-full h-8" preload="none">
                    <source src={"data:#{sound.mime};base64,#{sound.base64}"} type={sound.mime} />
                  </audio>
                </div>
              <% else %>
                <p class="mt-2 text-xs text-gray-400 italic">音声データが見つかりません</p>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="🔊" message="サウンドがありません" />
      <% end %>
    </div>
    """
  end

  # ---- Empty State ----

  attr :icon, :string, required: true
  attr :message, :string, required: true

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <%= if @icon != "" do %>
        <span class="text-4xl mb-3">{@icon}</span>
      <% end %>
      
      <p class="text-gray-400 text-sm">{@message}</p>
    </div>
    """
  end

  defp display_name(%{is_stage: true}), do: "背景"
  defp display_name(%{name: name}), do: name

  # ---- Sprite Thumbnail ----

  attr :sprite, :map, required: true

  defp sprite_thumbnail(assigns) do
    first_costume = List.first(assigns.sprite.costumes || [])
    assigns = assign(assigns, :costume, first_costume)

    ~H"""
    <%= if @costume && @costume.base64 do %>
      <img
        src={"data:#{@costume.mime};base64,#{@costume.base64}"}
        alt={@sprite.name}
        class="w-8 h-8 object-contain flex-shrink-0 rounded"
      />
    <% else %>
      <span class="flex-shrink-0">{if @sprite.is_stage, do: "🎭", else: "🐱"}</span>
    <% end %>
    """
  end

  # ---- helpers ----

  @event_hat_opcodes ~w(
    event_whenflagclicked
    event_whenbroadcastreceived
    event_whenkeypressed
    event_whenthisspriteclicked
    event_whenstageclicked
    event_whengreaterthan
    event_whenbackdropswitchesto
    control_start_as_clone
  )

  defp event_hat?(opcode), do: opcode in @event_hat_opcodes

  defp scratch_input_text(value) do
    case value do
      nil -> ""
      %{kind: :literal, value: literal} when is_binary(literal) -> literal
      %{kind: :literal, value: literal} when is_number(literal) -> to_string(literal)
      %{"kind" => "literal", "value" => literal} when is_binary(literal) -> literal
      %{"kind" => "literal", "value" => literal} when is_number(literal) -> to_string(literal)
      value when is_binary(value) -> value
      value when is_number(value) -> to_string(value)
      value when is_atom(value) -> to_string(value)
      _ -> inspect(value)
    end
  end
end
