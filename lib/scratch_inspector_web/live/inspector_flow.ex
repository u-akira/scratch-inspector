defmodule ScratchInspectorWeb.Live.InspectorFlow do
  alias ScratchInspectorWeb.Live.InspectorEvents

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

  def build_flow_mermaid(_project, nil, _flow_detail), do: nil

  def build_flow_mermaid(project, target, _flow_detail) do
    scripts =
      target.top_scripts
      |> Enum.filter(&event_hat?(&1.hat_opcode))

    custom_blocks = target.custom_blocks

    script_nodes =
      scripts
      |> Enum.with_index(1)
      |> Enum.map(fn {script, idx} ->
        %{
          id: "script_#{idx}",
          detail:
            flow_detail_payload(
              %{
                kind: "script",
                id: script.id,
                hat_opcode: script.hat_opcode,
                hat_label: script.hat_label
              },
              target
            ),
          label: flow_node_label(script),
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
          label: custom_block_flow_label(block_def),
          class: :block_def,
          block_def: block_def
        }
      end)

    block_node_ids = Map.new(block_nodes, fn node -> {node.block_def.name, node.id} end)

    broadcast_messages =
      ((scripts |> Enum.flat_map(&broadcasts_sent_in_script(&1.blocks))) ++
         (custom_blocks |> Enum.flat_map(&broadcasts_sent_in_script(&1.code_blocks))))
      |> Enum.uniq()

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
              label: receiver_label(receiver_target, script),
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
          |> Enum.flat_map(fn msg ->
            find_broadcast_receivers(project, msg)
            |> Enum.map(fn {receiver_target, script} ->
              to_id =
                Map.get(
                  receiver_node_ids,
                  {receiver_target.name, receiver_target.is_stage, script.id}
                )

              {node.id, to_id}
            end)
          end)

        called_edges ++ broadcast_edges
      end)

    block_edges =
      Enum.flat_map(block_nodes, fn node ->
        call_edges =
          direct_calls_from_block_def(node.block_def, custom_blocks)
          |> Enum.map(fn sub_cb -> {node.id, Map.get(block_node_ids, sub_cb.name)} end)

        broadcast_edges =
          broadcasts_sent_in_script(node.block_def.code_blocks)
          |> Enum.flat_map(fn msg ->
            find_broadcast_receivers(project, msg)
            |> Enum.map(fn {receiver_target, script} ->
              to_id =
                Map.get(
                  receiver_node_ids,
                  {receiver_target.name, receiver_target.is_stage, script.id}
                )

              {node.id, to_id}
            end)
          end)

        call_edges ++ broadcast_edges
      end)

    nodes =
      script_nodes ++ block_nodes ++ Enum.reject(receiver_nodes, &is_nil/1)

    edges =
      (script_edges ++ block_edges)
      |> Enum.reject(fn {from_id, to_id} -> is_nil(from_id) or is_nil(to_id) end)
      |> Enum.uniq()

    if Enum.empty?(nodes), do: nil, else: render_flow_mermaid(nodes, edges)
  end

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

  defp direct_calls_from_block_def(cb, all_custom_blocks) do
    cb.code_blocks
    |> Enum.filter(fn b -> b.opcode == "procedures_call" end)
    |> Enum.map(fn b -> String.replace_prefix(b.label, "📞 ", "") end)
    |> Enum.uniq()
    |> Enum.map(fn name -> Enum.find(all_custom_blocks, &(&1.name == name)) end)
    |> Enum.reject(&is_nil/1)
  end

  defp render_flow_mermaid(nodes, edges) do
    header = [
      "flowchart LR",
      "classDef scriptNode fill:#FFAB19,stroke:#CC8813,color:#ffffff,stroke-width:2px;",
      "classDef blockNode fill:#FF6680,stroke:#D64C68,color:#ffffff,stroke-width:2px;",
      "classDef receiverNode fill:#ffffff,stroke:#4C97FF,color:#1f2937,stroke-width:2px;"
    ]

    body =
      Enum.flat_map(nodes, fn node ->
        payload = mermaid_payload(node.detail)

        [
          ~s(#{node.id}["#{escape_mermaid_label(node.label)}"]),
          "class #{node.id} #{mermaid_class(node.class)};"
        ] ++ ["click #{node.id} call __mermaidNodeClick(\"#{payload}\")"]
      end)

    edge_lines = Enum.map(edges, fn {from_id, to_id} -> "#{from_id} --> #{to_id}" end)

    Enum.join(header ++ body ++ edge_lines, "\n")
  end

  defp flow_detail_payload(detail, target) do
    InspectorEvents.normalize_flow_detail(%{
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
    label = to_string(label || "")

    if String.contains?(label, "<img ") or String.contains?(label, "<span ") do
      label
      |> String.replace("\n", "<br/>")
    else
      escape_plain_mermaid_label(label)
    end
  end

  defp escape_plain_mermaid_label(label) do
    label
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("&lt;br/&gt;", "<br/>")
    |> String.replace("\n", "<br/>")
  end

  defp flow_node_label(%{hat_opcode: "event_whenflagclicked"}) do
    ~s(<span class='scratch-flow-flag-label'><img src='/blocks-media/default/green-flag.svg' width='16' height='16' />が押されたとき</span>)
  end

  defp flow_node_label(script), do: script.hat_label

  defp custom_block_flow_label(%{
         detail_header: %{mutation: mutation, label: fallback},
         name: name
       })
       when is_map(mutation) do
    proccode = Map.get(mutation, "proccode")
    names = mutation_array(mutation, "argumentnames")

    case custom_block_flow_label_from_proccode(proccode, names) do
      "" -> fallback || name
      label -> label
    end
  end

  defp custom_block_flow_label(%{detail_header: %{label: label}, name: name}), do: label || name
  defp custom_block_flow_label(%{name: name}), do: name

  defp custom_block_flow_label_from_proccode(proccode, names)
       when is_binary(proccode) and is_list(names) and names != [] do
    {items, used_arg?} =
      Regex.split(~r/(%[sbn])/, proccode, include_captures: true)
      |> Enum.map_reduce({names, false}, fn
        <<"%"::binary, _type::binary-size(1)>> = placeholder, {[name | rest], _used_arg?} ->
          arg = if is_binary(name) and name != "", do: name, else: placeholder
          {flow_arg_span(arg), {rest, true}}

        <<"%"::binary, _type::binary-size(1)>> = placeholder, {[], _used_arg?} ->
          {flow_arg_span(placeholder), {[], true}}

        text, {remaining_names, used_arg?} ->
          {escape_inline_text(text), {remaining_names, used_arg?}}
      end)

    if used_arg?, do: Enum.join(items), else: ""
  end

  defp custom_block_flow_label_from_proccode(_, _), do: ""

  defp flow_arg_span(value) do
    escaped = escape_inline_text(value)

    ~s(<span class='scratch-flow-arg-pill'>#{escaped}</span>)
  end

  defp receiver_label(target, %{hat_opcode: "event_whenbroadcastreceived"} = script) do
    "#{display_name(target)}<br/>#{broadcast_receiver_event_html(script)}"
  end

  defp receiver_label(target, script) do
    "#{display_name(target)}<br/>#{script.hat_label}"
  end

  defp mermaid_class(:script), do: "scriptNode"
  defp mermaid_class(:block_def), do: "blockNode"
  defp mermaid_class(:receiver_script), do: "receiverNode"

  defp event_hat?(opcode), do: opcode in @event_hat_opcodes

  defp display_name(%{is_stage: true}), do: "背景"
  defp display_name(%{name: name}), do: name

  defp broadcast_receiver_event_label(%{hat_label: hat_label}) when is_binary(hat_label) do
    case Regex.run(~r/^(.*)を受け取ったとき$/, hat_label) do
      [_, msg] when msg != "" -> msg
      _ -> hat_label
    end
  end

  defp broadcast_receiver_event_label(_), do: ""

  defp broadcast_receiver_event_html(script) do
    msg = escape_inline_text(broadcast_receiver_event_label(script))
    ~s(<span style="font-size:0.82em;color:#6b7280;">#{msg}</span>)
  end

  defp escape_inline_text(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
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

  defp mutation_array(_, _), do: []
end
