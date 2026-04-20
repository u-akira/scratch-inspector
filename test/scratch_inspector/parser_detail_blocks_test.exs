defmodule ScratchInspector.ParserDetailBlocksTest do
  use ExUnit.Case, async: true

  alias ScratchInspector.Parser

  test "parse/2 builds detail headers and detail blocks for flow inspection" do
    sample_path =
      __DIR__
      |> Path.join("../../sample/*.sb3")
      |> Path.expand()
      |> Path.wildcard()
      |> Enum.sort()
      |> List.first()

    assert is_binary(sample_path)

    assert {:ok, project} = Parser.parse(sample_path, ".sb3")

    targets = Enum.filter([project.stage | project.sprites], & &1)

    assert Enum.any?(targets)

    Enum.each(targets, fn target ->
      Enum.each(target.top_scripts || [], fn script ->
        assert %{shape: :hat, opcode: opcode, label: label} = script.detail_header
        assert is_binary(opcode)
        assert is_binary(label)
        assert is_list(script.detail_blocks)

        Enum.each(script.detail_blocks, fn block ->
          assert_detail_block_shape(block)
        end)
      end)

      Enum.each(target.custom_blocks || [], fn block_def ->
        assert %{opcode: "procedures_definition", shape: :hat, label: label} =
                 block_def.detail_header

        assert is_binary(label)
        assert is_list(block_def.detail_blocks)

        Enum.each(block_def.detail_blocks, fn block ->
          assert_detail_block_shape(block)
        end)
      end)
    end)
  end

  defp assert_detail_block_shape(block) do
    assert %{
             id: _,
             opcode: opcode,
             category: category,
             shape: shape,
             next: _,
             mutation: mutation,
             fields: fields,
             inputs: inputs,
             children: children,
             label: label,
             parts: parts,
             branches: branches
           } = block

    assert is_binary(opcode)
    assert is_atom(category)
    assert is_atom(shape)
    assert is_map(mutation)
    assert is_binary(label)
    assert is_list(fields)
    assert is_list(inputs)
    assert is_list(children)
    assert is_list(parts)
    assert is_list(branches)
  end
end
