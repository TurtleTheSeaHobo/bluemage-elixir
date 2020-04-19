use Mix.Config

config :bluemage, Bluemage.Scheduler,
  jobs: [
    # Every minute
    #{"* * * * *",      fn -> System.cmd("echo", ["foo"]) end}
  ]
config :logger, level: :debug
