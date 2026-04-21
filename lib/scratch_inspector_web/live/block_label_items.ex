defmodule ScratchInspectorWeb.Live.BlockLabelItems do
  @moduledoc false

  @placeholder_split ~r/(\[[A-Z0-9_]+\])/
  @placeholder_capture ~r/^\[([A-Z0-9_]+)\]$/

  def parse(label, fields, inputs) when is_binary(label) do
    Regex.split(@placeholder_split, label, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&part_to_item(&1, fields, inputs))
  end

  def parse(_, _, _), do: []

  defp part_to_item(part, fields, inputs) do
    case Regex.run(@placeholder_capture, part) do
      [_, placeholder] ->
        field = resolve_by_name(fields, placeholder)
        input = resolve_by_name(inputs, placeholder)

        case normalize_field_item(placeholder, field) || normalize_input_item(placeholder, input) do
          nil -> %{kind: :label, value: part}
          item -> item
        end

      _ ->
        %{kind: :label, value: part}
    end
  end

  defp normalize_field_item(name, field) when is_map(field) do
    case fetch_value(field) do
      {:ok, value} -> %{kind: :field, name: name, value: value}
      :error -> nil
    end
  end

  defp normalize_field_item(_name, _field), do: nil

  defp normalize_input_item(name, input) when is_map(input) do
    case {fetch_slot(input), fetch_value(input)} do
      {{:ok, slot}, {:ok, value}} ->
        %{kind: :input, name: name, slot: slot, value: value}

      {:error, {:ok, value}} ->
        # Fallback for malformed input maps without slot.
        %{kind: :input, name: name, slot: :round, value: value}

      _ ->
        nil
    end
  end

  defp normalize_input_item(_name, _input), do: nil

  defp fetch_slot(map) do
    cond do
      Map.has_key?(map, :slot) -> {:ok, Map.get(map, :slot)}
      Map.has_key?(map, "slot") -> {:ok, Map.get(map, "slot")}
      true -> :error
    end
  end

  defp fetch_value(map) do
    cond do
      Map.has_key?(map, :value) -> {:ok, Map.get(map, :value)}
      Map.has_key?(map, "value") -> {:ok, Map.get(map, "value")}
      true -> :error
    end
  end

  defp resolve_by_name(collection, name) when is_map(collection), do: Map.get(collection, name)

  defp resolve_by_name(collection, name) when is_list(collection) do
    Enum.find(collection, fn
      %{} = item -> entry_name(item) == name
      _ -> false
    end)
  end

  defp resolve_by_name(_, _), do: nil

  defp entry_name(entry) when is_map(entry) do
    Map.get(entry, :name) || Map.get(entry, "name")
  end
end
