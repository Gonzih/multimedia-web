defmodule Vlc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # Vlc.Repo,
      # Start the Telemetry supervisor
      VlcWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Vlc.PubSub},
      # Start the Endpoint (http/https)
      VlcWeb.Endpoint,
      Vlc.Player,
      # Start a worker by calling: Vlc.Worker.start_link(arg)
      # {Vlc.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Vlc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    VlcWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
