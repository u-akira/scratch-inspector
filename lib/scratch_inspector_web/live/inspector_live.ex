defmodule ScratchInspectorWeb.InspectorLive do
  use ScratchInspectorWeb, :live_view

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
     |> assign(:flow_detail, nil)}
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
    socket =
      case {Map.get(params, "sprite"), Map.get(params, "type")} do
        {sprite, type} when is_binary(sprite) and is_binary(type) ->
          socket
          |> assign(:selected_sprite, sprite)
          |> assign(:selected_target_type, type)

        _ ->
          socket
      end

    current = socket.assigns.flow_detail

    next =
      if current && current.kind == kind && current.id == id,
        do: nil,
        else: %{kind: kind, id: id}

    {:noreply, assign(socket, :flow_detail, next)}
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
     |> assign(:flow_detail, nil)}
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
             |> assign(:processing, false)}

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
              <span class="text-sm text-white/80 font-medium"><%= @project.name %></span>
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
                    ファイルを選択
                    <.live_file_input upload={@uploads.scratch_file} class="sr-only" />
                  </label>

                  <%= for entry <- @uploads.scratch_file.entries do %>
                    <div class="mt-4 text-sm text-gray-600 flex items-center justify-center gap-2">
                      <span>📄</span>
                      <span><%= entry.client_name %></span>
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
                      <p class="mt-1 text-xs text-gray-400">アップロード中... <%= entry.progress %>%</p>
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
                <p class="mt-3 text-sm text-red-500 text-center"><%= @upload_error %></p>
              <% end %>
              <%= for err <- upload_errors(@uploads.scratch_file) do %>
                <p class="mt-3 text-sm text-red-500 text-center"><%= upload_error_text(err) %></p>
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
                <span class="text-[10px] text-gray-600 truncate max-w-[48px]"><%= sprite.name %></span>
              </button>
            <% end %>
          </div>

          <!-- Tabs -->
          <div class="bg-white border-b border-gray-200 px-4 flex gap-1 pt-2 flex-shrink-0">
            <%= for {tab, label, icon} <- tabs() do %>
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
                <%= icon %> <%= label %>
              </button>
            <% end %>
          </div>

          <!-- Tab content -->
          <div class="flex-1 overflow-y-auto p-6">
            <% target = if(@project && @selected_sprite, do: current_target(@project, @selected_sprite, @selected_target_type), else: nil) %>
            <%= case @active_tab do %>
              <% :flow -> %>
                <.flow_graph_panel project={@project} target={target} flow_detail={@flow_detail} />
              <% :variables -> %>
                <.variables_panel project={@project} target={target} selected_target_type={@selected_target_type} />
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

  defp tabs, do: [
    {:flow,      "フロー",      "🔀"},
    {:variables, "変数",        "📦"},
    {:costumes,  "コスチューム", "👔"},
    {:sounds,    "サウンド",    "🔊"}
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
    expected_label = "📡 「#{msg}」を受け取ったとき"
    all_targets = Enum.filter([project.stage | project.sprites], & &1)

    Enum.flat_map(all_targets, fn target ->
      target.top_scripts
      |> Enum.filter(fn s ->
        s.hat_opcode == "event_whenbroadcastreceived" && s.hat_label == expected_label
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

  attr :project, :map, required: true
  attr :target, :map, default: nil
  attr :flow_detail, :map, default: nil

  defp flow_graph_panel(assigns) do
    {detail_blocks, detail_title, detail_receivers} =
      case assigns.flow_detail do
        %{kind: "script", id: id} when not is_nil(assigns.target) ->
          script = Enum.find(assigns.target.top_scripts, &(&1.id == id))
          if script, do: {script.blocks, script.hat_label, nil}, else: {nil, nil, nil}

        %{kind: "block_def", id: name} when not is_nil(assigns.target) ->
          cb = Enum.find(assigns.target.custom_blocks, &(&1.name == name))
          if cb, do: {cb.code_blocks, "🔧 #{name}", nil}, else: {nil, nil, nil}

        %{kind: "broadcast", id: msg} ->
          receivers = find_broadcast_receivers(assigns.project, msg)
          {nil, "📡 「#{msg}」を受け取るスプライト", receivers}

        _ ->
          {nil, nil, nil}
      end

    assigns =
      assigns
      |> assign(:detail_blocks, detail_blocks)
      |> assign(:detail_title, detail_title)
      |> assign(:detail_receivers, detail_receivers)
      |> assign(:graph_chart, build_flow_mermaid(assigns.project, assigns.target, assigns.flow_detail))

    ~H"""
    <div>
      <%= if @target do %>
        <%= if is_nil(@graph_chart) do %>
          <.empty_state icon="🔀" message="このスプライトにはスクリプトがありません" />
        <% else %>
          <div class="mb-4 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
            <div class="mb-3 flex items-center justify-between gap-3">
              <div>
                <h2 class="text-sm font-semibold text-gray-800">Flow Graph</h2>
                <p class="text-xs text-gray-500">Click a node to inspect its detail below.</p>
              </div>
              <span class="text-xs text-gray-400"><%= display_name(@target) %></span>
            </div>
            <div
              id={"flow-chart-#{flow_dom_id(@target)}"}
              phx-hook="MermaidChart"
              data-chart={@graph_chart}
              class="min-h-[360px] overflow-auto rounded-lg bg-slate-50 px-2 py-4"
            />
          </div>
        <% end %>

        <%= if @flow_detail && (@detail_blocks != nil || @detail_receivers != nil) do %>
          <div class="border border-gray-200 rounded-xl overflow-hidden bg-white">
            <div class="flex items-center justify-between px-4 py-2 bg-gray-50 border-b border-gray-200">
              <span class="text-sm font-semibold text-gray-700"><%= @detail_title %></span>
              <button
                phx-click="flow_select_detail"
                phx-value-kind={@flow_detail.kind}
                phx-value-id={@flow_detail.id}
                class="text-gray-400 hover:text-gray-600 text-lg leading-none"
              >✕</button>
            </div>
            <div class="p-4 bg-gray-50">
              <%= if @detail_blocks do %>
                <%= if Enum.any?(@detail_blocks) do %>
                  <.block_chain blocks={@detail_blocks} />
                <% else %>
                  <p class="text-xs text-gray-400 italic">ブロックなし</p>
                <% end %>
              <% else %>
                <%= if Enum.any?(@detail_receivers) do %>
                  <div class="space-y-2">
                    <%= for {sprite, script} <- @detail_receivers do %>
                      <button
                        phx-click="select_sprite"
                        phx-value-name={sprite.name}
                        phx-value-type={if sprite.is_stage, do: "stage", else: "sprite"}
                        class="flex items-center gap-3 w-full bg-white rounded-lg border border-gray-200 px-3 py-2 hover:bg-blue-50 hover:border-blue-200 transition text-left"
                      >
                        <.sprite_thumbnail sprite={sprite} />
                        <span class="text-xs font-medium text-gray-700"><%= display_name(sprite) %></span>
                        <span class="text-xs text-gray-400">→</span>
                        <span class="text-xs text-gray-600"><%= script.hat_label %></span>
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
        <.empty_state icon="🔀" message="上のサムネイルからスプライトを選択してください" />
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
            detail: %{kind: "script", id: script.id},
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
            detail: %{kind: "block_def", id: block_def.name},
            label: "🔧 #{block_def.name}",
            class: :block_def,
            block_def: block_def
          }
        end)

      block_node_ids = Map.new(block_nodes, fn node -> {node.block_def.name, node.id} end)

      broadcast_messages =
        (scripts |> Enum.flat_map(&broadcasts_sent_in_script(&1.blocks))) ++
          (custom_blocks |> Enum.flat_map(&broadcasts_sent_in_script(&1.code_blocks)))
        |> Enum.uniq()

      broadcast_nodes =
        broadcast_messages
        |> Enum.with_index(1)
        |> Enum.map(fn {msg, idx} ->
          %{
            id: "broadcast_#{idx}",
            detail: %{kind: "broadcast", id: msg},
            label: "📡 #{msg}",
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
                detail: %{
                  kind: "script",
                  id: script.id,
                  sprite: receiver_target.name,
                  type: if(receiver_target.is_stage, do: "stage", else: "sprite")
                },
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
              Map.get(receiver_node_ids, {receiver_target.name, receiver_target.is_stage, script.id})

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
  defp selected_flow_node?(%{kind: kind, id: id}, %{kind: kind, id: id}), do: true
  defp selected_flow_node?(_, _), do: false

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

  # ---- Block Chain Renderer ----

  attr :blocks, :list, required: true

  defp block_chain(assigns) do
    assigns = assign(assigns, :vblocks, to_visual_blocks(assigns.blocks))

    ~H"""
    <div>
      <%= for block <- @vblocks do %>
        <% color = block_color(block.opcode) %>
        <% is_hat = block.depth == 0 && String.starts_with?(block.opcode, "event_") %>
        <% top_r = if is_hat, do: "18px", else: "4px" %>
        <% bot_r = if block.is_c_opener, do: "0px", else: "4px" %>

        <!-- Block row -->
        <div style="display: flex; align-items: stretch; margin-bottom: 1px;">
          <%= for wc <- block.wall_colors do %>
            <div style={"width: 16px; background-color: #{wc}; flex-shrink: 0;"}></div>
          <% end %>
          <%= if block.depth > 0 do %>
            <div style="width: 6px; flex-shrink: 0;"></div>
          <% end %>
          <div style={"display: inline-flex; background-color: #{color}; color: white; font-family: ui-sans-serif, system-ui, sans-serif; font-size: 0.75rem; font-weight: 600; padding: 5px 10px; border-radius: #{top_r} #{top_r} #{bot_r} #{bot_r}; box-shadow: 0 2px 0 rgba(0,0,0,0.22); align-items: center; gap: 6px; user-select: none;"}>
            <span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"><%= block.label %></span>
            <%= for param <- block.params do %>
              <span style="background: rgba(255,255,255,0.9); color: #333; border-radius: 4px; padding: 1px 6px; font-size: 0.7rem; white-space: nowrap; flex-shrink: 0;"><%= param %></span>
            <% end %>
          </div>
        </div>

        <!-- C-block closing arms -->
        <%= for prefix_count <- block.closing_arms do %>
          <div style="display: flex; align-items: stretch; margin-bottom: 1px;">
            <%= for wc <- Enum.take(block.wall_colors, prefix_count) do %>
              <div style={"width: 16px; background-color: #{wc}; flex-shrink: 0; min-height: 10px;"}></div>
            <% end %>
            <div style={"width: 20px; height: 10px; background-color: #{Enum.at(block.wall_colors, prefix_count, "#FFAB19")}; border-radius: 0 0 4px 4px;"}></div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp to_visual_blocks([]), do: []

  defp to_visual_blocks(blocks) do
    n = length(blocks)

    {result, _} =
      blocks
      |> Enum.with_index()
      |> Enum.map_reduce(%{}, fn {block, i}, depth_colors ->
        next = if i + 1 < n, do: Enum.at(blocks, i + 1), else: nil
        next_depth = if next, do: next.depth, else: 0
        close_count = max(0, block.depth - next_depth)
        is_c_opener = next != nil && next.depth > block.depth

        closing_arms =
          if close_count > 0,
            do: Enum.map(0..(close_count - 1), fn k -> block.depth - k - 1 end),
            else: []

        wall_colors =
          if block.depth == 0,
            do: [],
            else: Enum.map(0..(block.depth - 1), fn d -> Map.get(depth_colors, d, "#FFAB19") end)

        new_depth_colors =
          if is_c_opener,
            do: Map.put(depth_colors, block.depth, block_color(block.opcode)),
            else: depth_colors

        enhanced = Map.merge(block, %{is_c_opener: is_c_opener, closing_arms: closing_arms, wall_colors: wall_colors})
        {enhanced, new_depth_colors}
      end)

    result
  end

  defp block_color(opcode) do
    cond do
      String.starts_with?(opcode, "motion_")     -> "#4C97FF"
      String.starts_with?(opcode, "looks_")      -> "#9966FF"
      String.starts_with?(opcode, "sound_")      -> "#CF63CF"
      String.starts_with?(opcode, "event_")      -> "#FFAB19"
      String.starts_with?(opcode, "control_")    -> "#FFAB19"
      String.starts_with?(opcode, "sensing_")    -> "#5CB1D6"
      String.starts_with?(opcode, "operator_")   -> "#59C059"
      String.starts_with?(opcode, "data_")       -> "#FF8C1A"
      String.starts_with?(opcode, "procedures_") -> "#FF6680"
      String.starts_with?(opcode, "pen_")        -> "#0fBD8C"
      true                                       -> "#8E9399"
    end
  end

  # ---- Variables Panel ----

  attr :project, :map, required: true
  attr :target, :map, default: nil
  attr :selected_target_type, :string, default: nil

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

    assigns = assign(assigns, :filtered_variables, filtered)

    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        変数参照マップ
        <span class="text-xs text-gray-400 font-normal ml-2">使用中の変数のみ表示</span>
      </h2>
      <%= if Enum.any?(@filtered_variables) do %>
        <div class="space-y-3">
          <%= for var <- @filtered_variables do %>
            <div class="bg-white rounded-xl border border-gray-200 p-4">
              <div class="flex items-center gap-2 mb-2">
                <span class="text-lg"><%= if var.kind == :list, do: "📋", else: "📦" %></span>
                <span class="font-medium text-gray-800 text-sm"><%= var.name %></span>
                <%= if var.kind == :list do %>
                  <span class="text-xs px-2 py-0.5 rounded-full bg-blue-100 text-blue-700">リスト</span>
                <% end %>
                <span class={[
                  "text-xs px-2 py-0.5 rounded-full",
                  if(var.scope == :global,
                    do: "bg-purple-100 text-purple-700",
                    else: "bg-orange-100 text-orange-700"
                  )
                ]}>
                  <%= if var.scope == :global, do: "グローバル", else: "ローカル" %>
                </span>
              </div>
              <div class="ml-7 flex flex-wrap gap-1">
                <%= for ref <- var.readers do %>
                  <button
                    phx-click="select_sprite"
                    phx-value-name={ref}
                    phx-value-type={if @project.stage && @project.stage.name == ref, do: "stage", else: "sprite"}
                    class="text-xs bg-green-50 text-green-700 rounded px-2 py-1 font-mono hover:bg-green-100 transition"
                  ><%= ref %></button>
                <% end %>
                <%= for ref <- var.writers do %>
                  <button
                    phx-click="select_sprite"
                    phx-value-name={ref}
                    phx-value-type={if @project.stage && @project.stage.name == ref, do: "stage", else: "sprite"}
                    class="text-xs bg-red-50 text-red-700 rounded px-2 py-1 font-mono hover:bg-red-100 transition"
                  ><%= ref %></button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="📦" message={
          if @selected_target_type == "stage",
            do: "使用中のグローバル変数が見つかりませんでした",
            else: "このスプライトにローカル変数はありません"
        } />
      <% end %>
    </div>
    """
  end

  # ---- Costumes Panel ----

  attr :target, :map, default: nil

  defp costumes_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        コスチューム
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— <%= display_name(@target) %></span>
        <% end %>
      </h2>
      <%= if @target && Enum.any?(@target.costumes) do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          <%= for {costume, idx} <- Enum.with_index(@target.costumes) do %>
            <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <div class="aspect-square bg-gray-50 flex items-center justify-center p-2 border-b border-gray-100"
                   style="background-image: linear-gradient(45deg, #f0f0f0 25%, transparent 25%), linear-gradient(-45deg, #f0f0f0 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f0f0f0 75%), linear-gradient(-45deg, transparent 75%, #f0f0f0 75%); background-size: 16px 16px; background-position: 0 0, 0 8px, 8px -8px, -8px 0px;">
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
                <p class="text-xs font-medium text-gray-700 truncate"><%= costume.name %></p>
                <p class="text-[10px] text-gray-400 uppercase"><%= costume.data_format %> #<%= idx + 1 %></p>
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
          <span class="text-gray-400 font-normal">— <%= display_name(@target) %></span>
        <% end %>
      </h2>
      <%= if @target && Enum.any?(@target.sounds) do %>
        <div class="space-y-3">
          <%= for sound <- @target.sounds do %>
            <div class="bg-white rounded-xl border border-gray-200 p-4">
              <div class="flex items-center gap-3">
                <span class="text-2xl">🔊</span>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-gray-800 text-sm"><%= sound.name %></p>
                  <p class="text-[10px] text-gray-400 uppercase mt-0.5">
                    <%= sound.data_format %>
                    <%= if sound.rate do %>
                      · <%= div(sound.rate, 1000) %>kHz
                    <% end %>
                    <%= if sound.sample_count && sound.rate do %>
                      · <%= Float.round(sound.sample_count / sound.rate, 1) %>秒
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
      <span class="text-4xl mb-3"><%= @icon %></span>
      <p class="text-gray-400 text-sm"><%= @message %></p>
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
      <span class="flex-shrink-0"><%= if @sprite.is_stage, do: "🎭", else: "🐱" %></span>
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

end
