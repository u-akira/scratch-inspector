defmodule ScratchInspectorWeb.Live.InspectorFlowTest do
  use ExUnit.Case, async: true

  alias ScratchInspectorWeb.Live.InspectorFlow

  test "custom block flow nodes render argument names instead of placeholders" do
    target = %{
      name: "Sprite1",
      is_stage: false,
      top_scripts: [],
      custom_blocks: [
        %{
          name: "カードの属性を設定する %s %s %b",
          called_by: [],
          code_blocks: [],
          detail_header: %{
            label: "カードの属性を設定する 種類 枚数 有効か？",
            mutation: %{
              "proccode" => "カードの属性を設定する %s %s %b",
              "argumentnames" => Jason.encode!(["種類", "枚数", "有効か？"])
            }
          }
        }
      ]
    }

    project = %{stage: nil, sprites: [target]}

    mermaid = InspectorFlow.build_flow_mermaid(project, target, nil)

    assert mermaid =~ "カードの属性を設定する"
    assert mermaid =~ "種類"
    assert mermaid =~ "枚数"
    assert mermaid =~ "有効か？"
    assert mermaid =~ "<span class='scratch-flow-arg-pill'>"
    refute mermaid =~ "%s"
    refute mermaid =~ "%b"
  end

  test "green flag flow node keeps icon and label together" do
    target = %{
      name: "Sprite1",
      is_stage: false,
      custom_blocks: [],
      top_scripts: [
        %{
          id: "script-1",
          hat_opcode: "event_whenflagclicked",
          hat_label: "緑の旗が押されたとき",
          blocks: []
        }
      ]
    }

    project = %{stage: nil, sprites: [target]}

    mermaid = InspectorFlow.build_flow_mermaid(project, target, nil)

    assert mermaid =~ "scratch-flow-flag-label"
    assert mermaid =~ "green-flag.svg"
    assert mermaid =~ "が押されたとき</span>"
  end

  test "selected detail does not change the mermaid chart definition" do
    target = %{
      name: "Sprite1",
      is_stage: false,
      custom_blocks: [],
      top_scripts: [
        %{
          id: "script-1",
          hat_opcode: "event_whenbroadcastreceived",
          hat_label: "start",
          blocks: []
        }
      ]
    }

    project = %{stage: nil, sprites: [target]}
    selected = %{kind: "script", id: "script-1", sprite: "Sprite1", type: "sprite"}

    chart_without_selection = InspectorFlow.build_flow_mermaid(project, target, nil)
    chart_with_selection = InspectorFlow.build_flow_mermaid(project, target, selected)

    assert chart_with_selection == chart_without_selection
    refute chart_with_selection =~ "selectedNode"
  end
end
