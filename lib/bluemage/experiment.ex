defmodule Bluemage.Experiment do
  alias Bluemage.IMU
  alias Bluemage.RTC
  alias Bluemage.Ahrs
  alias Bluemage.Quaternion
  alias Bluemage.Packetizer
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
    Process.register(pid, Bluemage.Experiment)
    {:ok, pid}
  end

  def init(_opts) do
    Logger.info("Creating buffer and experiment tmp directories...")

    :os.cmd('mkdir -p /tmp/buffer/')
    :os.cmd('mkdir -p /tmp/experiment/')

    Logger.info("Checking for IMU and RTC driver readiness...")

    case yell(IMU, {:ready?, self()}, 10_000) do
      {true, _pid} -> Logger.info("Got ready signal from IMU driver.")
      {:err, :timed_out} -> Logger.info("Timed out waiting for ready signal from IMU driver.")
    end

    case yell(RTC, {:ready?, self()}, 10_000) do
      {true, _pid} -> Logger.info("Got ready signal from RTC driver.")
      {:err, :timed_out} -> Logger.info("Timed out waiting for ready signal from RTC driver.")
    end

    datapoint = [%Bluemage.Quaternion{}, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    loop(datapoint, 1)
  end

  # Main loop. Updates data at 100Hz and pushes packets at 50Hz.
  def loop(datapoint, 0) do
    receive do
    after
      0_010 ->
        yell(Packetizer, {:update_packet, self(), datapoint})
        update_datapoint(datapoint)
    end
    |> loop(1)
  end

  def loop(datapoint, 1) do
    receive do
    after
      0_010 ->
        update_datapoint(datapoint)
    end
    |> loop(0)
  end

  def update_datapoint([quaternion | _]) do
    [
      gx: gx,
      gy: gy,
      gz: gz,
      ax: ax,
      ay: ay,
      az: az,
      mx: mx,
      my: my,
      mz: mz
    ] =
      yell(IMU, {:get_IMU_data, self()})
      |> elem(0)
      |> Enum.map(fn {k, v} -> {k, Float.round(v, 6)} end)

    [
      Ahrs.update(gx, gy, gz, ax, ay, az, mx, my, mz, 0.01, quaternion)
      |> Quaternion.map(fn {k, v} -> {k, Float.round(v, 9)} end),
      gx,
      gy,
      gz,
      ax,
      ay,
      az,
      mx,
      my,
      mz
    ]
  end
end
