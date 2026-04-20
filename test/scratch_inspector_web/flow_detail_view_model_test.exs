defmodule ScratchInspectorWeb.FlowDetailViewModelTest do
  use ExUnit.Case, async: true

  alias ScratchInspectorWeb.FlowDetailViewModel

  describe "build/3" do
    test "returns script detail data for a selected script" do
      script = %{
        id: "script-1",
        hat_opcode: "event_whenflagclicked",
        hat_label: "when green flag clicked",
        detail_header: %{
          opcode: "event_whenflagclicked",
          shape: :hat,
          label: "when green flag clicked"
        },
        detail_blocks: [%{label: "move 10 steps"}]
      }

      target = %{name: "Sprite1", top_scripts: [script], custom_blocks: []}
      project = %{stage: nil, sprites: [target]}

      assert %{
               detail_script: %{
                 kind: :script,
                 source: ^script,
                 header: %{
                   opcode: "event_whenflagclicked",
                   shape: :hat,
                   label: "when green flag clicked"
                 },
                 blocks: [%{label: "move 10 steps"}]
               },
               detail_title: "when green flag clicked",
               detail_receivers: nil
             } =
               FlowDetailViewModel.build(project, target, %{kind: "script", id: "script-1"})
    end

    test "returns custom block detail data for a selected block definition" do
      block_def = %{
        name: "my block",
        detail_header: %{opcode: "procedures_definition", shape: :hat, label: "my block"},
        detail_blocks: [%{label: "say hello"}]
      }

      target = %{name: "Sprite1", top_scripts: [], custom_blocks: [block_def]}
      project = %{stage: nil, sprites: [target]}

      assert %{
               detail_script: %{
                 kind: :custom_block,
                 source: ^block_def,
                 header: %{opcode: "procedures_definition", shape: :hat, label: "my block"},
                 blocks: [%{label: "say hello"}]
               },
               detail_title: "my block",
               detail_receivers: nil
             } =
               FlowDetailViewModel.build(project, target, %{kind: "block_def", id: "my block"})
    end

    test "returns broadcast receivers for a selected broadcast" do
      receiver_script = %{
        id: "receiver-1",
        hat_opcode: "event_whenbroadcastreceived",
        hat_label: ~s(when I receive "message1")
      }

      receiver_target = %{name: "Sprite2", is_stage: false, top_scripts: [receiver_script]}
      current_target = %{name: "Sprite1", is_stage: false, top_scripts: [], custom_blocks: []}
      project = %{stage: nil, sprites: [current_target, receiver_target]}

      assert %{
               detail_script: nil,
               detail_title: ~s(Scripts that receive "message1"),
               detail_receivers: [
                 %{
                   target: ^receiver_target,
                   script: ^receiver_script,
                   detail: %{
                     kind: "script",
                     id: "receiver-1",
                     sprite: "Sprite2",
                     type: "sprite"
                   }
                 }
               ]
             } =
               FlowDetailViewModel.build(project, current_target, %{
                 kind: "broadcast",
                 id: "message1"
               })
    end

    test "returns empty detail when nothing matches" do
      target = %{name: "Sprite1", top_scripts: [], custom_blocks: []}
      project = %{stage: nil, sprites: [target]}

      assert %{detail_script: nil, detail_title: nil, detail_receivers: nil} =
               FlowDetailViewModel.build(project, target, %{kind: "script", id: "missing"})
    end
  end
end
