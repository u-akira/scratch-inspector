defmodule ScratchInspector.ProjectURLTest do
  use ExUnit.Case, async: true

  alias ScratchInspector.ProjectURL

  test "extracts a project id from a Scratch project URL" do
    assert {:ok, "123456789"} =
             ProjectURL.project_id_from_url("https://scratch.mit.edu/projects/123456789/")

    assert {:ok, "123456789"} =
             ProjectURL.project_id_from_url("https://www.scratch.mit.edu/projects/123456789")
  end

  test "rejects non-Scratch and malformed URLs" do
    assert {:error, _} = ProjectURL.project_id_from_url("https://example.com/projects/123")
    assert {:error, _} = ProjectURL.project_id_from_url("https://scratch.mit.edu/users/foo")
    assert {:error, _} = ProjectURL.project_id_from_url("javascript:alert(1)")
  end

  test "accepts only the official Scratch project host" do
    assert {:error, _} =
             ProjectURL.project_id_from_url("https://scratch.mit.edu.evil.test/projects/123")

    assert {:error, _} = ProjectURL.project_id_from_url("https://scratch.mit.edu/projects/abc")
  end

  test "parses project.json-shaped data through the shared parser" do
    json =
      Jason.encode!(%{"targets" => [%{"name" => "Sprite1", "isStage" => false, "blocks" => %{}}]})

    assert {:ok, %{sprites: [%{name: "Sprite1"}]}} = ScratchInspector.Parser.parse_json(json)
  end

  test "embeds downloaded costume and sound assets" do
    project = %{
      stage: %{
        costumes: [%{asset_file: "costume.svg", base64: nil}],
        sounds: [%{asset_file: "sound.wav", base64: nil}]
      },
      sprites: []
    }

    enriched =
      ScratchInspector.Parser.enrich_project_assets(project, [
        {~c"costume.svg", "<svg/>"},
        {~c"sound.wav", <<1, 2, 3>>}
      ])

    assert enriched.stage.costumes |> hd() |> Map.get(:base64) == Base.encode64("<svg/>")
    assert enriched.stage.sounds |> hd() |> Map.get(:base64) == Base.encode64(<<1, 2, 3>>)
  end
end
