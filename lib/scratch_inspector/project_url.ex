defmodule ScratchInspector.ProjectURL do
  @moduledoc "Scratch プロジェクトURLから project.json を取得する。"

  @http_timeout 30_000
  @max_response_bytes 100_000_000
  @scratch_hosts ["scratch.mit.edu", "www.scratch.mit.edu"]

  def fetch(url) when is_binary(url) do
    with {:ok, uri} <- validate_url(url),
         {:ok, project_id} <- project_id(uri),
         {:ok, metadata_body} <- get("https://api.scratch.mit.edu/projects/#{project_id}"),
         {:ok, metadata} <- decode_metadata(metadata_body),
         token when is_binary(token) <- Map.get(metadata, "project_token"),
         {:ok, body} <- get(project_json_url(project_id, token)),
         {:ok, project} <- ScratchInspector.Parser.parse_json(body, defer_heavy: false) do
      project = ScratchInspector.Parser.enrich_project_assets(project, download_assets(project))
      {:ok, project, "Scratch プロジェクト #{project_id}"}
    else
      nil -> {:error, "プロジェクトのコードを取得できません（非公開または削除済みの可能性があります）"}
      {:error, %Jason.DecodeError{}} -> {:error, "取得したプロジェクトデータを解析できません"}
      {:error, _reason} = error -> error
    end
  end

  def fetch(_), do: {:error, "URLを入力してください"}

  def project_id_from_url(url) when is_binary(url) do
    with {:ok, uri} <- validate_url(url), do: project_id(uri)
  end

  def project_id_from_url(_), do: {:error, "URLが正しくありません"}

  defp decode_metadata(body) do
    case Jason.decode(body) do
      {:ok, metadata} when is_map(metadata) -> {:ok, metadata}
      {:ok, _} -> {:error, "取得したプロジェクト情報が正しくありません"}
      {:error, _} -> {:error, "取得したプロジェクト情報を解析できません"}
    end
  end

  defp project_json_url(project_id, token) do
    "https://projects.scratch.mit.edu/#{project_id}?#{URI.encode_query(%{"token" => token})}"
  end

  defp download_assets(project) do
    project
    |> asset_names()
    |> Enum.reduce([], fn asset, files ->
      case get("https://assets.scratch.mit.edu/internalapi/asset/#{asset}/get/") do
        {:ok, binary} when byte_size(binary) <= 10_000_000 ->
          [{String.to_charlist(asset), binary} | files]

        _ ->
          files
      end
    end)
  end

  defp asset_names(project) do
    [project.stage | project.sprites]
    |> Enum.filter(&is_map/1)
    |> Enum.flat_map(fn target ->
      Enum.map(target.costumes || [], & &1.asset_file) ++
        Enum.map(target.sounds || [], & &1.asset_file)
    end)
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  defp validate_url(url) do
    uri = URI.parse(String.trim(url))

    if uri.scheme in ["http", "https"] and uri.host in @scratch_hosts and is_nil(uri.userinfo) do
      {:ok, uri}
    else
      {:error, "ScratchプロジェクトのURL（https://scratch.mit.edu/projects/123/）を入力してください"}
    end
  end

  defp project_id(%URI{path: path}) do
    case Regex.run(~r{^/projects/(\d+)(?:/|$)}, path || "", capture: :all_but_first) do
      [id] -> {:ok, id}
      _ -> {:error, "ScratchプロジェクトURLからプロジェクトIDを取得できません"}
    end
  end

  defp get(url) do
    :inets.start()
    :ssl.start()

    request =
      {String.to_charlist(url),
       [{~c"accept", ~c"application/json"}, {~c"user-agent", ~c"ScratchInspector/0.1"}]}

    options = [
      timeout: @http_timeout,
      connect_timeout: 10_000,
      autoredirect: false,
      ssl: [
        verify: :verify_peer,
        cacertfile: String.to_charlist(CAStore.file_path()),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    case :httpc.request(:get, request, options, body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}}
      when byte_size(body) <= @max_response_bytes ->
        {:ok, body}

      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        {:error, "プロジェクトの取得に失敗しました（HTTP #{status}）"}

      {:error, reason} ->
        {:error, "プロジェクトの取得に失敗しました: #{inspect(reason)}"}
    end
  end
end
