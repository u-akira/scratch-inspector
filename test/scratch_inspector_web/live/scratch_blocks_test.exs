defmodule ScratchInspectorWeb.Live.InspectorComponents.ScratchBlocksTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias ScratchInspectorWeb.Live.InspectorComponents.ScratchBlocks

  test "renders color inputs as swatches instead of visible color codes" do
    block = %{
      opcode: "pen_setPenColorToColor",
      category: :pen,
      shape: :stack,
      label: "ペンの色を [COLOR] にする",
      fields: [],
      inputs: [
        %{name: "COLOR", slot: :round, value: %{kind: :literal, input_type: 9, value: "#b4db96"}}
      ],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_block/1, block: block)

    assert html =~ "scratch-color-input"
    assert html =~ "--scratch-color-value: #b4db96;"
    refute html |> Floki.parse_document!() |> Floki.text() =~ "#b4db96"
  end

  test "renders toio do blocks with a cube-like icon" do
    block = %{
      opcode: "toio2_stopWheels",
      category: :toio_do,
      shape: :stack,
      label: "タイヤを止める",
      fields: [],
      inputs: [],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_block/1, block: block)

    assert html =~ "scratch-block-icon--toio"
    assert html =~ "--scratch-block-color: #f05b4f;"
    assert html =~ "--scratch-block-secondary: #d94a41;"
    assert html =~ "--scratch-block-tertiary: #c93f38;"
    assert html |> Floki.parse_document!() |> Floki.text() =~ "タイヤを止める"
  end

  test "renders toio duration inputs with timer icon and no speed percent labels" do
    block = %{
      opcode: "toio2_moveWheelsFor",
      category: :toio_do,
      shape: :stack,
      label: "左タイヤを速さ[LEFT_SPEED]、右タイヤを速さ[RIGHT_SPEED]で[DURATION]秒動かす",
      fields: [],
      inputs: [
        %{name: "LEFT_SPEED", slot: :round, value: %{kind: :literal, input_type: 4, value: "80"}},
        %{name: "RIGHT_SPEED", slot: :round, value: %{kind: :literal, input_type: 4, value: "-80"}},
        %{name: "DURATION", slot: :round, value: %{kind: :literal, input_type: 4, value: "2"}}
      ],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_block/1, block: block)
    text = html |> Floki.parse_document!() |> Floki.text()

    assert html =~ "scratch-timer-icon"
    assert text =~ "左タイヤを速さ"
    assert text =~ "右タイヤを速さ"
    assert text =~ "秒動かす"
    refute text =~ "%"
  end

  test "renders toio2 do blocks with toio styling and timer icon" do
    block = %{
      opcode: "toio2_moveFor",
      category: :toio_do,
      shape: :stack,
      label: "[DIRECTION]に速さ[SPEED]で[DURATION]秒動かす",
      fields: [],
      inputs: [
        %{name: "DIRECTION", slot: :round, value: %{kind: :literal, input_type: 10, value: "前"}},
        %{name: "SPEED", slot: :round, value: %{kind: :literal, input_type: 4, value: "60"}},
        %{name: "DURATION", slot: :round, value: %{kind: :literal, input_type: 4, value: "0.5"}}
      ],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_block/1, block: block)
    text = html |> Floki.parse_document!() |> Floki.text()

    assert html =~ "scratch-block-icon--toio"
    assert html =~ "scratch-timer-icon"
    assert text =~ "前"
    assert text =~ "速さ"
    assert text =~ "秒動かす"
    refute text =~ "toio2_moveFor"
  end

  test "renders toio direction menu blocks as fields without a toio icon" do
    block = %{
      opcode: "toio_menu_moveDirections",
      category: :toio,
      shape: :reporter_round,
      label: "toio_menu_moveDirections",
      fields: [%{name: "moveDirections", value: "前"}],
      inputs: [],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_inline_block/1, block: block)

    assert html =~ "scratch-block-item-field"
    refute html =~ "toio_menu_moveDirections"
    refute html =~ "scratch-block-icon--toio"
    assert html |> Floki.parse_document!() |> Floki.text() =~ "前"
  end

  test "renders backdrop menu shadow blocks as backdrop fields" do
    block = %{
      opcode: "looks_backdrops",
      category: :looks,
      shape: :reporter_round,
      label: "looks_backdrops",
      fields: [%{name: "BACKDROP", value: "プレイモード"}],
      inputs: [],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_inline_block/1, block: block)

    assert html =~ "scratch-block-item-field"
    refute html =~ "looks_backdrops"
    assert html |> Floki.parse_document!() |> Floki.text() =~ "プレイモード"
  end

  test "renders sensing object menu shadow blocks as object fields" do
    block = %{
      opcode: "sensing_of_object_menu",
      category: :sensing,
      shape: :reporter_round,
      label: "sensing_of_object_menu",
      fields: [%{name: "OBJECT", value: "カード選択"}],
      inputs: [],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_inline_block/1, block: block)

    assert html =~ "scratch-block-item-field"
    refute html =~ "sensing_of_object_menu"
    assert html |> Floki.parse_document!() |> Floki.text() =~ "カード選択"
  end

  test "renders custom procedure call placeholders as argument inputs" do
    block = %{
      opcode: "procedures_call",
      category: :custom,
      shape: :stack,
      label: "%s を実行時の効果音を鳴らす",
      mutation: %{
        "proccode" => "%s を実行時の効果音を鳴らす",
        "argumentids" => Jason.encode!(["sound-arg"])
      },
      fields: [],
      inputs: [
        %{
          name: "sound-arg",
          slot: :round,
          value: %{
            kind: :block,
            block: %{
              opcode: "argument_reporter_string_number",
              category: :custom,
              shape: :reporter_round,
              label: "実行時の効果音",
              fields: [],
              inputs: [],
              children: []
            }
          }
        }
      ],
      children: []
    }

    html = render_component(&ScratchBlocks.scratch_block/1, block: block)
    text = html |> Floki.parse_document!() |> Floki.text()

    assert html =~ "scratch-argument-reporter"
    assert text =~ "実行時の効果音"
    assert text =~ "を実行時の効果音を鳴らす"
    refute text =~ "%s"
  end
end
