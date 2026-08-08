defmodule ScratchInspectorWeb.Live.DeferredTargetCompactor do
  @moduledoc false

  @detail_inline_depth_limit 4

  def compact_for_message(target) do
    target
    |> Map.put(:costumes, [])
    |> Map.put(:sounds, [])
    |> compact(nil)
  end

  def compact(target, previous) do
    target
    |> Map.put(:costumes, Map.get(previous || %{}, :costumes, Map.get(target, :costumes, [])))
    |> Map.put(:sounds, Map.get(previous || %{}, :sounds, Map.get(target, :sounds, [])))
    |> Map.update(:top_scripts, [], fn scripts -> Enum.map(scripts, &compact_detail_script/1) end)
    |> Map.update(:custom_blocks, [], fn custom_blocks ->
      Enum.map(custom_blocks, &compact_detail_script/1)
    end)
  end

  defp compact_detail_script(script) do
    script
    |> Map.put(:render_blocks, [])
    |> Map.update(:detail_header, nil, &compact_detail_block(&1, @detail_inline_depth_limit))
    |> Map.update(:detail_blocks, [], &compact_detail_blocks(&1, @detail_inline_depth_limit))
  end

  defp compact_detail_blocks(blocks, depth) when is_list(blocks),
    do: Enum.map(blocks, &compact_detail_block(&1, depth))

  defp compact_detail_blocks(_, _depth), do: []

  defp compact_detail_block(nil, _depth), do: nil

  defp compact_detail_block(block, depth) when is_map(block) and depth <= 0 do
    block
    |> Map.take([:id, :opcode, :category, :shape, :label, :mutation, :reference])
    |> Map.put(:reference, true)
    |> Map.put(:fields, [])
    |> Map.put(:inputs, [])
    |> Map.put(:children, [])
  end

  defp compact_detail_block(block, depth) when is_map(block) do
    block
    |> Map.drop([:parts, :branches])
    |> Map.update(:inputs, [], &compact_detail_inputs(&1, depth - 1))
    |> Map.update(:children, [], &compact_detail_children(&1, depth - 1))
  end

  defp compact_detail_inputs(inputs, depth) when is_list(inputs),
    do: Enum.map(inputs, &compact_detail_input(&1, depth))

  defp compact_detail_inputs(_, _depth), do: []

  defp compact_detail_input(%{value: %{kind: :block, block: child}} = input, depth)
       when is_map(child) and depth <= 0 do
    Map.put(input, :value, %{
      kind: :reference,
      id: Map.get(child, :id),
      label: Map.get(child, :label) || Map.get(child, :opcode)
    })
  end

  defp compact_detail_input(%{value: %{kind: :block, block: child} = value} = input, depth)
       when is_map(child) do
    Map.put(input, :value, Map.put(value, :block, compact_detail_block(child, depth)))
  end

  defp compact_detail_input(input, _depth), do: input

  defp compact_detail_children(children, depth) when is_list(children) do
    Enum.map(children, fn
      %{blocks: blocks} = child -> Map.put(child, :blocks, compact_detail_blocks(blocks, depth))
      child -> child
    end)
  end

  defp compact_detail_children(_, _depth), do: []
end
