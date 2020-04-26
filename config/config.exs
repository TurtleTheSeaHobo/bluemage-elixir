use Mix.Config

config :bluemage, Bluemage.Scheduler,
  jobs: [
    # Every minute
    {"* * * * *",	fn -> send(Bluemage.Packetizer, {:push_packet, self()}) end}
  ]
config :logger, level: :debug
