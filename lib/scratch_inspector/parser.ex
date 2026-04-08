defmodule ScratchInspector.Parser do
  @moduledoc """
  Scratch プロジェクトファイルのパーサー。
  .sb3 / .sb2 は ZIP 内の project.json を解析。
  .sb は未対応（Scratch 1.x バイナリ形式）。
  """

  @doc """
  ファイルパスと拡張子を受け取り、解析済みプロジェクト構造を返す。
  """
  def parse(path, ext) when ext in [".sb2", ".sb3"] do
    with {:ok, files} <- extract_zip(path),
         {:ok, json} <- find_project_json(files),
         {:ok, data} <- Jason.decode(json) do
      {:ok, build_project(data, files)}
    end
  end

  def parse(_path, ".sb") do
    {:error, "Scratch 1.x (.sb) 形式は現在未対応です"}
  end

  def parse(_path, ext) do
    {:error, "未対応のファイル形式: #{ext}"}
  end

  # ---- ZIP extraction ----

  defp extract_zip(path) do
    case :zip.unzip(String.to_charlist(path), [:memory]) do
      {:ok, files} -> {:ok, files}
      {:error, reason} -> {:error, "ZIP の展開に失敗しました: #{inspect(reason)}"}
    end
  end

  defp find_project_json(files) do
    case Enum.find(files, fn {name, _} -> name == ~c"project.json" end) do
      {_, content} -> {:ok, content}
      nil -> {:error, "project.json が見つかりません"}
    end
  end

  defp find_file_data(files, filename) do
    case Enum.find(files, fn {name, _} -> List.to_string(name) == filename end) do
      {_, data} -> {:ok, data}
      nil -> nil
    end
  end

  # ---- project building ----

  defp build_project(data, zip_files) do
    targets = Map.get(data, "targets", [])
    global_vars = extract_global_variables(targets)
    local_vars = extract_local_variables(targets)

    stage_target = Enum.find(targets, fn t -> Map.get(t, "isStage", false) end)
    sprite_targets = Enum.reject(targets, fn t -> Map.get(t, "isStage", false) end)

    stage =
      if stage_target do
        build_sprite(Map.put(stage_target, "name", "Stage"), zip_files, true)
      end

    sprites = Enum.map(sprite_targets, &build_sprite(&1, zip_files, false))

    %{
      name: "",
      stage: stage,
      sprites: sprites,
      variables: global_vars ++ local_vars
    }
  end

  defp build_sprite(target, zip_files, is_stage) do
    name = Map.get(target, "name", "Unknown")
    blocks = Map.get(target, "blocks", %{})

    scripts = extract_script_labels(blocks)
    events = extract_events(blocks)
    custom_blocks = extract_custom_blocks(blocks)
    top_scripts = extract_top_scripts(blocks)
    costumes = extract_costumes(target, zip_files)
    sounds = extract_sounds(target, zip_files)

    %{
      name: name,
      is_stage: is_stage,
      scripts: scripts,
      events: events,
      custom_blocks: custom_blocks,
      top_scripts: top_scripts,
      costumes: costumes,
      sounds: sounds
    }
  end

  defp build_render_stack(nil, _blocks), do: []

  defp build_render_stack(start_id, blocks) do
    case Map.get(blocks, start_id) do
      block when is_map(block) ->
        current = build_render_block(start_id, block, blocks)
        next_id = Map.get(block, "next")
        [current | build_render_stack(next_id, blocks)]

      _ ->
        []
    end
  end

  defp build_render_block(id, block, blocks) do
    opcode = Map.get(block, "opcode", "")
    inputs = Map.get(block, "inputs", %{})
    fields = Map.get(block, "fields", %{})

    %{
      id: id,
      opcode: opcode,
      category: block_category(opcode),
      shape: block_shape(opcode),
      label: render_block_label(block),
      parts: render_block_parts(fields, inputs, blocks),
      branches: render_block_branches(inputs, blocks)
    }
  end

  defp render_block_label(block) do
    opcode = Map.get(block, "opcode", "")

    if opcode == "procedures_call" do
      block |> Map.get("mutation", %{}) |> Map.get("proccode", "custom block")
    else
      opcode_label(opcode)
    end
  end

  defp render_block_parts(fields, inputs, blocks) do
    field_parts =
      fields
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.map(fn {key, value} ->
        %{name: key, slot: :round, value: render_field_value(value)}
      end)
      |> Enum.reject(&is_nil(&1.value))

    input_parts =
      inputs
      |> Enum.reject(fn {key, _} -> String.starts_with?(key, "SUBSTACK") || key == "custom_block" end)
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.map(fn {key, value} ->
        %{name: key, slot: input_slot_shape(key, value, blocks), value: render_input_value(value, blocks)}
      end)
      |> Enum.reject(fn part -> is_nil(part.value) or part.value == "" end)

    field_parts ++ input_parts
  end

  defp render_field_value([value | _]) when is_binary(value), do: value
  defp render_field_value(_), do: nil

  defp render_input_value([_, second], blocks), do: render_input_atom(second, blocks)
  defp render_input_value([_, second, _fallback], blocks), do: render_input_atom(second, blocks)
  defp render_input_value(_, _blocks), do: nil

  defp render_input_atom([_type, value | _], _blocks) when is_binary(value), do: value
  defp render_input_atom([_type, value | _], _blocks) when is_number(value), do: to_string(value)

  defp render_input_atom(id, blocks) when is_binary(id) do
    case Map.get(blocks, id) do
      block when is_map(block) ->
        %{kind: :block, block: build_render_block(id, block, blocks)}

      _ ->
        "?"
    end
  end

  defp render_input_atom(_, _blocks), do: nil

  defp render_block_branches(inputs, blocks) do
    inputs
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, "SUBSTACK") end)
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {key, value} ->
      substack_id = extract_input_id(value)
      %{name: key, blocks: build_render_stack(substack_id, blocks)}
    end)
    |> Enum.reject(fn branch -> Enum.empty?(branch.blocks) end)
  end

  defp input_slot_shape(_key, [_, second], blocks), do: slot_shape_from_input(second, blocks)
  defp input_slot_shape(_key, [_, second, _fallback], blocks), do: slot_shape_from_input(second, blocks)
  defp input_slot_shape(_key, _value, _blocks), do: :round

  defp slot_shape_from_input(id, blocks) when is_binary(id) do
    case Map.get(blocks, id) do
      %{"opcode" => opcode} -> block_input_shape(opcode)
      _ -> :round
    end
  end

  defp slot_shape_from_input(_, _blocks), do: :round

  defp block_input_shape(opcode) do
    cond do
      opcode in ["operator_gt", "operator_lt", "operator_equals", "operator_and", "operator_or", "operator_not"] ->
        :boolean

      String.starts_with?(opcode, "operator_") or String.starts_with?(opcode, "sensing_") ->
        :round

      opcode in ["data_variable", "data_listcontents", "argument_reporter_boolean", "argument_reporter_string_number"] ->
        :round

      true ->
        :round
    end
  end

  defp block_shape(opcode) do
    cond do
      opcode in ["event_whenflagclicked", "event_whenbroadcastreceived", "event_whenkeypressed",
                 "event_whenthisspriteclicked", "event_whenstageclicked", "event_whengreaterthan",
                 "event_whenbackdropswitchesto", "control_start_as_clone"] ->
        :hat

      opcode in ["control_forever", "control_repeat", "control_repeat_until", "control_if", "control_if_else"] ->
        :c_block

      opcode == "control_stop" ->
        :cap

      true ->
        :stack
    end
  end

  defp block_category(opcode) do
    cond do
      String.starts_with?(opcode, "motion_") -> :motion
      String.starts_with?(opcode, "looks_") -> :looks
      String.starts_with?(opcode, "sound_") -> :sound
      String.starts_with?(opcode, "event_") -> :event
      String.starts_with?(opcode, "control_") -> :control
      String.starts_with?(opcode, "sensing_") -> :sensing
      String.starts_with?(opcode, "operator_") -> :operator
      String.starts_with?(opcode, "data_") -> :data
      String.starts_with?(opcode, "procedures_") -> :custom
      String.starts_with?(opcode, "pen_") -> :pen
      true -> :default
    end
  end

  # ---- costumes & sounds ----

  defp extract_costumes(target, zip_files) do
    target
    |> Map.get("costumes", [])
    |> Enum.map(fn costume ->
      md5ext = Map.get(costume, "md5ext") || Map.get(costume, "assetId", "") <> "." <> Map.get(costume, "dataFormat", "svg")
      data_format = Map.get(costume, "dataFormat", "svg") |> String.downcase()
      mime = costume_mime(data_format)

      base64_data =
        case find_file_data(zip_files, md5ext) do
          {:ok, binary} -> Base.encode64(binary)
          _ -> nil
        end

      %{
        name: Map.get(costume, "name", "unknown"),
        data_format: data_format,
        mime: mime,
        base64: base64_data
      }
    end)
  end

  defp extract_sounds(target, zip_files) do
    target
    |> Map.get("sounds", [])
    |> Enum.map(fn sound ->
      md5ext = Map.get(sound, "md5ext") || Map.get(sound, "assetId", "") <> "." <> Map.get(sound, "dataFormat", "wav")
      data_format = Map.get(sound, "dataFormat", "wav") |> String.downcase()
      mime = sound_mime(data_format)

      base64_data =
        case find_file_data(zip_files, md5ext) do
          {:ok, binary} -> Base.encode64(binary)
          _ -> nil
        end

      %{
        name: Map.get(sound, "name", "unknown"),
        data_format: data_format,
        mime: mime,
        base64: base64_data,
        rate: Map.get(sound, "rate"),
        sample_count: Map.get(sound, "sampleCount")
      }
    end)
  end

  defp costume_mime("svg"), do: "image/svg+xml"
  defp costume_mime("png"), do: "image/png"
  defp costume_mime("jpg"), do: "image/jpeg"
  defp costume_mime("jpeg"), do: "image/jpeg"
  defp costume_mime("bmp"), do: "image/bmp"
  defp costume_mime("gif"), do: "image/gif"
  defp costume_mime(_), do: "application/octet-stream"

  defp sound_mime("wav"), do: "audio/wav"
  defp sound_mime("mp3"), do: "audio/mpeg"
  defp sound_mime(_), do: "audio/wav"

  # ---- block chain walking ----

  @doc """
  ブロックチェーンを辿り、スクリプトの内容を読みやすい形で返す。
  """
  def walk_block_chain(start_id, blocks, depth \\ 0) do
    case Map.get(blocks, start_id) do
      nil ->
        []

      block when is_map(block) ->
        opcode = Map.get(block, "opcode", "")
        label =
          if opcode == "procedures_call" do
            proccode = block |> Map.get("mutation", %{}) |> Map.get("proccode", "?")
            proccode
          else
            opcode_label(opcode)
          end
        inputs = Map.get(block, "inputs", %{})
        fields = Map.get(block, "fields", %{})

        # パラメータを収集
        params = extract_block_params(inputs, fields, blocks)

        current = %{
          label: label,
          opcode: opcode,
          depth: depth,
          params: params
        }

        # サブスタック（if/else/repeat の中身）
        substacks =
          inputs
          |> Enum.filter(fn {key, _} -> String.starts_with?(key, "SUBSTACK") end)
          |> Enum.sort_by(fn {key, _} -> key end)
          |> Enum.flat_map(fn {_key, val} ->
            substack_id = extract_input_id(val)
            if substack_id, do: walk_block_chain(substack_id, blocks, depth + 1), else: []
          end)

        # 次のブロック
        next_id = Map.get(block, "next")
        next_blocks = if next_id, do: walk_block_chain(next_id, blocks, depth), else: []

        [current] ++ substacks ++ next_blocks

      _ ->
        []
    end
  end

  defp extract_input_id(val) when is_list(val) do
    # inputs の形式: [shadow_type, id_or_array]
    case val do
      [_, id] when is_binary(id) -> id
      [_, [_, id | _]] when is_binary(id) -> nil  # リテラル値
      _ -> nil
    end
  end

  defp extract_input_id(_), do: nil

  defp extract_block_params(inputs, fields, blocks) do
    field_params =
      fields
      |> Enum.map(fn {_key, val} ->
        case val do
          [name | _] when is_binary(name) -> name
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    input_params =
      inputs
      |> Enum.reject(fn {key, _} -> String.starts_with?(key, "SUBSTACK") || key == "custom_block" end)
      |> Enum.flat_map(fn {_key, val} ->
        # Scratch input encoding:
        #   [shadow, second]          — shadow=1/2: literal or reporter (no fallback)
        #   [shadow, second, fallback] — shadow=3: reporter/inline-var with shadow fallback
        case val do
          [_, second] -> extract_input_value(second, blocks)
          [_, second, _fallback] -> extract_input_value(second, blocks)
          _ -> []
        end
      end)

    field_params ++ input_params
  end

  # プリミティブ値: [type, value, ...] — type 4-11: number/string literal, 12-13: inline variable/list
  defp extract_input_value([_type, value | _], _blocks) when is_binary(value), do: [value]
  defp extract_input_value([_type, value | _], _blocks) when is_number(value), do: [to_string(value)]
  # reporter ブロック参照: "block_id"
  defp extract_input_value(id, blocks) when is_binary(id), do: [reporter_label(Map.get(blocks, id), blocks)]
  defp extract_input_value(_, _), do: []

  defp reporter_label(nil, _blocks), do: "?"
  defp reporter_label(block, blocks) do
    case Map.get(block, "opcode") do
      "data_variable" ->
        block |> Map.get("fields", %{}) |> Map.get("VARIABLE", []) |> List.first() || "?"
      "data_listcontents" ->
        block |> Map.get("fields", %{}) |> Map.get("LIST", []) |> List.first() || "?"
      opc ->
        inputs = Map.get(block, "inputs", %{})
        fields = Map.get(block, "fields", %{})
        inner = extract_block_params(inputs, fields, blocks)
        if Enum.empty?(inner), do: opcode_label(opc), else: "#{opcode_label(opc)}(#{Enum.join(inner, ", ")})"
    end
  end

  # ---- top-level scripts (non-function code) ----

  defp extract_top_scripts(blocks) do
    # hat blocks (トップレベル) から関数定義以外のスクリプトを抽出
    blocks
    |> Enum.filter(fn {_id, block} ->
      is_map(block) and
        is_nil(Map.get(block, "parent")) and
        Map.get(block, "topLevel", false) == true
    end)
    |> Enum.reject(fn {_id, block} ->
      Map.get(block, "opcode") in ["procedures_definition", "procedures_prototype"]
    end)
    |> Enum.map(fn {id, block} ->
      opcode = Map.get(block, "opcode", "")
      value = extract_event_value(block)
      label = event_label_from_opcode(opcode, value)

      # 最初の子ブロックから辿る
      next_id = Map.get(block, "next")
      chain = if next_id, do: walk_block_chain(next_id, blocks), else: []

      %{
        id: id,
        hat_label: label,
        hat_opcode: opcode,
        blocks: chain,
        render_blocks: build_render_stack(next_id, blocks)
      }
    end)
    |> Enum.sort_by(fn s -> s.hat_opcode end)
  end

  # ---- script labels ----

  defp extract_script_labels(blocks) do
    blocks
    |> Enum.filter(fn {_id, block} ->
      is_map(block) and is_nil(Map.get(block, "parent"))
    end)
    |> Enum.map(fn {_id, block} -> opcode_label(Map.get(block, "opcode", "")) end)
    |> Enum.uniq()
  end

  # ---- events ----

  defp extract_events(blocks) do
    event_opcodes = ~w(
      event_whenflagclicked
      event_whenbroadcastreceived
      event_whenkeypressed
      event_whenthisspriteclicked
      event_whenstageclicked
      event_whengreaterthan
      event_whenbackdropswitchesto
    )

    blocks
    |> Enum.filter(fn {_id, block} ->
      is_map(block) and
        Map.get(block, "opcode") in event_opcodes and
        is_nil(Map.get(block, "parent"))
    end)
    |> Enum.map(fn {id, block} ->
      opcode = Map.get(block, "opcode")
      value = extract_event_value(block)
      child_scripts = collect_child_labels(id, blocks)

      %{type: opcode, value: value, scripts: child_scripts}
    end)
  end

  defp extract_event_value(block) do
    fields = Map.get(block, "fields", %{})

    cond do
      Map.has_key?(fields, "BROADCAST_OPTION") ->
        fields |> Map.get("BROADCAST_OPTION") |> List.first()

      Map.has_key?(fields, "KEY_OPTION") ->
        fields |> Map.get("KEY_OPTION") |> List.first()

      Map.has_key?(fields, "BACKDROP") ->
        fields |> Map.get("BACKDROP") |> List.first()

      true ->
        nil
    end
  end

  defp collect_child_labels(parent_id, blocks) do
    blocks
    |> Enum.filter(fn {_id, block} ->
      is_map(block) and Map.get(block, "parent") == parent_id
    end)
    |> Enum.map(fn {_id, block} -> opcode_label(Map.get(block, "opcode", "")) end)
    |> Enum.take(5)
  end

  # ---- custom blocks ----

  defp extract_custom_blocks(blocks) do
    # procedure_definition ブロックを探す
    definitions =
      blocks
      |> Enum.filter(fn {_id, block} ->
        is_map(block) and Map.get(block, "opcode") == "procedures_definition"
      end)
      |> Enum.map(fn {id, block} ->
        proto_id = block |> Map.get("inputs", %{}) |> Map.get("custom_block", []) |> List.last()
        proto = Map.get(blocks, proto_id, %{})
        name = proto |> Map.get("mutation", %{}) |> Map.get("proccode", "unknown")

        # 関数本体のブロックチェーンを取得
        next_id = Map.get(block, "next")
        code_blocks = if next_id, do: walk_block_chain(next_id, blocks), else: []

        render_blocks = build_render_stack(next_id, blocks)

        {id, name, code_blocks, render_blocks}
      end)

    # procedure_call ブロックから呼び出し関係を構築
    call_map = build_call_map(blocks)

    Enum.map(definitions, fn {_def_id, name, code_blocks, render_blocks} ->
      callers = Map.get(call_map, name, [])

      %{
        name: name,
        called_by: callers,
        call_count: length(callers),
        code_blocks: code_blocks,
        render_blocks: render_blocks
      }
    end)
  end

  defp build_call_map(blocks) do
    blocks
    |> Enum.filter(fn {_id, block} ->
      is_map(block) and Map.get(block, "opcode") == "procedures_call"
    end)
    |> Enum.reduce(%{}, fn {id, block}, acc ->
      proccode = block |> Map.get("mutation", %{}) |> Map.get("proccode", "unknown")
      # 呼び出し元のハットブロック ID（ラベルではなく ID で管理し同名イベントを区別）
      caller_id = find_hat_block_id(id, blocks)
      if caller_id do
        Map.update(acc, proccode, [caller_id], &[caller_id | &1])
      else
        acc
      end
    end)
  end

  defp find_hat_block_id(block_id, blocks, visited \\ MapSet.new()) do
    block = Map.get(blocks, block_id)
    parent_id = if block, do: Map.get(block, "parent"), else: nil

    cond do
      is_nil(block) -> nil
      is_nil(parent_id) -> block_id
      MapSet.member?(visited, block_id) -> nil
      true ->
        parent = Map.get(blocks, parent_id)
        if parent && is_nil(Map.get(parent, "parent")) do
          parent_id
        else
          find_hat_block_id(parent_id, blocks, MapSet.put(visited, block_id))
        end
    end
  end

  # ---- variables ----

  defp extract_global_variables(targets) do
    stage = Enum.find(targets, fn t -> Map.get(t, "isStage", false) end)
    if is_nil(stage), do: [], else: do_extract_variables(stage, :global, targets)
  end

  defp extract_local_variables(targets) do
    sprite_targets = Enum.reject(targets, fn t -> Map.get(t, "isStage", false) end)
    Enum.flat_map(sprite_targets, fn t ->
      do_extract_variables(t, :local, [t])
    end)
  end

  defp do_extract_variables(target, scope, all_targets) do
    vars = Map.get(target, "variables", %{})
    lists = Map.get(target, "lists", %{})
    sprite_name = Map.get(target, "name")

    var_entries =
      vars
      |> Enum.map(fn {_id, [name | _]} ->
        {readers, writers} = find_variable_refs(name, all_targets)
        %{name: name, kind: :variable, scope: scope, sprite: sprite_name, readers: readers, writers: writers}
      end)
      |> Enum.filter(fn v -> Enum.any?(v.readers) or Enum.any?(v.writers) end)

    list_entries =
      lists
      |> Enum.map(fn {_id, [name | _]} ->
        {readers, writers} = find_list_refs(name, all_targets)
        %{name: name, kind: :list, scope: scope, sprite: sprite_name, readers: readers, writers: writers}
      end)
      |> Enum.filter(fn v -> Enum.any?(v.readers) or Enum.any?(v.writers) end)

    var_entries ++ list_entries
  end

  defp find_variable_refs(var_name, targets) do
    readers = find_block_refs(var_name, targets, ["data_variable"], "VARIABLE", :read)
    writers = find_block_refs(var_name, targets, ["data_setvariableto", "data_changevariableby"], "VARIABLE", :write)

    {readers, writers}
  end

  defp find_list_refs(list_name, targets) do
    reader_opcodes = ~w(data_listcontents data_itemnumoflist data_itemoflist data_lengthoflist data_listcontainsitem)
    writer_opcodes = ~w(data_addtolist data_deleteoflist data_deletealloflist data_insertatlist data_replaceitemoflist)

    readers = find_block_refs(list_name, targets, reader_opcodes, "LIST", :read)
    writers = find_block_refs(list_name, targets, writer_opcodes, "LIST", :write)

    {readers, writers}
  end

  defp find_block_refs(name, targets, opcodes, field_name, access) do
    targets
    |> Enum.flat_map(fn target ->
      blocks = Map.get(target, "blocks", %{})

      blocks
      |> Enum.filter(fn {_id, block} ->
        is_map(block) and
          Map.get(block, "opcode") in opcodes and
          block |> Map.get("fields", %{}) |> Map.get(field_name, []) |> List.first() == name
      end)
      |> Enum.map(fn {block_id, _block} -> build_usage_ref(target, blocks, block_id, access) end)
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq_by(fn ref ->
      {ref.sprite, ref.type, ref.detail_kind, ref.detail_id, ref.access}
    end)
  end

  defp build_usage_ref(target, blocks, block_id, access) do
    case find_hat_block_id(block_id, blocks) do
      nil ->
        nil

      owner_id ->
        case Map.get(blocks, owner_id) do
          %{"opcode" => "procedures_definition"} = block ->
            detail_id = procedure_name(block, blocks)

            %{
              sprite: Map.get(target, "name", "?"),
              type: if(Map.get(target, "isStage", false), do: "stage", else: "sprite"),
              detail_kind: "block_def",
              detail_id: detail_id,
              detail_label: detail_id,
              access: access
            }

          %{} = block ->
            detail_label = top_level_label(block)

            %{
              sprite: Map.get(target, "name", "?"),
              type: if(Map.get(target, "isStage", false), do: "stage", else: "sprite"),
              detail_kind: "script",
              detail_id: owner_id,
              detail_label: detail_label,
              access: access
            }

          _ ->
            nil
        end
    end
  end

  defp procedure_name(block, blocks) do
    proto_id = block |> Map.get("inputs", %{}) |> Map.get("custom_block", []) |> List.last()
    proto = Map.get(blocks, proto_id, %{})
    proto |> Map.get("mutation", %{}) |> Map.get("proccode", "unknown")
  end

  defp top_level_label(block) do
    opcode = Map.get(block, "opcode", "")
    value = extract_event_value(block)
    event_label_from_opcode(opcode, value)
  end

  # ---- labels ----

  defp event_label_from_opcode(opcode, value) do
    case opcode do
      "event_whenflagclicked" -> "緑の旗がクリックされたとき"
      "event_whenbroadcastreceived" -> "「#{value}」を受け取ったとき"
      "event_whenkeypressed" -> "「#{value}」キーが押されたとき"
      "event_whenthisspriteclicked" -> "スプライトがクリックされたとき"
      "event_whenstageclicked" -> "ステージがクリックされたとき"
      "event_whenbackdropswitchesto" -> "背景が「#{value}」に切り替わったとき"
      "event_whengreaterthan" -> "値が超えたとき"
      "control_start_as_clone" -> "クローンされたとき"
      _ -> opcode_label(opcode)
    end
  end

  def opcode_label(opcode) do
    case opcode do
      "event_whenflagclicked" -> "緑の旗"
      "event_whenbroadcastreceived" -> "メッセージ受信"
      "event_whenkeypressed" -> "キー押下"
      "event_whenthisspriteclicked" -> "スプライトクリック"
      "event_whenstageclicked" -> "ステージクリック"
      "event_whengreaterthan" -> "値が超えたとき"
      "event_whenbackdropswitchesto" -> "背景切替"
      "event_broadcast" -> "送る"
      "event_broadcastandwait" -> "送って待つ"
      "control_repeat" -> "🔄 繰り返す"
      "control_repeat_until" -> "🔄 まで繰り返す"
      "control_forever" -> "🔁 ずっと"
      "control_if" -> "❓ もし"
      "control_if_else" -> "❓ もし〜でなければ"
      "control_wait" -> "⏱️ 待つ"
      "control_wait_until" -> "⏱️ まで待つ"
      "control_stop" -> "🛑 止める"
      "control_start_as_clone" -> "クローンされたとき"
      "control_create_clone_of" -> "クローンを作る"
      "control_delete_this_clone" -> "🗑️ クローンを削除"
      "motion_movesteps" -> "➡️ 歩動かす"
      "motion_turnright" -> "↩️ 右に回す"
      "motion_turnleft" -> "↪️ 左に回す"
      "motion_gotoxy" -> "📍 x,yへ行く"
      "motion_goto" -> "📍 へ行く"
      "motion_glideto" -> "📍 へ滑る"
      "motion_glidesecstoxy" -> "📍 x,yへ滑る"
      "motion_pointindirection" -> "🧭 向きを変える"
      "motion_pointtowards" -> "🧭 へ向ける"
      "motion_changexby" -> "↔️ xを変える"
      "motion_changeyby" -> "↕️ yを変える"
      "motion_setx" -> "↔️ xを設定"
      "motion_sety" -> "↕️ yを設定"
      "motion_ifonedgebounce" -> "🔲 端に着いたら跳ね返る"
      "motion_setrotationstyle" -> "🔄 回転方法"
      "looks_say" -> "💬 言う"
      "looks_sayforsecs" -> "💬 秒言う"
      "looks_think" -> "💭 考える"
      "looks_thinkforsecs" -> "💭 秒考える"
      "looks_show" -> "👁️ 表示する"
      "looks_hide" -> "🙈 隠す"
      "looks_switchcostumeto" -> "コスチュームを変える"
      "looks_nextcostume" -> "次のコスチューム"
      "looks_switchbackdropto" -> "背景を変える"
      "looks_nextbackdrop" -> "次の背景"
      "looks_changesizeby" -> "🔍 大きさを変える"
      "looks_setsizeto" -> "🔍 大きさを設定"
      "looks_changeeffectby" -> "✨ 効果を変える"
      "looks_seteffectto" -> "✨ 効果を設定"
      "looks_cleargraphiceffects" -> "✨ 効果をなくす"
      "looks_gotofrontback" -> "📐 最前面/最背面"
      "looks_goforwardbackwardlayers" -> "📐 レイヤー移動"
      "sound_play" -> "音を鳴らす"
      "sound_playuntildone" -> "終わるまで音を鳴らす"
      "sound_stopallsounds" -> "🔇 全ての音を止める"
      "sound_setvolumeto" -> "音量を設定"
      "sound_changevolumeby" -> "音量を変える"
      "sound_seteffectto" -> "音の効果を設定"
      "sound_changeeffectby" -> "音の効果を変える"
      "sound_cleareffects" -> "音の効果をなくす"
      "sensing_askandwait" -> "❓ 聞いて待つ"
      "sensing_touchingobject" -> "👆 触れた"
      "sensing_keypressed" -> "キーが押された"
      "sensing_mousedown" -> "マウスが押された"
      "sensing_timer" -> "⏱️ タイマー"
      "sensing_resettimer" -> "⏱️ タイマーリセット"
      "data_setvariableto" -> "変数を設定"
      "data_changevariableby" -> "変数を変える"
      "data_variable" -> "変数"
      "data_showvariable" -> "変数を表示"
      "data_hidevariable" -> "変数を隠す"
      "data_addtolist" -> "リストに追加"
      "data_deleteoflist" -> "リストから削除"
      "data_deletealloflist" -> "リスト全削除"
      "data_insertatlist" -> "リストに挿入"
      "data_replaceitemoflist" -> "リスト項目を置換"
      "data_itemoflist" -> "リスト項目"
      "data_lengthoflist" -> "リスト長さ"
      "data_listcontainsitem" -> "リストに含まれる"
      "operator_add" -> "➕ 足す"
      "operator_subtract" -> "➖ 引く"
      "operator_multiply" -> "✖️ 掛ける"
      "operator_divide" -> "➗ 割る"
      "operator_random" -> "🎲 乱数"
      "operator_gt" -> "＞ より大きい"
      "operator_lt" -> "＜ より小さい"
      "operator_equals" -> "＝ 等しい"
      "operator_and" -> "かつ"
      "operator_or" -> "または"
      "operator_not" -> "ではない"
      "operator_join" -> "🔗 つなげる"
      "operator_letter_of" -> "📝 文字"
      "operator_length" -> "📏 長さ"
      "operator_mod" -> "📐 余り"
      "operator_round" -> "🔢 四捨五入"
      "operator_mathop" -> "🔢 数学関数"
      "pen_clear" -> "🖊️ 全部消す"
      "pen_stamp" -> "🖊️ スタンプ"
      "pen_penDown" -> "🖊️ ペンを下ろす"
      "pen_penUp" -> "🖊️ ペンを上げる"
      "pen_setPenColorToColor" -> "🖊️ ペンの色を設定"
      "pen_setPenSizeTo" -> "🖊️ ペンの太さを設定"
      "pen_changePenSizeBy" -> "🖊️ ペンの太さを変える"
      "pen_setPenColorParamTo" -> "🖊️ ペンのパラメータを設定"
      "pen_changePenColorParamBy" -> "🖊️ ペンのパラメータを変える"
      "pen_menu_colorParam" -> "🖊️ 色パラメータ"
      "procedures_definition" -> "定義"
      "procedures_call" -> "呼び出し"
      "procedures_prototype" -> "プロトタイプ"
      "argument_reporter_string_number" -> "📥 引数"
      "argument_reporter_boolean" -> "📥 真偽引数"
      # モーション（レポーター）
      "motion_xposition" -> "↔️ x座標"
      "motion_yposition" -> "↕️ y座標"
      "motion_direction" -> "🧭 向き"
      "motion_scroll_right" -> "↔️ 右スクロール"
      "motion_scroll_up" -> "↕️ 上スクロール"
      "motion_align_scene" -> "📐 シーンに整列"
      "motion_goto_menu" -> "📍 移動先"
      "motion_glideto_menu" -> "📍 滑る先"
      "motion_pointtowards_menu" -> "🧭 向ける先"
      # 見た目（レポーター・メニュー）
      "looks_costumenumbername" -> "コスチューム番号/名"
      "looks_backdropnumbername" -> "背景番号/名"
      "looks_size" -> "🔍 大きさ"
      "looks_costume" -> "コスチューム"
      "looks_backdrops" -> "背景"
      # 音（レポーター・メニュー）
      "sound_volume" -> "音量"
      "sound_sounds_menu" -> "サウンド"
      # センサー（未訳分）
      "sensing_touchingcolor" -> "👆 色に触れた"
      "sensing_coloristouchingcolor" -> "👆 色が色に触れた"
      "sensing_distanceto" -> "📏 距離"
      "sensing_answer" -> "💬 答え"
      "sensing_loudness" -> "音の大きさ"
      "sensing_mousex" -> "マウスのx座標"
      "sensing_mousey" -> "マウスのy座標"
      "sensing_setdragmode" -> "ドラッグモード設定"
      "sensing_current" -> "🕐 現在の時刻"
      "sensing_dayssince2000" -> "📅 2000年からの日数"
      "sensing_username" -> "👤 ユーザー名"
      "sensing_of" -> "の値"
      "sensing_of_object_menu" -> "オブジェクト"
      "sensing_distanceto_menu" -> "📏 距離の対象"
      "sensing_touchingobjectmenu" -> "👆 触れる対象"
      "sensing_keyoptions" -> "キー"
      # 演算子（未訳分）
      "operator_contains" -> "🔍 を含む"
      # データ（未訳分）
      "data_showlist" -> "リストを表示"
      "data_hidelist" -> "リストを隠す"
      # micro:bit 拡張機能
      "microbit_whenButtonPressed" -> "🔘 ボタンが押されたとき"
      "microbit_isButtonPressed" -> "🔘 ボタンが押されている"
      "microbit_whenGesture" -> "📐 動きを検知したとき"
      "microbit_displaySymbol" -> "💡 LEDに表示する"
      "microbit_displayText" -> "💡 テキストを表示する"
      "microbit_displayClear" -> "💡 LEDを消す"
      "microbit_whenTilted" -> "📐 傾いたとき"
      "microbit_isTilted" -> "📐 傾いている"
      "microbit_getTiltAngle" -> "📐 傾きの角度"
      "microbit_whenPinConnected" -> "🔌 ピンが繋がれたとき"
      "microbit_menu_buttons" -> "🔘 ボタン"
      "microbit_menu_gestures" -> "📐 動き"
      "microbit_menu_tiltDirectionAny" -> "📐 傾き方向"
      "microbit_menu_tiltDirection" -> "📐 傾き方向"
      # toio 拡張機能
      "toio_whenButtonPressed" -> "🔘 ボタンが押されたとき"
      "toio_isButtonPressed" -> "🔘 ボタンが押されている"
      "toio_moveFor" -> "🚗 方向に動かす"
      "toio_moveWheelsFor" -> "🚗 左右ホイールで動かす"
      "toio_playNoteFor" -> "🎵 音符を鳴らす"
      "toio_setLightColorFor" -> "💡 ライトの色を設定"
      "toio_turnOffLight" -> "💡 ライトを消す"
      "toio_menu_moveDirections" -> "🚗 移動方向"
      "toio_menu_changedStates" -> "変化の状態"
      "toio_menu_isChangedStates" -> "変化状態"
      _ -> opcode
    end
  end
end
