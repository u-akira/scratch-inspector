defmodule ScratchInspectorWeb.Live.InspectorComponents.AssetsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias ScratchInspectorWeb.Live.InspectorComponents.Assets

  test "sound players are keyed by asset and use direct audio sources" do
    target = %{
      name: "Sprite1",
      sounds: [
        %{
          name: "decision",
          data_format: "mp3",
          mime: "audio/mpeg",
          base64: Base.encode64("decision-audio"),
          asset_file: "decision.mp3",
          rate: 48_000,
          sample_count: 24_000
        },
        %{
          name: "pop",
          data_format: "mp3",
          mime: "audio/mpeg",
          base64: Base.encode64("pop-audio"),
          asset_file: "pop.mp3",
          rate: 48_000,
          sample_count: 12_000
        }
      ]
    }

    html = render_component(&Assets.sounds_panel/1, target: target)

    assert html =~ ~s(phx-update="replace")
    assert html =~ ~s(src="data:audio/mpeg;base64,#{Base.encode64("decision-audio")}")
    assert html =~ ~s(src="data:audio/mpeg;base64,#{Base.encode64("pop-audio")}")
    assert html =~ ~s(id="sound-player-0-)
    assert html =~ ~s(id="sound-player-1-)
  end
end
