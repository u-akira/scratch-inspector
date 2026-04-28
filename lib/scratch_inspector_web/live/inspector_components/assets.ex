defmodule ScratchInspectorWeb.Live.InspectorComponents.Assets do
  use ScratchInspectorWeb, :html

  attr :target, :map, default: nil
  def costumes_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        コスチューム
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— {display_name(@target)}</span>
        <% end %>
      </h2>
      <%= if @target && Enum.any?(@target.costumes) do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          <%= for {costume, idx} <- Enum.with_index(@target.costumes) do %>
            <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <div class="aspect-square bg-gray-50 flex items-center justify-center p-2 border-b border-gray-100">
                <%= if costume.base64 do %>
                  <img src={"data:#{costume.mime};base64,#{costume.base64}"} alt={costume.name} class="max-w-full max-h-full object-contain" />
                <% else %>
                  <span class="text-3xl text-gray-300">🖼️</span>
                <% end %>
              </div>
              <div class="p-2 text-center">
                <p class="text-xs font-medium text-gray-700 truncate">{costume.name}</p>
                <p class="text-[10px] text-gray-400 uppercase">{costume.data_format} #{idx + 1}</p>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="👔" message="コスチュームがありません" />
      <% end %>
    </div>
    """
  end

  attr :target, :map, default: nil
  def sounds_panel(assigns) do
    ~H"""
    <div>
      <h2 class="text-base font-semibold text-gray-700 mb-4">
        サウンド
        <%= if @target do %>
          <span class="text-gray-400 font-normal">— {display_name(@target)}</span>
        <% end %>
      </h2>
      <%= if @target && Enum.any?(@target.sounds) do %>
        <div class="space-y-3">
          <%= for sound <- @target.sounds do %>
            <div class="bg-white rounded-xl border border-gray-200 p-4">
              <div class="flex items-center gap-3">
                <span class="text-2xl">🔊</span>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-gray-800 text-sm">{sound.name}</p>
                  <p class="text-[10px] text-gray-400 uppercase mt-0.5">
                    {sound.data_format}
                    <%= if sound.rate do %>
                      · {div(sound.rate, 1000)}kHz
                    <% end %>
                    <%= if sound.sample_count && sound.rate do %>
                      · {Float.round(sound.sample_count / sound.rate, 1)}秒
                    <% end %>
                  </p>
                </div>
              </div>
              <%= if sound.base64 do %>
                <div class="mt-3">
                  <audio controls class="w-full h-8" preload="none">
                    <source src={"data:#{sound.mime};base64,#{sound.base64}"} type={sound.mime} />
                  </audio>
                </div>
              <% else %>
                <p class="mt-2 text-xs text-gray-400 italic">音声データが見つかりません</p>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <.empty_state icon="🔊" message="サウンドがありません" />
      <% end %>
    </div>
    """
  end

  attr :sprite, :map, required: true
  def sprite_thumbnail(assigns) do
    first_costume = List.first(assigns.sprite.costumes || [])
    assigns = assign(assigns, :costume, first_costume)

    ~H"""
    <%= if @costume && @costume.base64 do %>
      <img src={"data:#{@costume.mime};base64,#{@costume.base64}"} alt={@sprite.name} class="w-8 h-8 object-contain flex-shrink-0 rounded" />
    <% else %>
      <span class="flex-shrink-0">{if @sprite.is_stage, do: "🎭", else: "🐱"}</span>
    <% end %>
    """
  end

  attr :icon, :string, required: true
  attr :message, :string, required: true
  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <%= if @icon != "" do %>
        <span class="text-4xl mb-3">{@icon}</span>
      <% end %>
      <p class="text-gray-400 text-sm">{@message}</p>
    </div>
    """
  end

  def display_name(%{is_stage: true}), do: "背景"
  def display_name(%{name: name}), do: name
end
