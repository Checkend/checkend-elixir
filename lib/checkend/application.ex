defmodule Checkend.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Checkend.Worker, []}
    ]

    opts = [strategy: :one_for_one, name: Checkend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
