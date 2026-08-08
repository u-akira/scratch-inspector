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

  test "custom block detail uses argument names instead of procedure placeholders" do
    project_path =
      write_sb3(%{
        "targets" => [
          %{
            "isStage" => true,
            "name" => "Stage",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{},
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          },
          %{
            "isStage" => false,
            "name" => "Sprite1",
            "variables" => %{"var-id" => ["result", 0]},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{
              "definition" => %{
                "opcode" => "procedures_definition",
                "next" => "set-result",
                "parent" => nil,
                "inputs" => %{"custom_block" => [1, "prototype"]},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => true
              },
              "prototype" => %{
                "opcode" => "procedures_prototype",
                "next" => nil,
                "parent" => "definition",
                "inputs" => %{},
                "fields" => %{},
                "shadow" => true,
                "topLevel" => false,
                "mutation" => %{
                  "proccode" => "カードの属性を設定する %s %s %b",
                  "argumentids" => Jason.encode!(["arg-kind", "arg-count", "arg-enabled"]),
                  "argumentnames" => Jason.encode!(["種類", "枚数", "有効か？"]),
                  "argumentdefaults" => Jason.encode!(["", "", "false"]),
                  "warp" => "false"
                }
              },
              "set-result" => %{
                "opcode" => "data_setvariableto",
                "next" => nil,
                "parent" => "definition",
                "inputs" => %{"VALUE" => [3, "arg-kind", [10, ""]]},
                "fields" => %{"VARIABLE" => ["result", "var-id"]},
                "shadow" => false,
                "topLevel" => false
              },
              "arg-kind" => %{
                "opcode" => "argument_reporter_string_number",
                "next" => nil,
                "parent" => "set-result",
                "inputs" => %{},
                "fields" => %{"VALUE" => ["種類", nil]},
                "shadow" => false,
                "topLevel" => false
              }
            },
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          }
        ]
      })

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sprite] = project.sprites
    [custom_block] = sprite.custom_blocks

    assert custom_block.detail_header.label == "カードの属性を設定する 種類 枚数 有効か？"

    [set_block] = custom_block.detail_blocks
    value_input = Enum.find(set_block.inputs, &(&1.name == "VALUE"))

    assert %{
             kind: :block,
             block: %{opcode: "argument_reporter_string_number", label: "種類"}
           } = value_input.value
  end

  test "toio do blocks use Japanese labels and toio color category" do
    project_path =
      write_sb3(%{
        "targets" => [
          %{
            "isStage" => true,
            "name" => "Stage",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{},
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          },
          %{
            "isStage" => false,
            "name" => "Sprite1",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{
              "hat" => %{
                "opcode" => "event_whenflagclicked",
                "next" => "move",
                "parent" => nil,
                "inputs" => %{},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => true
              },
              "move" => %{
                "opcode" => "toio_moveFor",
                "next" => "stop",
                "parent" => "hat",
                "inputs" => %{
                  "SPEED" => [1, [4, "50"]],
                  "DURATION" => [1, [4, "1"]]
                },
                "fields" => %{"DIRECTION" => ["forward", nil]},
                "shadow" => false,
                "topLevel" => false
              },
              "stop" => %{
                "opcode" => "toio_stopWheels",
                "next" => nil,
                "parent" => "move",
                "inputs" => %{},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => false
              }
            },
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          }
        ]
      })

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sprite] = project.sprites
    [script] = sprite.top_scripts
    [move_block, stop_block] = script.detail_blocks

    assert move_block.category == :toio
    assert move_block.label == "[DIRECTION]に速さ[SPEED]で[DURATION]秒動かす"
    assert Enum.find(move_block.fields, &(&1.name == "DIRECTION")).value == "前"
    assert stop_block.category == :toio
    assert stop_block.label == "タイヤを止める"
  end

  test "toio direction menu shadow blocks are normalized" do
    project_path =
      write_sb3(%{
        "targets" => [
          %{
            "isStage" => true,
            "name" => "Stage",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{},
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          },
          %{
            "isStage" => false,
            "name" => "Sprite1",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{
              "hat" => %{
                "opcode" => "event_whenflagclicked",
                "next" => "move",
                "parent" => nil,
                "inputs" => %{},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => true
              },
              "move" => %{
                "opcode" => "toio_moveFor",
                "next" => nil,
                "parent" => "hat",
                "inputs" => %{
                  "DIRECTION" => [1, "direction-menu"],
                  "SPEED" => [1, [4, "45"]],
                  "DURATION" => [1, [4, "0.5"]]
                },
                "fields" => %{},
                "shadow" => false,
                "topLevel" => false
              },
              "direction-menu" => %{
                "opcode" => "toio_menu_moveDirections",
                "next" => nil,
                "parent" => "move",
                "inputs" => %{},
                "fields" => %{"moveDirections" => ["forward", nil]},
                "shadow" => true,
                "topLevel" => false
              }
            },
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          }
        ]
      })

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sprite] = project.sprites
    [script] = sprite.top_scripts
    [move_block] = script.detail_blocks
    direction_input = Enum.find(move_block.inputs, &(&1.name == "DIRECTION"))

    assert %{
             value: %{
               kind: :block,
               block: %{
                 opcode: "toio_menu_moveDirections",
                 category: :toio,
                 label: "[DIRECTION]",
                 fields: [%{name: "moveDirections", value: "前"}]
               }
             }
           } = direction_input
  end

  test "toio2 do blocks use Japanese labels and the toio do category" do
    project_path =
      write_sb3(%{
        "targets" => [
          %{
            "isStage" => true,
            "name" => "Stage",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{},
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          },
          %{
            "isStage" => false,
            "name" => "Sprite1",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{
              "hat" => %{
                "opcode" => "event_whenflagclicked",
                "next" => "move",
                "parent" => nil,
                "inputs" => %{},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => true
              },
              "move" => %{
                "opcode" => "toio2_moveFor",
                "next" => nil,
                "parent" => "hat",
                "inputs" => %{
                  "DIRECTION" => [1, "direction-menu"],
                  "SPEED" => [1, [4, "60"]],
                  "DURATION" => [1, [4, "0.5"]]
                },
                "fields" => %{},
                "shadow" => false,
                "topLevel" => false
              },
              "direction-menu" => %{
                "opcode" => "toio2_menu_moveDirections",
                "next" => nil,
                "parent" => "move",
                "inputs" => %{},
                "fields" => %{"moveDirections" => ["forward", nil]},
                "shadow" => true,
                "topLevel" => false
              }
            },
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          }
        ]
      })

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sprite] = project.sprites
    [script] = sprite.top_scripts
    [move_block] = script.detail_blocks
    direction_input = Enum.find(move_block.inputs, &(&1.name == "DIRECTION"))

    assert move_block.category == :toio_do
    assert move_block.label == "[DIRECTION]に速さ[SPEED]で[DURATION]秒動かす"

    assert %{
             value: %{
               kind: :block,
               block: %{
                 opcode: "toio2_menu_moveDirections",
                 category: :toio_do,
                 label: "[DIRECTION]",
                 fields: [%{name: "moveDirections", value: "前"}]
               }
             }
           } = direction_input
  end

  test "common Scratch field values and menu shadow blocks are localized" do
    project_path =
      write_sb3(%{
        "targets" => [
          %{
            "isStage" => true,
            "name" => "Stage",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{},
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          },
          %{
            "isStage" => false,
            "name" => "Sprite1",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{
              "hat" => %{
                "opcode" => "event_whenbroadcastreceived",
                "next" => "effect",
                "parent" => nil,
                "inputs" => %{},
                "fields" => %{"BROADCAST_OPTION" => ["回転ボタンを表示する", nil]},
                "shadow" => false,
                "topLevel" => true
              },
              "effect" => %{
                "opcode" => "looks_seteffectto",
                "next" => "costume-name",
                "parent" => "hat",
                "inputs" => %{"VALUE" => [1, [4, "50"]]},
                "fields" => %{"EFFECT" => ["GHOST", nil]},
                "shadow" => false,
                "topLevel" => false
              },
              "costume-name" => %{
                "opcode" => "looks_costumenumbername",
                "next" => "switch-bg",
                "parent" => "effect",
                "inputs" => %{},
                "fields" => %{"NUMBER_NAME" => ["name", nil]},
                "shadow" => false,
                "topLevel" => false
              },
              "switch-bg" => %{
                "opcode" => "looks_switchbackdropto",
                "next" => "drag",
                "parent" => "costume-name",
                "inputs" => %{"BACKDROP" => [1, "backdrop-menu"]},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => false
              },
              "backdrop-menu" => %{
                "opcode" => "looks_backdrops",
                "next" => nil,
                "parent" => "switch-bg",
                "inputs" => %{},
                "fields" => %{"BACKDROP" => ["プレイモード", nil]},
                "shadow" => true,
                "topLevel" => false
              },
              "drag" => %{
                "opcode" => "sensing_setdragmode",
                "next" => nil,
                "parent" => "switch-bg",
                "inputs" => %{},
                "fields" => %{"DRAG_MODE" => ["draggable", nil]},
                "shadow" => false,
                "topLevel" => false
              }
            },
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          }
        ]
      })

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sprite] = project.sprites
    [script] = sprite.top_scripts
    [effect_block, costume_name_block, switch_bg_block, drag_block] = script.detail_blocks

    assert Enum.find(effect_block.fields, &(&1.name == "EFFECT")).value == "幽霊"
    assert Enum.find(costume_name_block.fields, &(&1.name == "NUMBER_NAME")).value == "名前"
    assert Enum.find(drag_block.fields, &(&1.name == "DRAG_MODE")).value == "ドラッグできる"

    backdrop_input = Enum.find(switch_bg_block.inputs, &(&1.name == "BACKDROP"))

    assert %{
             value: %{
               kind: :block,
               block: %{
                 opcode: "looks_backdrops",
                 label: "[BACKDROP]",
                 fields: [%{name: "BACKDROP", value: "プレイモード"}]
               }
             }
           } = backdrop_input
  end

  test "sensing of object menu and property fields are localized" do
    project_path =
      write_sb3(%{
        "targets" => [
          %{
            "isStage" => true,
            "name" => "Stage",
            "variables" => %{},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{},
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          },
          %{
            "isStage" => false,
            "name" => "Sprite1",
            "variables" => %{"var-direction" => ["_向き", 0]},
            "lists" => %{},
            "broadcasts" => %{},
            "blocks" => %{
              "hat" => %{
                "opcode" => "event_whenflagclicked",
                "next" => "set-direction",
                "parent" => nil,
                "inputs" => %{},
                "fields" => %{},
                "shadow" => false,
                "topLevel" => true
              },
              "set-direction" => %{
                "opcode" => "data_setvariableto",
                "next" => nil,
                "parent" => "hat",
                "inputs" => %{"VALUE" => [1, "sensing-of"]},
                "fields" => %{"VARIABLE" => ["_向き", "var-direction"]},
                "shadow" => false,
                "topLevel" => false
              },
              "sensing-of" => %{
                "opcode" => "sensing_of",
                "next" => nil,
                "parent" => "set-direction",
                "inputs" => %{"OBJECT" => [1, "object-menu"]},
                "fields" => %{"PROPERTY" => ["direction", nil]},
                "shadow" => false,
                "topLevel" => false
              },
              "object-menu" => %{
                "opcode" => "sensing_of_object_menu",
                "next" => nil,
                "parent" => "sensing-of",
                "inputs" => %{},
                "fields" => %{"OBJECT" => ["カード選択", nil]},
                "shadow" => true,
                "topLevel" => false
              }
            },
            "comments" => %{},
            "costumes" => [],
            "sounds" => []
          }
        ]
      })

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sprite] = project.sprites
    [script] = sprite.top_scripts
    [set_block] = script.detail_blocks
    sensing_input = Enum.find(set_block.inputs, &(&1.name == "VALUE"))

    assert %{
             value: %{
               kind: :block,
               block: %{
                 opcode: "sensing_of",
                 fields: [%{name: "PROPERTY", value: "向き"}],
                 inputs: [
                   %{
                     name: "OBJECT",
                     value: %{
                       kind: :block,
                       block: %{
                         opcode: "sensing_of_object_menu",
                         label: "[OBJECT]",
                         fields: [%{name: "OBJECT", value: "カード選択"}]
                       }
                     }
                   }
                 ]
               }
             }
           } = sensing_input
  end

  test "sounds include inline audio data when the asset exists in the archive" do
    sound_binary = "RIFFfake-wave-data"

    project_path =
      write_sb3(
        %{
          "targets" => [
            %{
              "isStage" => true,
              "name" => "Stage",
              "variables" => %{},
              "lists" => %{},
              "broadcasts" => %{},
              "blocks" => %{},
              "comments" => %{},
              "costumes" => [],
              "sounds" => [
                %{
                  "name" => "pop",
                  "assetId" => "sound-asset",
                  "dataFormat" => "wav",
                  "md5ext" => "sound-asset.wav",
                  "rate" => 44_100,
                  "sampleCount" => 128
                }
              ]
            }
          ]
        },
        [{~c"sound-asset.wav", sound_binary}]
      )

    assert {:ok, project} = Parser.parse(project_path, ".sb3")
    [sound] = project.stage.sounds

    assert sound.name == "pop"
    assert sound.mime == "audio/wav"
    assert sound.asset_file == "sound-asset.wav"
    assert sound.base64 == Base.encode64(sound_binary)
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

  defp write_sb3(project, files \\ []) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "scratch-inspector-parser-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    project_json = Jason.encode!(project)
    path = Path.join(dir, "project.sb3")

    zip_entries = [{~c"project.json", project_json} | files]

    {:ok, {~c"project.sb3", zip_binary}} =
      :zip.create(~c"project.sb3", zip_entries, [:memory])

    File.write!(path, zip_binary)
    path
  end
end
