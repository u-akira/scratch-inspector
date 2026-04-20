defmodule ScratchInspector.Parser do
  @moduledoc """
  Scratch プロジェクトファイルのパーサー。
  .sb3 / .sb2 は ZIP 内の project.json を解析。
  .sb は未対応（Scratch 1.x バイナリ形式）。
  """

  # ---- Block labels (Japanese translations) ----

  defp opcode_label("looks_seteffectto"), do: "[EFFECT] の効果を [VALUE] にする"
  defp opcode_label("operator_random"), do: "[FROM] から [TO] までの乱数"
  defp opcode_label("data_setvariableto"), do: "[VARIABLE] を [VALUE] にする"
  defp opcode_label("data_changevariableby"), do: "[VARIABLE] を [VALUE] ずつ変える"
  defp opcode_label("data_showvariable"), do: "[VARIABLE] を表示する"
  defp opcode_label("data_hidevariable"), do: "[VARIABLE] を隠す"
  defp opcode_label("control_if"), do: "もし [CONDITION] なら"
  defp opcode_label("control_if_else"), do: "もし [CONDITION] なら"
  defp opcode_label("control_repeat"), do: "[TIMES] 回繰り返す"
  defp opcode_label("control_forever"), do: "ずっと"
  defp opcode_label("control_stop"), do: "[STOP_OPTION] を止める"
  defp opcode_label("event_whenflagclicked"), do: "緑の旗がクリックされたとき"
  defp opcode_label("event_whenkeypressed"), do: "[KEY_OPTION] キーが押されたとき"
  defp opcode_label("event_whenthisspriteclicked"), do: "このスプライトがクリックされたとき"
  defp opcode_label("event_whenbackdropswitchesto"), do: "背景が [BACKDROP] になったとき"
  defp opcode_label("event_whengreaterthan"), do: "[WHENGREATERTHANMENU] > [VALUE]"
  defp opcode_label("motion_movesteps"), do: "[STEPS] 歩動かす"
  defp opcode_label("motion_turnright"), do: "時計回りに [DEGREES] 度回す"
  defp opcode_label("motion_turnleft"), do: "反時計回りに [DEGREES] 度回す"
  defp opcode_label("motion_goto"), do: "[TO] へ行く"
  defp opcode_label("motion_gotoxy"), do: "x: [X] y: [Y] へ行く"
  defp opcode_label("motion_glideto"), do: "[SECS] 秒で [TO] へ行く"
  defp opcode_label("motion_glidesecstoxy"), do: "[SECS] 秒で x: [X] y: [Y] へ行く"
  defp opcode_label("motion_pointindirection"), do: "[DIRECTION] 度に向ける"
  defp opcode_label("motion_pointtowards"), do: "[TOWARDS] へ向ける"
  defp opcode_label("motion_changexby"), do: "x座標を [DX] ずつ変える"
  defp opcode_label("motion_setx"), do: "x座標を [X] にする"
  defp opcode_label("motion_changeyby"), do: "y座標を [DY] ずつ変える"
  defp opcode_label("motion_sety"), do: "y座標を [Y] にする"
  defp opcode_label("motion_ifonedgebounce"), do: "もし端に着いたら、跳ね返る"
  defp opcode_label("motion_setrotationstyle"), do: "回転方法を [STYLE] にする"
  defp opcode_label("looks_sayforsecs"), do: "[MESSAGE] と [SECS] 秒言う"
  defp opcode_label("looks_say"), do: "[MESSAGE] と言う"
  defp opcode_label("looks_thinkforsecs"), do: "[MESSAGE] と [SECS] 秒考える"
  defp opcode_label("looks_think"), do: "[MESSAGE] を考える"
  defp opcode_label("looks_show"), do: "表示する"
  defp opcode_label("looks_hide"), do: "隠す"
  defp opcode_label("looks_changeeffectby"), do: "[EFFECT] の効果を [CHANGE] ずつ変える"
  defp opcode_label("looks_setEffectTo"), do: "[EFFECT] の効果を [VALUE] にする"
  defp opcode_label("looks_cleargraphiceffects"), do: "画像効果をなくす"
  defp opcode_label("looks_changesizeby"), do: "大きさを [CHANGE] ずつ変える"
  defp opcode_label("looks_setsizeto"), do: "大きさを [CHANGE] %にする"
  defp opcode_label("looks_gotofrontback"), do: "[FRONT_BACK] へ移動する"
  defp opcode_label("looks_goforwardbackwardlayers"), do: "[FORWARD_BACKWARD] [NUM] 層移動する"
  defp opcode_label("looks_costumenumbername"), do: "コスチュームの [NUMBER_NAME]"
  defp opcode_label("looks_costume"), do: "コスチュームを [COSTUME] にする"
  defp opcode_label("looks_switchcostumeto"), do: "コスチュームを [COSTUME] にする"
  defp opcode_label("looks_nextcostume"), do: "次のコスチュームにする"
  defp opcode_label("looks_switchbackdropto"), do: "背景を [BACKDROP] にする"
  defp opcode_label("looks_switchbackdroptoandwait"), do: "背景を [BACKDROP] にする"
  defp opcode_label("looks_nextbackdrop"), do: "次の背景にする"
  defp opcode_label("sound_playuntildone"), do: "[SOUND_MENU] を鳴らす"
  defp opcode_label("sound_play"), do: "[SOUND_MENU] を鳴らす"
  defp opcode_label("sound_stopallsounds"), do: "すべての音を止める"
  defp opcode_label("sound_changeeffectby"), do: "[EFFECT] の効果を [VALUE] ずつ変える"
  defp opcode_label("sound_seteffectto"), do: "[EFFECT] の効果を [VALUE] にする"
  defp opcode_label("sound_cleareffects"), do: "音の効果をなくす"
  defp opcode_label("sound_changevolumeby"), do: "音量を [VOLUME] ずつ変える"
  defp opcode_label("sound_setvolumeto"), do: "音量を [VOLUME] %にする"
  defp opcode_label("sound_volume"), do: "音量"
  defp opcode_label("event_broadcast"), do: "[BROADCAST_INPUT] を送る"
  defp opcode_label("event_broadcastandwait"), do: "[BROADCAST_INPUT] を送って待つ"
  defp opcode_label("control_wait"), do: "[DURATION] 秒待つ"
  defp opcode_label("control_repeat_until"), do: "[CONDITION] まで繰り返す"
  defp opcode_label("control_while"), do: "[CONDITION] の間繰り返す"
  defp opcode_label("control_for_each"), do: "[VARIABLE] を [VALUE] から [VALUE2] まで使う"
  defp opcode_label("control_start_as_clone"), do: "クローンされたとき"
  defp opcode_label("control_create_clone_of"), do: "[CLONE_OPTION] のクローンを作る"
  defp opcode_label("control_delete_this_clone"), do: "このクローンを削除する"
  defp opcode_label("sensing_touchingobject"), do: "[TOUCHINGOBJECTMENU] に触れた"
  defp opcode_label("sensing_touchingcolor"), do: "[COLOR] 色に触れた"
  defp opcode_label("sensing_coloristouchingcolor"), do: "[COLOR] 色が [COLOR2] 色に触れた"
  defp opcode_label("sensing_distanceto"), do: "[DISTANCETOMENU] までの距離"
  defp opcode_label("sensing_askandwait"), do: "[QUESTION] と聞いて待つ"
  defp opcode_label("sensing_answer"), do: "答え"
  defp opcode_label("sensing_keypressed"), do: "[KEY_OPTION] キーが押された"
  defp opcode_label("sensing_mousedown"), do: "マウスが押された"
  defp opcode_label("sensing_mousex"), do: "マウスのx座標"
  defp opcode_label("sensing_mousey"), do: "マウスのy座標"
  defp opcode_label("sensing_setdragmode"), do: "ドラッグモードを [DRAG_MODE] にする"
  defp opcode_label("sensing_loudness"), do: "音量"
  defp opcode_label("sensing_timer"), do: "タイマー"
  defp opcode_label("sensing_resettimer"), do: "タイマーをリセット"
  defp opcode_label("sensing_of"), do: "[OBJECT] の [PROPERTY]"
  defp opcode_label("sensing_current"), do: "現在の [CURRENTMENU]"
  defp opcode_label("sensing_dayssince2000"), do: "2000年からの日数"
  defp opcode_label("sensing_username"), do: "ユーザー名"
  defp opcode_label("operator_add"), do: "[NUM1] + [NUM2]"
  defp opcode_label("operator_subtract"), do: "[NUM1] - [NUM2]"
  defp opcode_label("operator_multiply"), do: "[NUM1] * [NUM2]"
  defp opcode_label("operator_divide"), do: "[NUM1] / [NUM2]"
  defp opcode_label("operator_random"), do: "[FROM] から [TO] までの乱数"
  defp opcode_label("operator_gt"), do: "[OPERAND1] > [OPERAND2]"
  defp opcode_label("operator_lt"), do: "[OPERAND1] < [OPERAND2]"
  defp opcode_label("operator_equals"), do: "[OPERAND1] = [OPERAND2]"
  defp opcode_label("operator_and"), do: "[OPERAND1] かつ [OPERAND2]"
  defp opcode_label("operator_or"), do: "[OPERAND1] または [OPERAND2]"
  defp opcode_label("operator_not"), do: "[OPERAND] ではない"
  defp opcode_label("operator_join"), do: "[STRING1] と [STRING2]"
  defp opcode_label("operator_letter_of"), do: "[STRING] の [LETTER] 番目の文字"
  defp opcode_label("operator_length"), do: "[STRING] の長さ"
  defp opcode_label("operator_contains"), do: "[STRING1] に [STRING2] が含まれる"
  defp opcode_label("operator_mod"), do: "[NUM1] を [NUM2] で割った余り"
  defp opcode_label("operator_round"), do: "[NUM] を丸める"
  defp opcode_label("operator_mathop"), do: "[OPERATOR] の [NUM]"
  defp opcode_label("data_variable"), do: "[VARIABLE]"
  defp opcode_label("data_listcontents"), do: "[LIST]"
  defp opcode_label("data_addtolist"), do: "[ITEM] を [LIST] に追加する"
  defp opcode_label("data_deleteoflist"), do: "[LIST] の [INDEX] 番目を削除する"
  defp opcode_label("data_deletealloflist"), do: "[LIST] のすべてを削除する"
  defp opcode_label("data_insertatlist"), do: "[ITEM] を [LIST] の [INDEX] 番目に挿入する"
  defp opcode_label("data_replaceitemoflist"), do: "[LIST] の [INDEX] 番目を [ITEM] で置き換える"
  defp opcode_label("data_itemoflist"), do: "[LIST] の [INDEX] 番目"
  defp opcode_label("data_itemnumoflist"), do: "[ITEM] の [LIST] での位置"
  defp opcode_label("data_lengthoflist"), do: "[LIST] の長さ"
  defp opcode_label("data_listcontainsitem"), do: "[LIST] に [ITEM] が含まれる"
  defp opcode_label("pen_clear"), do: "全部消す"
  defp opcode_label("pen_stamp"), do: "スタンプ"
  defp opcode_label("pen_penDown"), do: "ペンを下ろす"
  defp opcode_label("pen_penUp"), do: "ペンを上げる"
  defp opcode_label("pen_setPenColorToColor"), do: "ペンの色を [COLOR] にする"
  defp opcode_label("pen_changePenColorParamBy"), do: "ペンの [COLOR_PARAM] を [VALUE] ずつ変える"
  defp opcode_label("pen_setPenColorParamTo"), do: "ペンの [COLOR_PARAM] を [VALUE] にする"
  defp opcode_label("pen_changePenSizeBy"), do: "ペンの太さを [SIZE] ずつ変える"
  defp opcode_label("pen_setPenSizeTo"), do: "ペンの太さを [SIZE] にする"
  # Custom blocks
  defp opcode_label("procedures_definition"), do: "定義"
  defp opcode_label("procedures_call"), do: "custom block"
  # Fallback
  defp opcode_label(opcode), do: opcode

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
  defp build_detail_stack(nil, _blocks), do: []

  defp build_render_stack(start_id, blocks) do
    build_detail_stack(start_id, blocks)
  end

  defp build_detail_stack(start_id, blocks) do
    case Map.get(blocks, start_id) do
      block when is_map(block) ->
        current = build_detail_block(start_id, block, blocks)
        next_id = Map.get(block, "next")
        [current | build_detail_stack(next_id, blocks)]

      _ ->
        []
    end
  end

  defp build_render_block(id, block, blocks) do
    build_detail_block(id, block, blocks)
  end

  defp build_detail_block(id, block, blocks) do
    opcode = Map.get(block, "opcode", "")
    inputs = Map.get(block, "inputs", %{})
    fields = Map.get(block, "fields", %{})

    %{
      id: id,
      opcode: opcode,
      category: block_category(opcode),
      shape: block_shape(opcode),
      next: Map.get(block, "next"),
      mutation: Map.get(block, "mutation", %{}),
      fields: normalize_detail_fields(fields),
      inputs: normalize_detail_inputs(inputs, blocks),
      children: normalize_detail_children(inputs, blocks),
      label: render_block_label(block),
      parts: render_block_parts(fields, inputs, blocks),
      branches: render_block_branches(inputs, blocks)
    }
  end

  defp normalize_detail_fields(fields) do
    fields
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {key, value} ->
      %{
        name: key,
        value: render_field_value(value)
      }
    end)
  end

  defp normalize_detail_inputs(inputs, blocks) do
    inputs
    |> Enum.reject(fn {key, _} ->
      String.starts_with?(key, "SUBSTACK") or key == "custom_block"
    end)
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {key, value} ->
      %{
        name: key,
        slot: input_slot_shape(key, value, blocks),
        value: normalize_detail_input_value(value, blocks)
      }
    end)
  end

  defp normalize_detail_input_value([_, second], blocks), do: normalize_detail_input_atom(second, blocks)
  defp normalize_detail_input_value([_, second, _fallback], blocks), do: normalize_detail_input_atom(second, blocks)
  defp normalize_detail_input_value(_, _blocks), do: nil

  defp normalize_detail_input_atom([type, value | _], _blocks) when is_binary(value) or is_number(value) do
    %{kind: :literal, input_type: type, value: to_string(value)}
  end

  defp normalize_detail_input_atom(id, blocks) when is_binary(id) do
    case Map.get(blocks, id) do
      block when is_map(block) ->
        %{kind: :block, block: build_detail_block(id, block, blocks)}

      _ ->
        %{kind: :literal, value: "?"}
    end
  end

  defp normalize_detail_input_atom(_, _blocks), do: nil

  defp normalize_detail_children(inputs, blocks) do
    inputs
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, "SUBSTACK") end)
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {key, value} ->
      %{
        name: key,
        blocks: build_detail_stack(extract_input_id(value), blocks)
      }
    end)
    |> Enum.reject(fn child -> Enum.empty?(child.blocks) end)
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

      # Boolean reporters (hexagon shape)
      opcode in ["operator_gt", "operator_lt", "operator_equals", "operator_and", "operator_or", "operator_not"] ->
        :reporter_boolean

      # Value reporters (oval shape)
      String.starts_with?(opcode, "operator_") or String.starts_with?(opcode, "sensing_") or
      opcode in ["data_variable", "data_listcontents", "argument_reporter_boolean", "argument_reporter_string_number"] ->
        :reporter_round

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

  defp build_custom_block_detail_header(def_id, proto, next_id, blocks) do
    proto = proto || %{}
    mutation = Map.get(proto, "mutation", %{})
    fields = Map.get(proto, "fields", %{})
    inputs = Map.get(proto, "inputs", %{})

    %{
      id: def_id,
      opcode: "procedures_definition",
      category: :custom,
      shape: :hat,
      next: next_id,
      mutation: mutation,
      fields: normalize_detail_fields(fields),
      inputs: normalize_detail_inputs(inputs, blocks),
      children: normalize_detail_children(inputs, blocks),
      label: Map.get(mutation, "proccode", "custom block"),
      parts: render_block_parts(fields, inputs, blocks),
      branches: render_block_branches(inputs, blocks)
    }
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
        detail_header: %{
          id: id,
          opcode: opcode,
          category: :event,
          shape: :hat,
          next: next_id,
          mutation: %{},
          fields: [],
          inputs: [],
          children: [],
          label: label,
          parts: [],
          branches: []
        },
        detail_blocks: build_detail_stack(next_id, blocks),
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
        detail_header = build_custom_block_detail_header(id, proto, next_id, blocks)
        detail_blocks = build_detail_stack(next_id, blocks)

        {id, name, code_blocks, render_blocks, detail_header, detail_blocks}
      end)

    # procedure_call ブロックから呼び出し関係を構築
    call_map = build_call_map(blocks)

    Enum.map(definitions, fn {_def_id, name, code_blocks, render_blocks, detail_header, detail_blocks} ->
      callers = Map.get(call_map, name, [])

      %{
        name: name,
        called_by: callers,
        call_count: length(callers),
        code_blocks: code_blocks,
        render_blocks: render_blocks,
        detail_header: detail_header,
        detail_blocks: detail_blocks
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
end
