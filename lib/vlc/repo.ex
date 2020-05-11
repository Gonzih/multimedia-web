defmodule Vlc.Repo do
  use Ecto.Repo,
    otp_app: :vlc,
    adapter: Ecto.Adapters.Postgres
end
