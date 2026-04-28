defmodule ScratchInspectorWeb.Live.InspectorEvents do
  alias ScratchInspectorWeb.Live.InspectorUpload

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

  def handle("select_tab", %{"tab" => tab}, socket) do
    {:noreply, Phoenix.Component.assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle("toggle_sprite_code", _params, socket) do
    {:noreply, Phoenix.Component.assign(socket, :show_sprite_code, !socket.assigns.show_sprite_code)}
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
    next_detail = normalize_flow_detail(%{kind: kind, id: id, sprite: target_sprite, type: target_type})
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
    {:noreply,
     socket
     |> Phoenix.Component.assign(:project, nil)
     |> Phoenix.Component.assign(:selected_sprite, nil)
     |> Phoenix.Component.assign(:selected_target_type, nil)
     |> Phoenix.Component.assign(:upload_error, nil)
     |> Phoenix.Component.assign(:active_tab, :flow)
     |> Phoenix.Component.assign(:processing, false)
     |> Phoenix.Component.assign(:show_sprite_code, false)
     |> Phoenix.Component.assign(:flow_detail, nil)
     |> Phoenix.Component.assign(:expanded_variable_key, nil)}
  end

  def normalize_flow_detail(nil), do: nil

  def normalize_flow_detail(detail) when is_map(detail) do
    %{
      kind: Map.get(detail, :kind) || Map.get(detail, "kind"),
      id: Map.get(detail, :id) || Map.get(detail, "id"),
      sprite: Map.get(detail, :sprite) || Map.get(detail, "sprite"),
      type: Map.get(detail, :type) || Map.get(detail, "type")
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
end
