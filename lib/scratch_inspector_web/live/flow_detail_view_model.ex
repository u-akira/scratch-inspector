defmodule ScratchInspectorWeb.FlowDetailViewModel do
  @moduledoc false

  def build(_project, _target, nil), do: empty()
  def build(_project, nil, _flow_detail), do: empty()

  def build(project, target, flow_detail) do
    case flow_detail do
      %{kind: "script", id: id} ->
        case Enum.find(target.top_scripts, &(&1.id == id)) do
          nil ->
            empty()

          script ->
            %{
              detail_script: %{
                kind: :script,
                source: script,
                header: Map.get(script, :detail_header),
                blocks: Map.get(script, :detail_blocks, [])
              },
              detail_title: script.hat_label,
              detail_receivers: nil
            }
        end

      %{kind: "block_def", id: name} ->
        case Enum.find(target.custom_blocks, &(&1.name == name)) do
          nil ->
            empty()

          block_def ->
            %{
              detail_script: %{
                kind: :custom_block,
                source: block_def,
                header: Map.get(block_def, :detail_header),
                blocks: Map.get(block_def, :detail_blocks, [])
              },
              detail_title: name,
              detail_receivers: nil
            }
        end

      %{kind: "broadcast", id: msg} ->
        %{
          detail_script: nil,
          detail_title: ~s(Scripts that receive "#{msg}"),
          detail_receivers:
            Enum.map(find_broadcast_receivers(project, msg), fn {receiver_target, script} ->
              %{
                target: receiver_target,
                script: script,
                detail: %{
                  kind: "script",
                  id: script.id,
                  sprite: receiver_target.name,
                  type: receiver_type(receiver_target)
                }
              }
            end)
        }

      _ ->
        empty()
    end
  end

  defp empty do
    %{
      detail_script: nil,
      detail_title: nil,
      detail_receivers: nil
    }
  end

  defp find_broadcast_receivers(project, msg) do
    all_targets = Enum.filter([project.stage | project.sprites], & &1)

    Enum.flat_map(all_targets, fn target ->
      target.top_scripts
      |> Enum.filter(fn script ->
        script.hat_opcode == "event_whenbroadcastreceived" and
          script_receives_broadcast?(script.hat_label, msg)
      end)
      |> Enum.map(fn script -> {target, script} end)
    end)
  end

  defp script_receives_broadcast?(hat_label, msg)
       when is_binary(hat_label) and is_binary(msg) and msg != "" do
    String.contains?(hat_label, msg)
  end

  defp script_receives_broadcast?(_, _), do: false

  defp receiver_type(%{is_stage: true}), do: "stage"
  defp receiver_type(_), do: "sprite"
end
