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

    ~H"""
    <div class="scratch-detail-panel">
      <div class="min-w-full w-max">
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

  attr :block, :map, required: true

  def scratch_block(assigns) do
    assigns =
      assigns
      |> assign(:category_class, scratch_category_class(assigns.block.category))
      |> assign(:category_style, scratch_category_style(assigns.block.category))
      |> assign(:category_theme_class, scratch_category_theme_class(assigns.block.category))
      |> assign(:semantic_class, scratch_semantic_class(assigns.block))
      |> assign(:shape_class, scratch_shape_class(assigns.block.shape))
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))
      |> assign(:child_container_class, scratch_child_container_class(assigns.block.shape))
      |> assign(:c_block?, assigns.block.shape == :c_block)
      |> assign(:show_green_flag_icon, assigns.block.opcode == "event_whenflagclicked")
      |> assign(:show_extension_icon, assigns.block.category == :extension)
      |> assign(:show_toio_icon, toio_icon_block?(assigns.block))
      |> assign(:microbit_icon_uri, @microbit_icon_uri)
      |> assign(:c_block_join_class, c_block_join_class(assigns.block))

    ~H"""
    <div class="flex w-max max-w-none flex-col items-start">
      <div
        class={[
          "scratch-block",
          @category_class,
          @category_theme_class,
          @semantic_class,
          @shape_class,
          @c_block_join_class
        ]}
        style={@category_style}
      >
        <span :if={@show_green_flag_icon} class="inline-flex shrink-0 items-center justify-center">
          <svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true">
            <image height="24px" width="24px" href="/blocks-media/default/green-flag.svg"></image>
          </svg>
        </span>
        <img :if={@show_extension_icon} src={@microbit_icon_uri} alt="" class="h-5 w-5 shrink-0" />
        <.toio_icon
          :if={@show_toio_icon}
          class="scratch-block-icon scratch-block-icon--toio h-5 w-5 shrink-0"
        />
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
                    <div class="scratch-block-child-label scratch-block-child-label--c-block">
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
      <% :label -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :definition_name -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :definition_arg -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :field -> %>
        <span class={@item_class}>{@item.value}</span>
      <% :input when is_map(@item.value) and @item.value.kind == :block -> %>
        <%= if scratch_timer_input?(@item) do %>
          <span class={@item_class}>
            <.timer_icon />
            <.scratch_inline_block
              block={@item.value.block}
              nested={Map.get(@item.value, :nested_logical, false)}
            />
          </span>
        <% else %>
          <%= if inline_block_without_slot_wrapper?(@item) do %>
            <.scratch_inline_block block={@item.value.block} />
          <% else %>
            <span :if={Map.get(@item.value, :nested_logical, false)} class="scratch-nested-group-mark">
              (
            </span>

            <.scratch_inline_block
              block={@item.value.block}
              nested={Map.get(@item.value, :nested_logical, false)}
            />
            <span :if={Map.get(@item.value, :nested_logical, false)} class="scratch-nested-group-mark">
              )
            </span>
          <% end %>
        <% end %>
      <% :input -> %>
        <%= if color = scratch_color_input_value(@item) do %>
          <span class="scratch-color-input" style={"--scratch-color-value: #{color};"}>
            <span class="scratch-color-input__swatch"></span>
          </span>
        <% else %>
          <%= if scratch_timer_input?(@item) do %>
            <span class={@item_class}>
              <.timer_icon /> <span>{scratch_input_text(@item.value)}</span>
            </span>
          <% else %>
            <span class={@item_class}>{scratch_input_text(@item.value)}</span>
          <% end %>
        <% end %>
    <% end %>
    """
  end

  defp timer_icon(assigns) do
    ~H"""
    <svg class="scratch-timer-icon h-3.5 w-3.5 shrink-0" viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8.7" r="5.2" fill="#EEF3F8" stroke="#5F6368" stroke-width="1.2" />
      <path d="M6.1 1.8h3.8" stroke="#5F6368" stroke-width="1.4" stroke-linecap="round" />
      <path d="M8 3.5V2.2" stroke="#5F6368" stroke-width="1.2" stroke-linecap="round" />
      <path d="M8 8.7V5.8M8 8.7l2.1 1.2" stroke="#5F6368" stroke-width="1.2" stroke-linecap="round" />
    </svg>
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
      |> assign(:category_style, scratch_category_style(assigns.block.category))
      |> assign(:category_theme_class, scratch_category_theme_class(assigns.block.category))
      |> assign(:semantic_class, scratch_semantic_class(assigns.block))
      |> assign(:shape_class, shape_class)
      |> assign(:items, scratch_block_items(assigns.block) |> annotate_items(assigns.block))
      |> assign(
        :show_extension_icon,
        assigns.block.category == :extension and
          assigns.block.opcode not in ["microbit_menu_buttons", "microbit_menu_tiltDirectionAny"]
      )
      |> assign(:show_toio_icon, toio_icon_block?(assigns.block))
      |> assign(:microbit_icon_uri, @microbit_icon_uri)
      |> assign(:nested_class, if(assigns.nested, do: "scratch-inline-block--nested", else: nil))

    ~H"""
    <span
      class={[
        "scratch-inline-block",
        @category_class,
        @category_theme_class,
        @semantic_class,
        @shape_class,
        @nested_class
      ]}
      style={@category_style}
    >
      <img :if={@show_extension_icon} src={@microbit_icon_uri} alt="" class="h-4 w-4 shrink-0" />
      <.toio_icon
        :if={@show_toio_icon}
        class="scratch-block-icon scratch-block-icon--toio h-4 w-4 shrink-0"
      />
      <%= for item <- @items do %>
        <.scratch_block_item item={item} />
      <% end %>
    </span>
    """
  end

  attr :class, :string, required: true

  defp toio_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 20 20" role="img" aria-label="toio">
      <path
        d="M2.1 7.1 6.4 2.2c.3-.4.8-.6 1.3-.5l9 1.6c.5.1.9.5.8 1.1l-.4 6.5c0 .4-.2.7-.4 1l-3.9 5.3c-.3.4-.8.6-1.3.5L2.8 16c-.5-.1-.9-.5-.9-1l-.2-6.7c0-.4.1-.8.4-1.2Z"
        fill="#fff"
        stroke="#5C5142"
        stroke-width="0.8"
        stroke-linejoin="round"
      />
      <path
        d="M2.1 7.4 11.7 9l5.5-5.3"
        fill="none"
        stroke="#5C5142"
        stroke-width="0.7"
        stroke-linecap="round"
      />
      <path d="M11.7 9v8.1" fill="none" stroke="#5C5142" stroke-width="0.7" stroke-linecap="round" />
      <path
        d="M5.4 11.8c.9-.7 2.1-.5 2.8.3M13.1 12.5c.7-.6 1.6-.5 2.1.1"
        fill="none"
        stroke="#BEB5AA"
        stroke-width="1.1"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  defp scratch_block_item_class(%{kind: :label}), do: "scratch-block-item-label"

  defp scratch_block_item_class(%{kind: :definition_name}),
    do: "scratch-block-item-definition-name"

  defp scratch_block_item_class(%{kind: :definition_arg}),
    do: "scratch-block-item-definition-arg"

  defp scratch_block_item_class(%{kind: :field, parent_opcode: "looks_costume"}),
    do: "scratch-block-item-field scratch-slot--round"

  defp scratch_block_item_class(%{kind: :field}), do: "scratch-block-item-field"

  defp scratch_block_item_class(%{kind: :input, name: "BROADCAST_INPUT"}),
    do: "scratch-block-item-field"

  defp scratch_block_item_class(%{
         kind: :input,
         value: %{kind: :block, nested_logical: true},
         slot: slot
       }),
       do: "#{scratch_slot_class(slot, :block)} scratch-slot--nested-logical"

  defp scratch_block_item_class(%{kind: :input, value: %{kind: :block}, slot: slot}),
    do: scratch_slot_class(slot, :block)

  defp scratch_block_item_class(%{kind: :input, slot: slot, value: value}) do
    [
      scratch_slot_class(slot, :literal),
      scratch_input_semantic_class(value),
      scratch_slot_category_semantic_class(slot, value, :input)
    ]
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

  defp scratch_slot_class(_, :literal), do: "scratch-slot scratch-slot--literal"
  defp scratch_slot_class(_, :block), do: "scratch-slot scratch-slot--block"

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

  defp annotate_items(items, %{category: category, opcode: opcode}) when is_list(items),
    do:
      Enum.map(
        items,
        &(&1 |> Map.put(:parent_category, category) |> Map.put(:parent_opcode, opcode))
      )

  defp annotate_items(items, %{category: category}) when is_list(items),
    do: Enum.map(items, &Map.put(&1, :parent_category, category))

  defp annotate_items(items, _), do: items

  defp scratch_block_items(%{opcode: "procedures_definition"} = block) do
    case detail_block_label(block.label) do
      label when is_binary(label) and label != "" ->
        [%{kind: :label, value: "定義"}] ++ custom_definition_items(block, label)

      _ ->
        [%{kind: :label, value: "定義"}]
    end
  end

  defp scratch_block_items(%{opcode: "procedures_call"} = block) do
    label = detail_block_label(block.label)

    case custom_call_items(block, label) do
      [] ->
        if is_binary(label) and label != "",
          do: BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{}),
          else: []

      items ->
        items
    end
  end

  defp scratch_block_items(%{opcode: "data_setvariableto"} = block) do
    label = detail_block_label(block.label)

    if is_binary(label) and label != "",
      do: BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{}),
      else: []
  end

  defp scratch_block_items(block) do
    label = detail_block_label(block.label)

    if is_binary(label) and label != "",
      do: BlockLabelItems.parse(label, block.fields || %{}, block.inputs || %{}),
      else: []
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
  defp normalize_extension_menu_label("looks_backdrops"), do: "[BACKDROP]"
  defp normalize_extension_menu_label("sensing_of_object_menu"), do: "[OBJECT]"
  defp normalize_extension_menu_label("toio_menu_moveDirections"), do: "[DIRECTION]"
  defp normalize_extension_menu_label("toio_menu_rotateDirections"), do: "[DIRECTION]"
  defp normalize_extension_menu_label("toio2_menu_moveDirections"), do: "[DIRECTION]"
  defp normalize_extension_menu_label("toio2_menu_rotateDirections"), do: "[DIRECTION]"
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
  defp scratch_category_class(:toio), do: "bg-[#00AECA]"
  defp scratch_category_class(:toio_do), do: "bg-[#F05B4F]"
  defp scratch_category_class(_), do: "bg-slate-500"

  defp scratch_semantic_class(%{opcode: opcode})
       when opcode in ["argument_reporter_boolean", "argument_reporter_string_number"],
       do: "scratch-argument-reporter"

  defp scratch_semantic_class(_), do: nil
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
  defp scratch_category_hex(:toio), do: "#00AECA"
  defp scratch_category_hex(:toio_do), do: "#F05B4F"
  defp scratch_category_hex(_), do: "#64748B"

  defp scratch_category_style(:toio_do) do
    "--scratch-block-color: #f05b4f; --scratch-block-secondary: #d94a41; --scratch-block-tertiary: #c93f38;"
  end

  defp scratch_category_style(_), do: nil

  defp scratch_category_theme_class(:toio_do), do: "scratch-block--themed"
  defp scratch_category_theme_class(_), do: nil

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

  defp scratch_child_container_class(:c_block),
    do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem] rounded-b-[1.25rem] bg-inherit pr-1"

  defp scratch_child_container_class(_), do: "ml-5 mt-1.5 w-[calc(100%-1rem)] min-w-[14rem]"
  defp scratch_child_name("SUBSTACK"), do: nil
  defp scratch_child_name("SUBSTACK2"), do: "でなければ"
  defp scratch_child_name(_), do: nil

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: "sound_sounds_menu"}}
       }),
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: "looks_costume"}}
       }),
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: "looks_backdrops"}}
       }),
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: "sensing_of_object_menu"}}
       }),
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: "microbit_menu_buttons"}}
       }),
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: "microbit_menu_tiltDirectionAny"}}
       }),
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: opcode}}
       })
       when opcode in ["toio_menu_moveDirections", "toio_menu_rotateDirections"],
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{opcode: opcode}}
       })
       when opcode in ["toio2_menu_moveDirections", "toio2_menu_rotateDirections"],
       do: true

  defp inline_block_without_slot_wrapper?(%{
         kind: :input,
         value: %{kind: :block, block: %{shape: shape}}
       })
       when shape in [:round, :reporter_round],
       do: true

  defp inline_block_without_slot_wrapper?(_), do: false

  defp c_block_join_class(%{shape: :c_block, children: children}) when is_list(children),
    do: if(Enum.any?(children), do: "scratch-c-block-head-joined", else: nil)

  defp c_block_join_class(_), do: nil

  defp toio_icon_block?(%{category: :toio_do, opcode: opcode}),
    do:
      opcode not in [
        "toio2_menu_moveDirections",
        "toio2_menu_rotateDirections"
      ]

  defp toio_icon_block?(_), do: false

  defp custom_call_items(block, fallback_label) do
    mutation = Map.get(block, :mutation, %{})
    proccode = Map.get(mutation, "proccode") || fallback_label
    argument_ids = mutation_array(mutation, "argumentids")

    custom_call_items_from_proccode(proccode, argument_ids, block.inputs || [])
  end

  defp custom_call_items_from_proccode(proccode, argument_ids, inputs)
       when is_binary(proccode) and is_list(argument_ids) and argument_ids != [] do
    Regex.split(~r/(%[sbn])/, proccode, include_captures: true)
    |> Enum.map_reduce(argument_ids, fn
      <<"%"::binary, _type::binary-size(1)>> = placeholder, [argument_id | rest] ->
        {custom_call_argument_item(argument_id, placeholder, inputs), rest}

      <<"%"::binary, _type::binary-size(1)>> = placeholder, [] ->
        {%{kind: :label, value: placeholder}, []}

      text, remaining_ids ->
        {%{kind: :label, value: text}, remaining_ids}
    end)
    |> elem(0)
    |> Enum.reject(fn item -> item.value == "" end)
  end

  defp custom_call_items_from_proccode(_, _, _), do: []

  defp custom_call_argument_item(argument_id, placeholder, inputs) do
    case Enum.find(inputs, &(Map.get(&1, :name) == argument_id)) do
      %{slot: slot, value: value} ->
        %{kind: :input, name: argument_id, slot: slot, value: value}

      _ ->
        %{kind: :label, value: placeholder}
    end
  end

  defp custom_definition_items(block, fallback_label) do
    mutation = Map.get(block, :mutation, %{})
    proccode = Map.get(mutation, "proccode")
    names = mutation_array(mutation, "argumentnames")

    case custom_definition_items_from_proccode(proccode, names) do
      [] -> [%{kind: :definition_name, value: fallback_label}]
      items -> items
    end
  end

  defp custom_definition_items_from_proccode(proccode, names)
       when is_binary(proccode) and is_list(names) and names != [] do
    Regex.split(~r/(%[sbn])/, proccode, include_captures: true)
    |> Enum.map_reduce(names, fn
      <<"%"::binary, _type::binary-size(1)>>, [name | rest] ->
        {%{kind: :definition_arg, value: name}, rest}

      <<"%"::binary, _type::binary-size(1)>> = placeholder, [] ->
        {%{kind: :definition_arg, value: placeholder}, []}

      text, remaining_names ->
        {%{kind: :definition_name, value: text}, remaining_names}
    end)
    |> elem(0)
    |> Enum.reject(fn item -> item.value == "" end)
  end

  defp custom_definition_items_from_proccode(_, _), do: []

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

  defp mutation_array(_, _), do: []

  defp scratch_color_input_value(%{kind: :input, name: name, value: value})
       when name in ["COLOR", "COLOR2"] do
    value
    |> scratch_input_text()
    |> normalize_hex_color()
  end

  defp scratch_color_input_value(_), do: nil

  defp scratch_timer_input?(%{kind: :input, name: "DURATION", parent_category: :toio_do}),
    do: true

  defp scratch_timer_input?(_), do: false

  defp normalize_hex_color("#" <> hex) when byte_size(hex) == 6 do
    if Regex.match?(~r/^[0-9a-fA-F]{6}$/, hex), do: "##{String.downcase(hex)}", else: nil
  end

  defp normalize_hex_color(_), do: nil

  defp scratch_input_text(value) do
    case value do
      nil -> ""
      %{kind: :literal, value: literal} when is_binary(literal) -> literal
      %{kind: :literal, value: literal} when is_number(literal) -> to_string(literal)
      %{kind: :reference, label: label} when is_binary(label) -> label
      %{kind: :reference, id: id} when is_binary(id) -> id
      %{"kind" => "literal", "value" => literal} when is_binary(literal) -> literal
      %{"kind" => "literal", "value" => literal} when is_number(literal) -> to_string(literal)
      %{"kind" => "reference", "label" => label} when is_binary(label) -> label
      %{"kind" => "reference", "id" => id} when is_binary(id) -> id
      value when is_binary(value) -> value
      value when is_number(value) -> to_string(value)
      value when is_atom(value) -> to_string(value)
      _ -> inspect(value)
    end
  end
end
