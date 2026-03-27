defmodule ScratchInspectorWeb.InspectorLive do
  use ScratchInspectorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Scratch Inspector")
      |> assign(:project, nil)
      |> assign(:active_tab, :code)
      |> assign(:selected_sprite, nil)
      |> assign(:selected_target_type, nil)
      |> assign(:upload_error, nil)
      |> assign(:processing, false)
      |> assign(:expanded_functions, MapSet.new())
      |> assign(:expanded_scripts, MapSet.new())
      |> assign(:show_sprite_code, false)
      |> allow_upload(:scratch_file,
        accept: :any,
        max_entries: 1,
        max_file_size: 50_000_000,
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
     |> assign(:expanded_functions, MapSet.new())
     |> assign(:expanded_scripts, MapSet.new())
     |> assign(:show_sprite_code, false)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("toggle_function", %{"name" => name}, socket) do
    expanded = socket.assigns.expanded_functions

    expanded =
      if MapSet.member?(expanded, name),
        do: MapSet.delete(expanded, name),
        else: MapSet.put(expanded, name)

    {:noreply, assign(socket, :expanded_functions, expanded)}
  end

  @impl true
  def handle_event("toggle_script", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded_scripts

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, assign(socket, :expanded_scripts, expanded)}
  end

  @impl true
  def handle_event("toggle_sprite_code", _params, socket) do
    {:noreply, assign(socket, :show_sprite_code, !socket.assigns.show_sprite_code)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:project, nil)
     |> assign(:selected_sprite, nil)
     |> assign(:selected_target_type, nil)
     |> assign(:upload_error, nil)
     |> assign(:active_tab, :events)
     |> assign(:processing, false)
     |> assign(:expanded_functions, MapSet.new())
     |> assign(:expanded_scripts, MapSet.new())
     |> assign(:show_sprite_code, false)}
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
        <div class="flex h-[calc(100vh-56px)]">
          <!-- Sidebar -->
          <aside class="w-56 bg-white border-r border-gray-200 overflow-y-auto flex-shrink-0">
            <!-- Stage section -->
            <%= if @project.stage do %>
              <div class="px-3 py-2 border-b border-gray-100">
                <p class="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">背景</p>
              </div>
              <div class="p-2">
                <button
                  phx-click="select_sprite"
                  phx-value-name={@project.stage.name}
                  phx-value-type="stage"
                  class={[
                    "w-full text-left px-3 py-2 rounded-lg text-sm transition flex items-center gap-2",
                    if(@selected_sprite == @project.stage.name,
                      do: "bg-[#4C97FF] text-white font-medium",
                      else: "text-gray-700 hover:bg-gray-100"
                    )
                  ]}
                >
                  <.sprite_thumbnail sprite={@project.stage} />
                  <span class="truncate flex-1">背景</span>
                  <span class={[
                    "ml-1 text-xs px-1.5 py-0.5 rounded-full",
                    if(@selected_sprite == @project.stage.name,
                      do: "bg-white/20 text-white",
                      else: "bg-gray-100 text-gray-500"
                    )
                  ]}>
                    <%= length(@project.stage.costumes) %>🎨
                  </span>
                </button>
              </div>
            <% end %>

            <!-- Sprites section -->
            <div class="px-3 py-2 border-b border-gray-100">
              <p class="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">
                スプライト (<%= length(@project.sprites) %>)
              </p>
            </div>
            <nav class="p-2 space-y-0.5">
              <%= for sprite <- @project.sprites do %>
                <button
                  phx-click="select_sprite"
                  phx-value-name={sprite.name}
                  phx-value-type="sprite"
                  class={[
                    "w-full text-left px-3 py-2 rounded-lg text-sm transition flex items-center gap-2",
                    if(@selected_sprite == sprite.name,
                      do: "bg-[#4C97FF] text-white font-medium",
                      else: "text-gray-700 hover:bg-gray-100"
                    )
                  ]}
                >
                  <.sprite_thumbnail sprite={sprite} />
                  <span class="truncate flex-1"><%= sprite.name %></span>
                  <span class={[
                    "ml-1 text-xs px-1.5 py-0.5 rounded-full",
                    if(@selected_sprite == sprite.name,
                      do: "bg-white/20 text-white",
                      else: "bg-gray-100 text-gray-500"
                    )
                  ]}>
                    <%= length(sprite.scripts) %>
                  </span>
                </button>
              <% end %>
            </nav>
          </aside>

          <!-- Main content -->
          <main class="flex-1 overflow-hidden flex flex-col">
            <!-- Tabs -->
            <div class="bg-white border-b border-gray-200 px-4 flex gap-1 pt-2">
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
                <% :functions -> %>
                  <.functions_panel target={target} expanded={@expanded_functions} />
                <% :variables -> %>
                  <.variables_panel project={@project} target={target} selected_target_type={@selected_target_type} />
                <% :code -> %>
                  <.code_panel target={target} expanded_scripts={@expanded_scripts} />
                <% :costumes -> %>
                  <.costumes_panel target={target} />
                <% :sounds -> %>
                  <.sounds_panel target={target} />
              <% end %>
            </div>
          </main>
        </div>
      <% end %>
    </div>
    """
  end

  # ---- sub-components ----

  defp tabs, do: [
    {:code, "コード", "📜"},
    {:functions, "ブロック定義", "🔧"},
    {:variables, "変数", "📦"},
    {:costumes, "コスチューム", "👔"},
    {:sounds, "サウンド", "🔊"}
  ]

  defp upload_error_text(:too_large), do: "ファイルが大きすぎます（最大 50MB）"
  defp upload_error_text(:not_accepted), do: "対応していないファイル形式です"
  defp upload_error_text(:too_many_files), do: "ファイルは1つだけ選択してください"
  defp upload_error_text(_), do: "アップロードエラーが発生しました"

  # ---- Functions Panel ----

  attr :target, :map, default: nil
  attr :expanded, :any, required: true

  defp functions_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        ブロック定義
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— <%= display_name(@target) %></span>
        <% end %>
      </h2>
      <%= if @target && Enum.any?(@target.custom_blocks) do %>
        <div class="space-y-3">
          <%= for block <- @target.custom_blocks do %>
            <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <button
                phx-click="toggle_function"
                phx-value-name={block.name}
                class="w-full text-left p-4 hover:bg-gray-50 transition"
              >
                <div class="flex items-center gap-2">
                  <span class="text-lg">🔧</span>
                  <span class="font-medium text-gray-800 text-sm flex-1"><%= block.name %></span>
                  <span class="text-xs text-gray-400">
                    <%= length(block.code_blocks) %> ブロック
                  </span>
                  <span class={"text-gray-400 text-xs transition-transform #{if MapSet.member?(@expanded, block.name), do: "rotate-180"}"}>
                    ▼
                  </span>
                </div>
              </button>
              <%= if MapSet.member?(@expanded, block.name) do %>
                <div class="border-t border-gray-100 bg-gray-50 p-4">
                  <%= if Enum.any?(block.code_blocks) do %>
                    <.block_chain blocks={block.code_blocks} />
                  <% else %>
                    <p class="text-xs text-gray-400 italic">ブロックなし</p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="🔧" message="このスプライトにブロック定義はありません" />
      <% end %>
    </div>
    """
  end

  # ---- Code Panel (non-function scripts) ----

  attr :target, :map, default: nil
  attr :expanded_scripts, :any, required: true

  defp code_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        スクリプト一覧
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— <%= display_name(@target) %></span>
        <% end %>
      </h2>
      <%= if @target && Enum.any?(@target.top_scripts) do %>
        <div class="space-y-3">
          <%= for script <- @target.top_scripts do %>
            <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <button
                phx-click="toggle_script"
                phx-value-id={script.id}
                class="w-full text-left p-4 hover:bg-gray-50 transition"
              >
                <div class="flex items-center gap-2">
                  <span class="text-lg"><%= event_icon(script.hat_opcode) %></span>
                  <span class="font-medium text-gray-800 text-sm flex-1"><%= script.hat_label %></span>
                  <span class="text-xs text-gray-400">
                    <%= length(script.blocks) %> ブロック
                  </span>
                  <span class={"text-gray-400 text-xs transition-transform #{if MapSet.member?(@expanded_scripts, script.id), do: "rotate-180"}"}>
                    ▼
                  </span>
                </div>
              </button>

              <%= if MapSet.member?(@expanded_scripts, script.id) do %>
                <div class="border-t border-gray-100 bg-gray-50 p-4">
                  <%= if Enum.any?(script.blocks) do %>
                    <.block_chain blocks={script.blocks} />
                  <% else %>
                    <p class="text-xs text-gray-400 italic">ブロックなし</p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="📜" message="このスプライトにスクリプトはありません" />
      <% end %>
    </div>
    """
  end

  # ---- Block Chain Renderer ----

  attr :blocks, :list, required: true

  defp block_chain(assigns) do
    assigns = assign(assigns, :vblocks, to_visual_blocks(assigns.blocks))

    ~H"""
    <div>
      <%= for block <- @vblocks do %>
        <% color = block_color(block.opcode) %>
        <% wall_color = "#CC8813" %>
        <% is_hat = block.depth == 0 && String.starts_with?(block.opcode, "event_") %>
        <% top_r = if is_hat, do: "18px", else: "4px" %>
        <% bot_r = if block.is_c_opener, do: "0px", else: "4px" %>

        <!-- Block row -->
        <div style="display: flex; align-items: stretch; margin-bottom: 1px;">
          <%= for _ <- List.duplicate(nil, block.depth) do %>
            <div style={"width: 16px; background-color: #{wall_color}; flex-shrink: 0;"}></div>
          <% end %>
          <div style={"flex: 1; background-color: #{color}; color: white; font-family: ui-sans-serif, system-ui, sans-serif; font-size: 0.75rem; font-weight: 600; padding: 5px 10px; border-radius: #{top_r} #{top_r} #{bot_r} #{bot_r}; box-shadow: 0 2px 0 rgba(0,0,0,0.22); display: flex; align-items: center; gap: 6px; min-width: 0; user-select: none;"}>
            <span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"><%= block.label %></span>
            <%= for param <- block.params do %>
              <span style="background: rgba(255,255,255,0.9); color: #333; border-radius: 4px; padding: 1px 6px; font-size: 0.7rem; white-space: nowrap; flex-shrink: 0;"><%= param %></span>
            <% end %>
          </div>
        </div>

        <!-- C-block closing arms -->
        <%= for prefix_count <- block.closing_arms do %>
          <div style="display: flex; align-items: stretch; margin-bottom: 1px;">
            <%= for _ <- List.duplicate(nil, prefix_count) do %>
              <div style={"width: 16px; background-color: #{wall_color}; flex-shrink: 0; min-height: 10px;"}></div>
            <% end %>
            <div style={"width: 20px; height: 10px; background-color: #{wall_color}; border-radius: 0 0 4px 4px;"}></div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp to_visual_blocks([]), do: []

  defp to_visual_blocks(blocks) do
    n = length(blocks)

    blocks
    |> Enum.with_index()
    |> Enum.map(fn {block, i} ->
      next = if i + 1 < n, do: Enum.at(blocks, i + 1), else: nil
      next_depth = if next, do: next.depth, else: 0
      close_count = max(0, block.depth - next_depth)

      closing_arms =
        if close_count > 0 do
          Enum.map(0..(close_count - 1), fn k -> block.depth - k - 1 end)
        else
          []
        end

      Map.merge(block, %{
        is_c_opener: next != nil && next.depth > block.depth,
        closing_arms: closing_arms
      })
    end)
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
                <span class="text-lg">📦</span>
                <span class="font-medium text-gray-800 text-sm"><%= var.name %></span>
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
              <div class="ml-7 grid grid-cols-2 gap-2">
                <%= if Enum.any?(var.readers) do %>
                  <div>
                    <p class="text-xs text-gray-400 mb-1">参照</p>
                    <div class="space-y-1">
                      <%= for ref <- var.readers do %>
                        <div class="text-xs bg-green-50 text-green-700 rounded px-2 py-1 font-mono">
                          <%= ref %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.any?(var.writers) do %>
                  <div>
                    <p class="text-xs text-gray-400 mb-1">書き込み</p>
                    <div class="space-y-1">
                      <%= for ref <- var.writers do %>
                        <div class="text-xs bg-red-50 text-red-700 rounded px-2 py-1 font-mono">
                          <%= ref %>
                        </div>
                      <% end %>
                    </div>
                  </div>
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

  defp event_icon("event_whenflagclicked"), do: "🚩"
  defp event_icon("event_whenbroadcastreceived"), do: "📡"
  defp event_icon("event_whenkeypressed"), do: "⌨️"
  defp event_icon("event_whenthisspriteclicked"), do: "🖱️"
  defp event_icon("event_whenstageclicked"), do: "🖱️"
  defp event_icon("event_whengreaterthan"), do: "📊"
  defp event_icon("event_whenbackdropswitchesto"), do: "🎨"
  defp event_icon("control_start_as_clone"), do: "🐑"
  defp event_icon(_), do: "⚡"

end
