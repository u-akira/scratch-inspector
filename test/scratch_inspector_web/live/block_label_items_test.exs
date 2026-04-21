defmodule ScratchInspectorWeb.Live.BlockLabelItemsTest do
  use ExUnit.Case, async: true

  alias ScratchInspectorWeb.Live.BlockLabelItems

  test "parses placeholders from list-based fields and inputs" do
    label = "[EFFECT] の効果を [VALUE] にする"

    fields = [
      %{name: "EFFECT", value: "ghost"}
    ]

    inputs = [
      %{name: "VALUE", slot: :round, value: %{kind: :literal, value: "10"}}
    ]

    assert BlockLabelItems.parse(label, fields, inputs) == [
             %{kind: :field, name: "EFFECT", value: "ghost"},
             %{kind: :label, value: " の効果を "},
             %{kind: :input, name: "VALUE", slot: :round, value: %{kind: :literal, value: "10"}},
             %{kind: :label, value: " にする"}
           ]
  end

  test "falls back safely when placeholder source is malformed" do
    label = "[VALUE]"
    fields = [%{name: "EFFECT", value: "ghost"}]
    inputs = %{"VALUE" => [%{name: "EFFECT", value: "ghost"}]}

    assert BlockLabelItems.parse(label, fields, inputs) == [
             %{kind: :label, value: "[VALUE]"}
           ]
  end

  test "does not crash for reproduction-like shape with missing VALUE" do
    label = "[VALUE] にする"
    fields = [%{name: "EFFECT", value: "ghost"}]
    inputs = [%{name: "EFFECT", value: "ghost"}]

    assert BlockLabelItems.parse(label, fields, inputs) == [
             %{kind: :label, value: "[VALUE]"},
             %{kind: :label, value: " にする"}
           ]
  end

  test "keeps compatibility with map-based parser shape" do
    label = "[EFFECT] の効果を [VALUE] にする"

    fields = %{
      "EFFECT" => %{value: "ghost"}
    }

    inputs = %{
      "VALUE" => %{slot: :round, value: "25"}
    }

    assert BlockLabelItems.parse(label, fields, inputs) == [
             %{kind: :field, name: "EFFECT", value: "ghost"},
             %{kind: :label, value: " の効果を "},
             %{kind: :input, name: "VALUE", slot: :round, value: "25"},
             %{kind: :label, value: " にする"}
           ]
  end
  test "keeps placeholder order for looks effect label/value combinations" do
    label = "[EFFECT] の効果を [VALUE] にする"

    cases = [
      {"ghost", "0"},
      {"pixelate", "1"}
    ]

    for {effect, value} <- cases do
      fields = [%{name: "EFFECT", value: effect}]
      inputs = [%{name: "VALUE", slot: :round, value: %{kind: :literal, value: value}}]

      assert BlockLabelItems.parse(label, fields, inputs) == [
               %{kind: :field, name: "EFFECT", value: effect},
               %{kind: :label, value: " の効果を "},
               %{kind: :input, name: "VALUE", slot: :round, value: %{kind: :literal, value: value}},
               %{kind: :label, value: " にする"}
             ]
    end
  end

  test "parses digit placeholders for operator equals" do
    label = "[OPERAND1] = [OPERAND2]"

    fields = []

    inputs = [
      %{name: "OPERAND1", slot: :round, value: %{kind: :literal, value: "x"}},
      %{name: "OPERAND2", slot: :round, value: %{kind: :literal, value: "1"}}
    ]

    assert BlockLabelItems.parse(label, fields, inputs) == [
             %{kind: :input, name: "OPERAND1", slot: :round, value: %{kind: :literal, value: "x"}},
             %{kind: :label, value: " = "},
             %{kind: :input, name: "OPERAND2", slot: :round, value: %{kind: :literal, value: "1"}}
           ]
  end
end
