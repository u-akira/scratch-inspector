defmodule ScratchInspectorWeb.Live.InspectorComponents.ScratchBlocks do
  use ScratchInspectorWeb, :html
  alias ScratchInspectorWeb.Live.BlockLabelItems

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
      |> assign(:c_block_join_class, c_block_join_class(assigns.block))

    ~H"""
    <div class="flex flex-col items-start w-full min-w-0">
      <div class={["scratch-block", @category_class, @shape_class, @c_block_join_class]}>
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
                    <div class="scratch-block-child-label">{child_name}</div>
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
          <span class={@item_class}><.scratch_inline_block block={@item.value.block} /></span>
        <% end %>
      <% :input -> %><span class={@item_class}>{scratch_input_text(@item.value)}</span>
    <% end %>
    """
  end

  attr :block, :map, required: true
  def scratch_inline_block(assigns) do
    assigns =
      assigns
      |> assign(:category_class, scratch_category_class(assigns.block.category))
      |> assign(:shape_class, inline_shape_class(assigns.block.shape))
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))

    ~H"""
    <span class={["scratch-inline-block", @category_class, @shape_class]}>
      <%= for item <- @items do %>
        <.scratch_block_item item={item} />
      <% end %>
    </span>
    """
  end

  defp scratch_block_item_class(%{kind: :label}), do: "scratch-block-item-label"
  defp scratch_block_item_class(%{kind: :definition_name}), do: "scratch-block-item-definition-name"
  defp scratch_block_item_class(%{kind: :field}), do: "scratch-block-item-field"
  defp scratch_block_item_class(%{kind: :input, name: "BROADCAST_INPUT"}), do: "scratch-block-item-field"
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

  defp detail_block_label(label) when is_binary(label), do: String.trim_leading(label)
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
  defp scratch_child_container_class(:c_block), do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem] rounded-b-[1.25rem] bg-inherit pr-1"
  defp scratch_child_container_class(_), do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem]"
  defp scratch_child_name("SUBSTACK"), do: nil
  defp scratch_child_name("SUBSTACK2"), do: "else"
  defp scratch_child_name(_), do: nil
  defp inline_block_without_slot_wrapper?(%{kind: :input, value: %{kind: :block, block: %{opcode: "sound_sounds_menu"}}}), do: true
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
