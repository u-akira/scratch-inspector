defmodule ScratchInspectorWeb.Live.InspectorUI do
  def tabs do
    [
      {:flow, "フロー", ""},
      {:variables, "変数", ""},
      {:costumes, "コスチューム", ""},
      {:sounds, "サウンド", ""}
    ]
  end

  def upload_error_text(:too_large), do: "ファイルが大きすぎます（最大 50MB）"
  def upload_error_text(:not_accepted), do: "対応していないファイル形式です"
  def upload_error_text(:too_many_files), do: "ファイルは1つだけ選択してください"
  def upload_error_text(_), do: "アップロードエラーが発生しました"
end
