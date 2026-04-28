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

  def build_flow_mermaid(project, target, flow_detail) do
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
    do:
      InspectorEvents.flow_detail_same?(
        InspectorEvents.normalize_flow_detail(current),
        InspectorEvents.normalize_flow_detail(detail)
      )

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

    if String.contains?(label, "<img ") do
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
    ~s(<img src="/blocks-media/default/green-flag.svg" width="1em" height="1em" style="display:inline-block;width:1em;height:1em;max-width:none;vertical-align:-0.12em;margin-right:0.28em;" />が押されたとき)
  end

  defp flow_node_label(script), do: script.hat_label

  defp mermaid_class(:script), do: "scriptNode"
  defp mermaid_class(:block_def), do: "blockNode"
  defp mermaid_class(:broadcast), do: "broadcastNode"
  defp mermaid_class(:receiver_script), do: "receiverNode"

  defp event_hat?(opcode), do: opcode in @event_hat_opcodes

  defp display_name(%{is_stage: true}), do: "背景"
  defp display_name(%{name: name}), do: name
end
