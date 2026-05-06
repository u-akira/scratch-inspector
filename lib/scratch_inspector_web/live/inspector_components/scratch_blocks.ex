defmodule ScratchInspectorWeb.Live.InspectorComponents.ScratchBlocks do
  use ScratchInspectorWeb, :html
  alias ScratchInspectorWeb.Live.BlockLabelItems
  @microbit_icon_uri "data:image/png;base64,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"

  attr :detail, :map, required: true
  def scratch_script_detail(assigns) do
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
  def scratch_stack(assigns) do
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
  def scratch_block(assigns) do
    assigns =
      assigns
      |> assign(:category_class, scratch_category_class(assigns.block.category))
      |> assign(:shape_class, scratch_shape_class(assigns.block.shape))
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))
      |> assign(:child_container_class, scratch_child_container_class(assigns.block.shape))
      |> assign(:c_block?, assigns.block.shape == :c_block)
      |> assign(:show_green_flag_icon, assigns.block.opcode == "event_whenflagclicked")
      |> assign(:show_extension_icon, assigns.block.category == :extension)
      |> assign(:microbit_icon_uri, @microbit_icon_uri)
      |> assign(:c_block_join_class, c_block_join_class(assigns.block))

    ~H"""
    <div class="flex flex-col items-start w-full min-w-0">
      <div class={["scratch-block", @category_class, @shape_class, @c_block_join_class]}>
        <span :if={@show_green_flag_icon} class="inline-flex shrink-0 items-center justify-center">
          <svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true">
            <image
              height="24px"
              width="24px"
              href="/blocks-media/default/green-flag.svg"
            >
            </image>
          </svg>
        </span>
        <img :if={@show_extension_icon} src={@microbit_icon_uri} alt="" class="h-5 w-5 shrink-0" />
        <%= for item <- @items do %>
          <.scratch_block_item item={item} />
        <% end %>
      </div>
      <%= if Enum.any?(@block.children || []) do %>
        <%= if @c_block? do %>
          <div class="scratch-c-block-frame">
            <div class="scratch-c-block-scope" style={"--c-block-accent: #{scratch_category_hex(assigns.block.category)}"}>
              <%= for child <- @block.children do %>
                <div class="mb-2 last:mb-0">
                  <%= if child_name = scratch_child_name(child.name) do %>
                    <div class="scratch-block-child-label scratch-block-child-label--c-block">{child_name}</div>
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
                  <div class="scratch-block-child-label">{child_name}</div>
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
  def scratch_block_item(assigns) do
    assigns = assign(assigns, :item_class, scratch_block_item_class(assigns.item))

    ~H"""
    <%= case @item.kind do %>
      <% :label -> %><span class={@item_class}>{@item.value}</span>
      <% :definition_name -> %><span class={@item_class}>{@item.value}</span>
      <% :field -> %><span class={@item_class}>{@item.value}</span>
      <% :input when is_map(@item.value) and @item.value.kind == :block -> %>
        <%= if inline_block_without_slot_wrapper?(@item) do %>
          <.scratch_inline_block block={@item.value.block} />
        <% else %>
          <span :if={Map.get(@item.value, :nested_logical, false)} class="scratch-nested-group-mark">(</span>
          <.scratch_inline_block block={@item.value.block} nested={Map.get(@item.value, :nested_logical, false)} />
          <span :if={Map.get(@item.value, :nested_logical, false)} class="scratch-nested-group-mark">)</span>
        <% end %>
      <% :input -> %><span class={@item_class}>{scratch_input_text(@item.value)}</span>
    <% end %>
    """
  end

  attr :block, :map, required: true
  attr :nested, :boolean, default: false
  def scratch_inline_block(assigns) do
    shape_class =
      if assigns.block.opcode == "looks_costume" do
        nil
      else
        inline_shape_class(assigns.block.shape)
      end

    assigns =
      assigns
      |> assign(:category_class, scratch_category_class(assigns.block.category))
      |> assign(:shape_class, shape_class)
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))
      |> assign(
        :show_extension_icon,
        assigns.block.category == :extension and
          assigns.block.opcode not in ["microbit_menu_buttons", "microbit_menu_tiltDirectionAny"]
      )
      |> assign(:microbit_icon_uri, @microbit_icon_uri)
      |> assign(:nested_class, if(assigns.nested, do: "scratch-inline-block--nested", else: nil))

    ~H"""
    <span class={["scratch-inline-block", @category_class, @shape_class, @nested_class]}>
      <img :if={@show_extension_icon} src={@microbit_icon_uri} alt="" class="h-4 w-4 shrink-0" />
      <%= for item <- @items do %>
        <.scratch_block_item item={item} />
      <% end %>
    </span>
    """
  end

  defp scratch_block_item_class(%{kind: :label}), do: "scratch-block-item-label"
  defp scratch_block_item_class(%{kind: :definition_name}), do: "scratch-block-item-definition-name"
  defp scratch_block_item_class(%{kind: :field, parent_opcode: "looks_costume"}),
    do: "scratch-block-item-field scratch-slot--round"
  defp scratch_block_item_class(%{kind: :field}), do: "scratch-block-item-field"
  defp scratch_block_item_class(%{kind: :input, name: "BROADCAST_INPUT"}), do: "scratch-block-item-field"
  defp scratch_block_item_class(%{kind: :input, value: %{kind: :block, nested_logical: true}, slot: slot}),
    do: "#{scratch_slot_class(slot, :block)} scratch-slot--nested-logical"
  defp scratch_block_item_class(%{kind: :input, value: %{kind: :block}, slot: slot}), do: scratch_slot_class(slot, :block)
  defp scratch_block_item_class(%{kind: :input, slot: slot, value: value}) do
    [scratch_slot_class(slot, :literal), scratch_input_semantic_class(value), scratch_slot_category_semantic_class(slot, value, :input)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp scratch_slot_class(:boolean, :literal), do: "scratch-slot scratch-slot--boolean scratch-slot--literal"
  defp scratch_slot_class(:boolean, :block), do: "scratch-slot scratch-slot--boolean scratch-slot--block"
  defp scratch_slot_class(:round, :literal), do: "scratch-slot scratch-slot--round scratch-slot--literal"
  defp scratch_slot_class(:round, :block), do: "scratch-slot scratch-slot--round scratch-slot--block"
  defp scratch_slot_class(_, :literal), do: "scratch-slot scratch-slot--literal"
  defp scratch_slot_class(_, :block), do: "scratch-slot scratch-slot--block"
  defp scratch_input_semantic_class(%{kind: :literal, input_type: input_type}) when input_type in [12, 13], do: "scratch-slot--data-ref"
  defp scratch_input_semantic_class(%{"kind" => "literal", "input_type" => input_type}) when input_type in [12, 13], do: "scratch-slot--data-ref"
  defp scratch_input_semantic_class(_), do: nil
  defp scratch_slot_category_semantic_class(:round, %{parent_category: :event}, :input), do: "scratch-slot--event-literal"
  defp scratch_slot_category_semantic_class(_, _, _), do: nil
  defp annotate_items(items, %{category: category, opcode: opcode}) when is_list(items),
    do: Enum.map(items, &( &1 |> Map.put(:parent_category, category) |> Map.put(:parent_opcode, opcode)))
  defp annotate_items(items, %{category: category}) when is_list(items), do: Enum.map(items, &Map.put(&1, :parent_category, category))
  defp annotate_items(items, _), do: items

  defp scratch_block_items(%{opcode: "procedures_definition"} = block) do
    case detail_block_label(block.label) do
      label when is_binary(label) and label != "" -> [%{kind: :label, value: "定義 "}, %{kind: :definition_name, value: label}]
      _ -> [%{kind: :label, value: "定義"}]
    end
  end
  defp scratch_block_items(%{opcode: "data_setvariableto"} = block) do
    label = detail_block_label(block.label)
    if is_binary(label) and label != "", do: BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{}), else: []
  end
  defp scratch_block_items(block) do
    label = detail_block_label(block.label)
    if is_binary(label) and label != "", do: BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{}), else: []
  end

  defp detail_block_label(label) when is_binary(label) do
    label
    |> String.trim_leading()
    |> normalize_extension_menu_label()
  end
  defp detail_block_label(label), do: label

  # Fallback normalization for extension menu reporter labels.
  # Some projects expose opcode text directly as label.
  defp normalize_extension_menu_label("microbit_menu_buttons"), do: "[BTN]"
  defp normalize_extension_menu_label("microbit_menu_tiltDirectionAny"), do: "[DIRECTION]"
  defp normalize_extension_menu_label(label), do: label
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
  defp scratch_category_class(:extension), do: "bg-[#0FBD8C]"
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
  defp scratch_category_hex(:extension), do: "#0FBD8C"
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
  defp scratch_child_container_class(:c_block), do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem] rounded-b-[1.25rem] bg-inherit pr-1"
  defp scratch_child_container_class(_), do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem]"
  defp scratch_child_name("SUBSTACK"), do: nil
  defp scratch_child_name("SUBSTACK2"), do: "でなければ"
  defp scratch_child_name(_), do: nil
  defp inline_block_without_slot_wrapper?(%{kind: :input, value: %{kind: :block, block: %{opcode: "sound_sounds_menu"}}}), do: true
  defp inline_block_without_slot_wrapper?(%{kind: :input, value: %{kind: :block, block: %{opcode: "looks_costume"}}}), do: true
  defp inline_block_without_slot_wrapper?(%{kind: :input, value: %{kind: :block, block: %{opcode: "microbit_menu_buttons"}}}), do: true
  defp inline_block_without_slot_wrapper?(%{kind: :input, value: %{kind: :block, block: %{opcode: "microbit_menu_tiltDirectionAny"}}}), do: true
  defp inline_block_without_slot_wrapper?(%{kind: :input, value: %{kind: :block, block: %{shape: shape}}}) when shape in [:round, :reporter_round], do: true
  defp inline_block_without_slot_wrapper?(_), do: false
  defp c_block_join_class(%{shape: :c_block, children: children}) when is_list(children), do: if(Enum.any?(children), do: "scratch-c-block-head-joined", else: nil)
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
      [] -> fallback_custom_args(fields, inputs)
      _ -> names |> Enum.with_index() |> Enum.map(fn {name, index} -> %{name: normalize_custom_arg_name(name, index), default: Enum.at(defaults, index)} end)
    end
  end
  defp custom_block_arguments(_), do: []
  defp fallback_custom_args(fields, inputs) do
    field_args = Enum.map(fields, fn field -> %{name: "field:#{field.name}", default: field.value} end)
    input_args = Enum.map(inputs, fn input -> %{name: "input:#{input.name}", default: scratch_input_text(input.value)} end)
    field_args ++ input_args
  end
  defp mutation_array(mutation, key) when is_map(mutation) do
    case Map.get(mutation, key) do
      value when is_list(value) -> Enum.map(value, &to_string/1)
      value when is_binary(value) -> case Jason.decode(value) do {:ok, list} when is_list(list) -> Enum.map(list, &to_string/1); _ -> [] end
      _ -> []
    end
  end
  defp normalize_custom_arg_name(name, _index) when is_binary(name) and name != "", do: name
  defp normalize_custom_arg_name(_name, index), do: "arg#{index + 1}"

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
