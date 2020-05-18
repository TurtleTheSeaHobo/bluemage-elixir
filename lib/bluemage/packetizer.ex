defmodule Bluemage.Packetizer do
  alias Bluemage.Experiment
  alias Bluemage.RTC
  require Logger

  # Sends message to named process, then awaits and returns reply
  defp yell(target, body, timeout \\ 1_000) do
    target_pid = Process.whereis(target)
    send(target_pid, body)

    receive do
      {reply, pid} when pid == target_pid -> {reply, pid}
    after
      timeout -> {:err, :timed_out}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    pid = spawn_link(__MODULE__, :init, [opts])
    Process.register(pid, Bluemage.Packetizer)
    {:ok, pid}
  end

  def init(_opts) do
    packet = %{
      "info" => %{
        "name" => "Bluemage",
        "team" => "LSN-SEDS"
      },
      "data" => []
    }

    loop(packet)
  end

  def loop(internal_packet) do
    receive do
      {:push_packet, pid} ->
        send(pid, {:ok, self()})
        push_packet(internal_packet)

      {:update_packet, pid, datapoint} ->
        send(pid, {:ok, self()})
        update_packet(internal_packet, datapoint)

      {:push_packet, pid, external_packet} ->
        send(pid, {:ok, self()})
        push_packet(external_packet)
        internal_packet
    end
    |> loop
  end

  def push_packet(%{"data" => _} = packet) do
    {:ok, file} =
      File.open(
        "/tmp/experiment/" <>
          Integer.to_string(yell(RTC, {:get_epoch, self()}) |> elem(0)) <> ".json",
        [:write]
      )

    IO.binwrite(file, Jason.encode!(%{packet | "data" => Enum.reverse(packet["data"])}))
    File.close(file)

    %{packet | "data" => []}
  end

  def push_packet(packet) do
    {:ok, file} =
      File.open(
        "/tmp/experiment/" <>
          Integer.to_string(yell(RTC, {:get_epoch, self()}) |> elem(0)) <> "SP" <> ".json",
        [:write]
      )

    IO.binwrite(file, Jason.encode!(packet))
    File.close(file)

    packet
  end

  def update_packet(packet, datapoint) do
    %{packet | "data" => [datapoint] ++ packet["data"]}
  end
end
