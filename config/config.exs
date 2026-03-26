# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :scratch_inspector,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :scratch_inspector, ScratchInspectorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ScratchInspectorWeb.ErrorHTML, json: ScratchInspectorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ScratchInspector.PubSub,
  live_view: [signing_salt: "gSYGDKDw"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  scratch_inspector: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Enum.join([Path.expand("../deps", __DIR__), Path.expand("../assets/node_modules", __DIR__)], if(:os.type() == {:win32, :nt}, do: ";", else: ":"))}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  scratch_inspector: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Scratch file MIME types
config :mime, :types, %{
  "application/x-scratch" => ["sb"],
  "application/x-scratch2" => ["sb2"],
  "application/x-scratch3" => ["sb3"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
