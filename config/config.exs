use Mix.Config

config :bluemage, Bluemage.Scheduler,
  jobs: [
    # Every second
    {{:extended, "* * * * *"},	fn -> send(Bluemage.EoL, {:tick, self()}) end},
    # Every minute
    {"* * * * *",	fn -> send(Bluemage.Packetizer, {:push_packet, self()}) end},
    # Every four hours (testing with every minute)
    {"0 */4 * * *", fn -> send(Bluemage.Packetizer, {:push_packet, self(), Bluemage.Diagnostic.make_packet}) end}
    #{"* * * * *", fn -> send(Bluemage.Packetizer, {:push_packet, self(), Bluemage.Diagnostic.make_packet}) end}
  ]
config :logger, level: :debug
