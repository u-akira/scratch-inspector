defmodule ScratchInspectorWeb.Live.InspectorComponents.Variables do
  use ScratchInspectorWeb, :html

  attr :project, :map, required: true
  attr :target, :map, default: nil
  attr :selected_target_type, :string, default: nil
  attr :expanded_variable_key, :string, default: nil

  def variables_panel(assigns) do
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
        変数一覧マップ<span class="text-xs text-gray-400 font-normal ml-2">使用中の変数のみ表示</span>
      </h2>
      <%= if Enum.any?(@variables) or Enum.any?(@lists) do %>
        <div class="space-y-3">
          <.variable_group title="変数" items={@variables} expanded_variable_key={@expanded_variable_key} />
          <.variable_group title="リスト" items={@lists} expanded_variable_key={@expanded_variable_key} />
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

  def variable_group(assigns) do
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

  def variable_card(assigns) do
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
        <span class="text-xs font-medium text-slate-400">{if @expanded?, do: "Hide", else: "Usage"}</span>
      </button>
      <%= if @expanded? do %>
        <div class="border-t border-gray-200 bg-slate-50 px-4 py-3">
          <%= if Enum.any?(@usage_groups) do %>
            <div class="space-y-3">
              <%= for group <- @usage_groups do %>
                <div>
                  <div class="mb-2 flex items-center gap-2">
                    <span class="text-sm font-medium text-slate-700">{group.sprite}</span>
                    <span class="text-xs text-slate-400">{if group.type == "stage", do: "Stage", else: "Sprite"}</span>
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
                            <span class="truncate text-xs font-medium text-slate-700">{usage.detail_label}</span>
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

  attr :icon, :string, required: true
  attr :message, :string, required: true

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <%= if @icon != "" do %>
        <span class="text-4xl mb-3">{@icon}</span>
      <% end %>
      <p class="text-gray-400 text-sm">{@message}</p>
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
    |> Enum.group_by(fn ref -> {ref.sprite, ref.type, ref.detail_kind, ref.detail_id, ref.detail_label} end)
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
      %{sprite: sprite, type: type, usages: Enum.sort_by(usages, &String.downcase(&1.detail_label))}
    end)
    |> Enum.sort_by(fn group -> {group.type != "stage", String.downcase(group.sprite)} end)
  end

  defp variable_usage_count_text(item) do
    total = length(item.readers) + length(item.writers)
    "#{total} usage entries"
  end

  defp scope_label(:global), do: "Global"
  defp scope_label(:local), do: "Local"
  defp scope_badge_class(:global), do: "rounded-full bg-purple-100 px-2 py-0.5 text-xs text-purple-700"
  defp scope_badge_class(:local), do: "rounded-full bg-orange-100 px-2 py-0.5 text-xs text-orange-700"
  defp access_label(:read), do: "読む"
  defp access_label(:write), do: "書く"
  defp access_badge_class(:read), do: "rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-medium text-emerald-700"
  defp access_badge_class(:write), do: "rounded-full bg-rose-100 px-2 py-0.5 text-[10px] font-medium text-rose-700"
end
