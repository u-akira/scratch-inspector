defmodule ScratchInspectorWeb.Live.InspectorURL do
  import Phoenix.Component

  def process(socket, url) do
    parent = self()
    url = String.trim(url || "")

    if url == "" do
      {:noreply, assign(socket, :upload_error, "URLを入力してください")}
    else
      Task.start(fn ->
        result =
          try do
            ScratchInspector.ProjectURL.fetch(url)
          rescue
            e -> {:error, "URL取得中にエラー: #{Exception.message(e)}"}
          end

        send(parent, {:url_parse_finished, result})
      end)

      {:noreply, socket |> assign(:processing, true) |> assign(:upload_error, nil)}
    end
  end
end
