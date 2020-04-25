use Mix.Config

config :bluemage, Bluemage.Scheduler,
  jobs: [
    # Every minute
    {"* * * * *",	fn -> send(Bluemage.Experiment, :push) end}
  ]
config :logger, level: :debug
