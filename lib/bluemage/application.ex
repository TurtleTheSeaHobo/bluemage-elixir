defmodule Bluemage.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      Bluemage.EoL,
      Bluemage.RTC,
      Bluemage.IMU,
      Bluemage.Scheduler,
      Bluemage.Packetizer,
      Bluemage.Experiment
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bluemage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
