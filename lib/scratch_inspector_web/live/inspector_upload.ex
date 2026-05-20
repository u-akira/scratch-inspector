defmodule ScratchInspectorWeb.Live.InspectorUpload do
  import Phoenix.Component
  import Phoenix.LiveView
  require Logger
  @parse_timeout_ms 60_000

  def process(socket) do
    parent = self()
    started_at = System.monotonic_time(:millisecond)
    upload_entries = socket.assigns.uploads.scratch_file.entries
    Logger.info("[upload] process start entries=#{length(upload_entries)}")

    consumed =
      consume_uploaded_entries(socket, :scratch_file, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name) |> String.downcase()
        size = entry.client_size || 0
        temp_copy = persistent_temp_path(ext)

        Logger.info(
          "[upload] consume entry start name=#{entry.client_name} ext=#{ext} size=#{size} path=#{path}"
        )

        case File.cp(path, temp_copy) do
          :ok ->
            Logger.info("[upload] temp copy ok name=#{entry.client_name} temp=#{temp_copy}")
            {:ok, %{temp_path: temp_copy, ext: ext, name: entry.client_name}}

          {:error, reason} ->
            Logger.error("[upload] temp copy error name=#{entry.client_name} reason=#{inspect(reason)}")
            {:ok, {:copy_error, reason, entry.client_name}}
        end
      end)

    elapsed = System.monotonic_time(:millisecond) - started_at
    Logger.info("[upload] process consumed entries=#{length(consumed)} elapsed_ms=#{elapsed}")

    case consumed do
      [%{temp_path: temp_path, ext: ext, name: name}] ->
        Task.start(fn ->
          task_t0 = System.monotonic_time(:millisecond)
          Logger.info("[upload-task] parse start name=#{name} ext=#{ext} temp=#{temp_path}")

          parse_result = run_parse_with_timeout(temp_path, ext, name)

          Logger.info(
            "[upload-task] parse finished name=#{name} elapsed_ms=#{System.monotonic_time(:millisecond) - task_t0} result=#{elem(parse_result, 0)}"
          )

          Logger.info("[upload-task] send result to liveview pid=#{inspect(parent)}")
          send(parent, {:upload_parse_finished, parse_result, name, temp_path})
        end)

        {:noreply,
         socket
         |> assign(:processing, true)
         |> assign(:upload_error, nil)}

      [{:copy_error, reason, name}] ->
        Logger.error("[upload] copy failed name=#{name} reason=#{inspect(reason)}")
        {:noreply, assign(socket, :upload_error, "アップロード一時保存に失敗しました")}

      [] ->
        Logger.error("[upload] no consumed entries")
        {:noreply, assign(socket, :upload_error, "アップロードが完了していません。再試行してください。")}
    end
  end

  def finish(socket, parse_result, name, temp_path) do
    case parse_result do
      {:ok, project} ->
        parent = self()
        ext = Path.extname(name) |> String.downcase()

        Task.start(fn ->
          enrich_result =
            try do
              ScratchInspector.Parser.enrich_project_costume_images_from_archive(project, temp_path, ext)
            rescue
              e -> {:error, Exception.message(e)}
            end

          _ = File.rm(temp_path)
          send(parent, {:costume_assets_enriched, enrich_result})
        end)

        Logger.info(
          "[upload] parse success name=#{name} stage=#{not is_nil(project.stage)} sprites=#{length(project.sprites)} vars=#{length(project.variables)}"
        )

        socket
        |> assign(:project, Map.put(project, :name, name))
        |> assign(:selected_sprite, if(project.stage, do: project.stage.name, else: nil))
        |> assign(:selected_target_type, if(project.stage, do: "stage", else: nil))
        |> assign(:upload_error, nil)
        |> assign(:processing, false)
        |> assign(:expanded_variable_key, nil)

      {:error, reason} ->
        _ = File.rm(temp_path)
        Logger.error("[upload] parse error name=#{name} reason=#{inspect(reason)}")

        socket
        |> assign(:upload_error, reason)
        |> assign(:processing, false)
    end
  end

  defp persistent_temp_path(ext) do
    Path.join(
      System.tmp_dir!(),
      "scratch_inspector_#{System.system_time(:microsecond)}_#{System.unique_integer([:positive])}#{ext}"
    )
  end

  defp run_parse_with_timeout(temp_path, ext, name) do
    task =
      Task.async(fn ->
        try do
          ScratchInspector.Parser.parse(temp_path, ext)
        rescue
          e ->
            Logger.error("[upload-task] parser raised name=#{name} error=#{Exception.message(e)}")
            {:error, "パース中にエラー: #{Exception.message(e)}"}
        end
      end)

    case Task.yield(task, @parse_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("[upload-task] parse timeout name=#{name} timeout_ms=#{@parse_timeout_ms}")
        {:error, "解析がタイムアウトしました。プロジェクトが大きすぎるか、解析処理が停止しています。"}
    end
  end
end
