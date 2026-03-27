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
        label = opcode_label(opcode)
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
        case val do
          [_, [literal_type, value | _]] when is_integer(literal_type) and is_binary(value) ->
            [value]

          [_, id] when is_binary(id) ->
            # reporter ブロックの場合
            case Map.get(blocks, id) do
              %{"opcode" => opc} -> [opcode_label(opc)]
              _ -> []
            end

          _ ->
            []
        end
      end)

    field_params ++ input_params
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
        blocks: chain
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

        {id, name, code_blocks}
      end)

    # procedure_call ブロックから呼び出し関係を構築
    call_map = build_call_map(blocks)

    Enum.map(definitions, fn {_def_id, name, code_blocks} ->
      callers = Map.get(call_map, name, [])

      %{
        name: name,
        called_by: callers,
        call_count: length(callers),
        code_blocks: code_blocks
      }
    end)
  end

  defp build_call_map(blocks) do
    blocks
    |> Enum.filter(fn {_id, block} ->
      is_map(block) and Map.get(block, "opcode") == "procedures_call"
    end)
    |> Enum.reduce(%{}, fn {_id, block}, acc ->
      proccode = block |> Map.get("mutation", %{}) |> Map.get("proccode", "unknown")
      # 呼び出し元のコンテキスト（親hat blockのラベル）
      caller_context = find_hat_block_label(block, blocks)
      Map.update(acc, proccode, [caller_context], &[caller_context | &1])
    end)
  end

  defp find_hat_block_label(block, blocks, visited \\ MapSet.new()) do
    parent_id = Map.get(block, "parent")

    cond do
      is_nil(parent_id) ->
        opcode_label(Map.get(block, "opcode", ""))

      MapSet.member?(visited, parent_id) ->
        "?"

      true ->
        case Map.get(blocks, parent_id) do
          parent when is_map(parent) ->
            if is_nil(Map.get(parent, "parent")) do
              opcode = Map.get(parent, "opcode", "")
              value = extract_event_value(parent)
              event_label_from_opcode(opcode, value)
            else
              find_hat_block_label(parent, blocks, MapSet.put(visited, parent_id))
            end

          _ ->
            "?"
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
    sprite_name = Map.get(target, "name")

    vars
    |> Enum.map(fn {_id, [name | _]} ->
      {readers, writers} = find_variable_refs(name, all_targets)

      %{
        name: name,
        scope: scope,
        sprite: sprite_name,
        readers: readers,
        writers: writers
      }
    end)
    |> Enum.filter(fn var ->
      Enum.any?(var.readers) or Enum.any?(var.writers)
    end)
  end

  defp find_variable_refs(var_name, targets) do
    readers =
      targets
      |> Enum.flat_map(fn t ->
        sprite_name = Map.get(t, "name", "?")
        blocks = Map.get(t, "blocks", %{})

        blocks
        |> Enum.filter(fn {_id, block} ->
          is_map(block) and
            Map.get(block, "opcode") == "data_variable" and
            block |> Map.get("fields", %{}) |> Map.get("VARIABLE", []) |> List.first() == var_name
        end)
        |> Enum.map(fn _ -> sprite_name end)
      end)
      |> Enum.uniq()

    writers =
      targets
      |> Enum.flat_map(fn t ->
        sprite_name = Map.get(t, "name", "?")
        blocks = Map.get(t, "blocks", %{})

        blocks
        |> Enum.filter(fn {_id, block} ->
          is_map(block) and
            Map.get(block, "opcode") in ["data_setvariableto", "data_changevariableby"] and
            block |> Map.get("fields", %{}) |> Map.get("VARIABLE", []) |> List.first() == var_name
        end)
        |> Enum.map(fn _ -> sprite_name end)
      end)
      |> Enum.uniq()

    {readers, writers}
  end

  # ---- labels ----

  defp event_label_from_opcode(opcode, value) do
    case opcode do
      "event_whenflagclicked" -> "🚩 緑の旗がクリックされたとき"
      "event_whenbroadcastreceived" -> "📡 「#{value}」を受け取ったとき"
      "event_whenkeypressed" -> "⌨️ 「#{value}」キーが押されたとき"
      "event_whenthisspriteclicked" -> "🖱️ スプライトがクリックされたとき"
      "event_whenstageclicked" -> "🖱️ ステージがクリックされたとき"
      "event_whenbackdropswitchesto" -> "🎨 背景が「#{value}」に切り替わったとき"
      "event_whengreaterthan" -> "📊 値が超えたとき"
      "control_start_as_clone" -> "🐑 クローンされたとき"
      _ -> opcode_label(opcode)
    end
  end

  def opcode_label(opcode) do
    case opcode do
      "event_whenflagclicked" -> "🚩 緑の旗"
      "event_whenbroadcastreceived" -> "📡 メッセージ受信"
      "event_whenkeypressed" -> "⌨️ キー押下"
      "event_whenthisspriteclicked" -> "🖱️ スプライトクリック"
      "event_whenstageclicked" -> "🖱️ ステージクリック"
      "event_whengreaterthan" -> "📊 値が超えたとき"
      "event_whenbackdropswitchesto" -> "🎨 背景切替"
      "event_broadcast" -> "📡 送る"
      "event_broadcastandwait" -> "📡 送って待つ"
      "control_repeat" -> "🔄 繰り返す"
      "control_repeat_until" -> "🔄 まで繰り返す"
      "control_forever" -> "🔁 ずっと"
      "control_if" -> "❓ もし"
      "control_if_else" -> "❓ もし〜でなければ"
      "control_wait" -> "⏱️ 待つ"
      "control_wait_until" -> "⏱️ まで待つ"
      "control_stop" -> "🛑 止める"
      "control_start_as_clone" -> "🐑 クローンされたとき"
      "control_create_clone_of" -> "🐑 クローンを作る"
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
      "looks_switchcostumeto" -> "👔 コスチュームを変える"
      "looks_nextcostume" -> "👔 次のコスチューム"
      "looks_switchbackdropto" -> "🎨 背景を変える"
      "looks_nextbackdrop" -> "🎨 次の背景"
      "looks_changesizeby" -> "🔍 大きさを変える"
      "looks_setsizeto" -> "🔍 大きさを設定"
      "looks_changeeffectby" -> "✨ 効果を変える"
      "looks_seteffectto" -> "✨ 効果を設定"
      "looks_cleargraphiceffects" -> "✨ 効果をなくす"
      "looks_gotofrontback" -> "📐 最前面/最背面"
      "looks_goforwardbackwardlayers" -> "📐 レイヤー移動"
      "sound_play" -> "🔊 音を鳴らす"
      "sound_playuntildone" -> "🔊 終わるまで音を鳴らす"
      "sound_stopallsounds" -> "🔇 全ての音を止める"
      "sound_setvolumeto" -> "🔊 音量を設定"
      "sound_changevolumeby" -> "🔊 音量を変える"
      "sound_seteffectto" -> "🔊 音の効果を設定"
      "sound_changeeffectby" -> "🔊 音の効果を変える"
      "sound_cleareffects" -> "🔊 音の効果をなくす"
      "sensing_askandwait" -> "❓ 聞いて待つ"
      "sensing_touchingobject" -> "👆 触れた"
      "sensing_keypressed" -> "⌨️ キーが押された"
      "sensing_mousedown" -> "🖱️ マウスが押された"
      "sensing_timer" -> "⏱️ タイマー"
      "sensing_resettimer" -> "⏱️ タイマーリセット"
      "data_setvariableto" -> "📦 変数を設定"
      "data_changevariableby" -> "📦 変数を変える"
      "data_variable" -> "📦 変数"
      "data_showvariable" -> "📦 変数を表示"
      "data_hidevariable" -> "📦 変数を隠す"
      "data_addtolist" -> "📋 リストに追加"
      "data_deleteoflist" -> "📋 リストから削除"
      "data_deletealloflist" -> "📋 リスト全削除"
      "data_insertatlist" -> "📋 リストに挿入"
      "data_replaceitemoflist" -> "📋 リスト項目を置換"
      "data_itemoflist" -> "📋 リスト項目"
      "data_lengthoflist" -> "📋 リスト長さ"
      "data_listcontainsitem" -> "📋 リストに含まれる"
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
      "procedures_definition" -> "🔧 定義"
      "procedures_call" -> "📞 呼び出し"
      "procedures_prototype" -> "🔧 プロトタイプ"
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
      "looks_costumenumbername" -> "👔 コスチューム番号/名"
      "looks_backdropnumbername" -> "🎨 背景番号/名"
      "looks_size" -> "🔍 大きさ"
      "looks_costume" -> "👔 コスチューム"
      "looks_backdrops" -> "🎨 背景"
      # 音（レポーター・メニュー）
      "sound_volume" -> "🔊 音量"
      "sound_sounds_menu" -> "🔊 サウンド"
      # センサー（未訳分）
      "sensing_touchingcolor" -> "👆 色に触れた"
      "sensing_coloristouchingcolor" -> "👆 色が色に触れた"
      "sensing_distanceto" -> "📏 距離"
      "sensing_answer" -> "💬 答え"
      "sensing_loudness" -> "🔊 音の大きさ"
      "sensing_mousex" -> "🖱️ マウスのx座標"
      "sensing_mousey" -> "🖱️ マウスのy座標"
      "sensing_setdragmode" -> "🖱️ ドラッグモード設定"
      "sensing_current" -> "🕐 現在の時刻"
      "sensing_dayssince2000" -> "📅 2000年からの日数"
      "sensing_username" -> "👤 ユーザー名"
      "sensing_of" -> "📊 の値"
      "sensing_of_object_menu" -> "📊 オブジェクト"
      "sensing_distanceto_menu" -> "📏 距離の対象"
      "sensing_touchingobjectmenu" -> "👆 触れる対象"
      "sensing_keyoptions" -> "⌨️ キー"
      # 演算子（未訳分）
      "operator_contains" -> "🔍 を含む"
      # データ（未訳分）
      "data_showlist" -> "📋 リストを表示"
      "data_hidelist" -> "📋 リストを隠す"
      "data_listcontainsitem" -> "📋 リストに含まれる"
      _ -> opcode
    end
  end
end
