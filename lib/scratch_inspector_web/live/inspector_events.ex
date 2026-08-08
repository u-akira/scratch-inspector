defmodule ScratchInspectorWeb.Live.InspectorEvents do
  alias ScratchInspectorWeb.Live.DeferredTargetCompactor
  alias ScratchInspectorWeb.Live.InspectorUpload
  require Logger
  @deferred_enrich_timeout_ms 20_000

  def handle("validate", _params, socket) do
    {:noreply, Phoenix.Component.assign(socket, :upload_error, nil)}
  end

  def handle("upload", _params, socket), do: InspectorUpload.process(socket)

  def handle("select_sprite", %{"name" => name, "type" => type}, socket) do
    {:noreply,
     socket
     |> Phoenix.Component.assign(:selected_sprite, name)
     |> Phoenix.Component.assign(:selected_target_type, type)
     |> Phoenix.Component.assign(:show_sprite_code, false)
     |> Phoenix.Component.assign(:flow_detail, nil)
     |> Phoenix.Component.assign(:expanded_variable_key, nil)}
  end

  def handle("analyze_deferred_target", %{"name" => name, "type" => type}, socket) do
    cond do
      not is_nil(socket.assigns.deferred_target) ->
        {:noreply, socket}

      not is_binary(socket.assigns.uploaded_archive_path) ->
        {:noreply,
         Phoenix.Component.assign(
           socket,
           :analysis_errors,
           put_analysis_error(
             socket.assigns.analysis_errors,
             type,
             name,
             "Uploaded archive is no longer available."
           )
         )}

      true ->
        case find_target(socket.assigns.project, name, type) do
          %{deferred_analysis: true} ->
            parent = self()
            path = socket.assigns.uploaded_archive_path
            ext = socket.assigns.uploaded_archive_ext

            Logger.info(
              "[deferred] enriching target from archive start name=#{name} type=#{type}"
            )

            Task.start(fn ->
              enriched = run_deferred_enrich_with_timeout(path, ext, name, type)

              send(
                parent,
                {:deferred_enrich_finished, name, type, compact_enrich_result(enriched)}
              )
            end)

            {:noreply,
             socket
             |> Phoenix.Component.assign(:deferred_target, %{name: name, type: type})
             |> Phoenix.Component.assign(
               :analysis_errors,
               clear_analysis_error(socket.assigns.analysis_errors, type, name)
             )
             |> Phoenix.Component.assign(:upload_error, nil)}

          _ ->
            {:noreply, socket}
        end
    end
  end

  def handle("select_tab", %{"tab" => tab}, socket) do
    {:noreply, Phoenix.Component.assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle("toggle_sprite_code", _params, socket) do
    {:noreply,
     Phoenix.Component.assign(socket, :show_sprite_code, !socket.assigns.show_sprite_code)}
  end

  def handle("flow_select_detail", %{"kind" => kind, "id" => id} = params, socket) do
    target_sprite = Map.get(params, "sprite")
    target_type = Map.get(params, "type")

    socket =
      case {target_sprite, target_type} do
        {sprite, type} when is_binary(sprite) and is_binary(type) ->
          socket
          |> Phoenix.Component.assign(:selected_sprite, sprite)
          |> Phoenix.Component.assign(:selected_target_type, type)

        _ ->
          socket
      end

    current = normalize_flow_detail(socket.assigns.flow_detail)

    next_detail =
      normalize_flow_detail(%{kind: kind, id: id, sprite: target_sprite, type: target_type})

    next = if flow_detail_same?(current, next_detail), do: nil, else: next_detail

    {:noreply, Phoenix.Component.assign(socket, :flow_detail, next)}
  end

  def handle("toggle_variable_detail", %{"key" => key}, socket) do
    next = if socket.assigns.expanded_variable_key == key, do: nil, else: key
    {:noreply, Phoenix.Component.assign(socket, :expanded_variable_key, next)}
  end

  def handle("jump_to_variable_usage", params, socket) do
    {:noreply,
     socket
     |> Phoenix.Component.assign(:selected_sprite, params["sprite"])
     |> Phoenix.Component.assign(:selected_target_type, params["type"])
     |> Phoenix.Component.assign(:active_tab, :flow)
     |> Phoenix.Component.assign(
       :flow_detail,
       normalize_flow_detail(%{
         kind: params["detail-kind"],
         id: params["detail-id"],
         sprite: params["sprite"],
         type: params["type"]
       })
     )}
  end

  def handle("reset", _params, socket) do
    InspectorUpload.cleanup_uploaded_archive(socket)

    {:noreply,
     socket
     |> Phoenix.Component.assign(:project, nil)
     |> Phoenix.Component.assign(:selected_sprite, nil)
     |> Phoenix.Component.assign(:selected_target_type, nil)
     |> Phoenix.Component.assign(:upload_error, nil)
     |> Phoenix.Component.assign(:active_tab, :flow)
     |> Phoenix.Component.assign(:processing, false)
     |> Phoenix.Component.assign(:deferred_target, nil)
     |> Phoenix.Component.assign(:uploaded_archive_path, nil)
     |> Phoenix.Component.assign(:uploaded_archive_ext, nil)
     |> Phoenix.Component.assign(:analysis_errors, %{})
     |> Phoenix.Component.assign(:show_sprite_code, false)
     |> Phoenix.Component.assign(:flow_detail, nil)
     |> Phoenix.Component.assign(:expanded_variable_key, nil)}
  end

  def normalize_flow_detail(nil), do: nil

  def normalize_flow_detail(detail) when is_map(detail) do
    %{
      kind: normalize_flow_detail_part(Map.get(detail, :kind) || Map.get(detail, "kind")),
      id: normalize_flow_detail_part(Map.get(detail, :id) || Map.get(detail, "id")),
      sprite: Map.get(detail, :sprite) || Map.get(detail, "sprite"),
      type: Map.get(detail, :type) || Map.get(detail, "type"),
      hat_opcode:
        normalize_flow_detail_part(Map.get(detail, :hat_opcode) || Map.get(detail, "hat_opcode")),
      hat_label:
        normalize_flow_detail_part(Map.get(detail, :hat_label) || Map.get(detail, "hat_label"))
    }
    |> then(fn normalized ->
      if is_binary(normalized.kind) and is_binary(normalized.id), do: normalized, else: nil
    end)
  end

  def normalize_flow_detail(_), do: nil

  def flow_detail_same?(nil, nil), do: true

  def flow_detail_same?(left, right) when is_map(left) and is_map(right) do
    left.kind == right.kind and left.id == right.id and left.sprite == right.sprite and
      left.type == right.type
  end

  def flow_detail_same?(_, _), do: false

  defp normalize_flow_detail_part(nil), do: nil
  defp normalize_flow_detail_part(value) when is_binary(value), do: value
  defp normalize_flow_detail_part(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_flow_detail_part(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_flow_detail_part(value) when is_float(value), do: Float.to_string(value)
  defp normalize_flow_detail_part(_), do: nil

  defp find_target(project, name, "stage") do
    if project.stage && project.stage.name == name, do: project.stage, else: nil
  end

  defp find_target(project, name, _type) do
    Enum.find(project.sprites, &(&1.name == name))
  end

  defp run_deferred_enrich_with_timeout(path, ext, name, type) do
    task =
      Task.async(fn ->
        try do
          ScratchInspector.Parser.enrich_target_from_archive(path, ext, name, type)
        rescue
          e ->
            {:error, Exception.message(e)}
        end
      end)

    case Task.yield(task, @deferred_enrich_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:error, _} = err} ->
        err

      {:ok, {:ok, enriched}} ->
        Logger.info("[deferred] enrich full success name=#{name} type=#{type}")
        enriched

      nil ->
        Logger.warning(
          "[deferred] enrich timeout fallback name=#{name} type=#{type} timeout_ms=#{@deferred_enrich_timeout_ms}"
        )

        {:error, "Detailed analysis timed out. Lightweight flow is still available."}
    end
  end

  defp compact_enrich_result({:error, _reason} = error), do: error

  defp compact_enrich_result(enriched) when is_map(enriched),
    do: DeferredTargetCompactor.compact_for_message(enriched)

  defp put_analysis_error(errors, type, name, message) do
    Map.put(errors || %{}, analysis_key(type, name), message)
  end

  defp clear_analysis_error(errors, type, name) do
    Map.delete(errors || %{}, analysis_key(type, name))
  end

  defp analysis_key(type, name), do: "#{type}:#{name}"
end
