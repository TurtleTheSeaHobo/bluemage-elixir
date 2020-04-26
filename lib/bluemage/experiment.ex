defmodule Bluemage.Experiment do
	alias Bluemage.IMU
	alias Bluemage.RTC
	alias Bluemage.Ahrs
	require Logger

	#Reverses lists
	defp reverse(list), do: reverse(list, [])
	defp reverse([head | []], list), do: [head] ++ list
	defp reverse([head | tail], list), do: reverse(tail, [head] ++ list)

	#Sends message to named process, then awaits and returns reply
	defp yell(target, body, timeout \\ 1_000) do
		pid = Process.whereis(target)
		send(pid, body)
		receive do
			{reply, pid}	-> {reply, pid}
		after
			timeout			-> {:err, :timed_out}
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
		packet = %{
			"info" => %{
				"name" => "Bluemage",
				"team" => "LSN-SEDS"
			},
			"data" => [[%Bluemage.Quaternion{}]]
		}
	
		Logger.info("Checking for IMU and RTC driver readiness...")

		case yell(IMU, {:ready?, self()}, 10_000) do
			{true, _pid}	 	-> Logger.info("Got ready signal from IMU driver.")
			{:err, :timed_out}	-> Logger.info("Timed out waiting for ready signal from IMU driver.")
		end

		case yell(RTC, {:ready?, self()}, 10_000) do
			{true, _pid}		-> Logger.info("Got ready signal from RTC driver." )
			{:err, :timed_out}	-> Logger.info("Timed out waiting for ready signal from RTC driver.")
		end
		
		loop(packet)	
	end

	def loop(packet) do
		receive do
			:push	-> push(packet)
		after
			0_020	-> update(packet)
		end |> loop()
	end
	
	def push(packet) do
		{:ok, file} = File.open("/tmp/experiment/" <> Integer.to_string(yell(RTC, {:get_epoch, self()}) |> elem(0)) <> ".json", [:write])

		IO.binwrite(file, Jason.encode!(%{packet | "data" => reverse(tl(packet["data"]))}))
		File.close(file)

		%{packet | "data" => [hd(packet["data"])]}
	end

	def update(packet) do
		[
			gx: gx, gy: gy, gz: gz,
			ax: ax, ay: ay, az: az,
			mx: mx, my: my, mz: mz
		] = yell(IMU, {:get_IMU_data, self()}) |> elem(0) |> Enum.map(fn {k, v} -> {k, Float.round(v, 9)} end)

		%{packet | "data" => 
			[[
				Ahrs.update(gx, gy, gz, ax, ay, az, mx, my, mz, 0.02, hd(hd(packet["data"]))),
				gx, gy, gz, ax, ay, az, mx, my, mz
			]] ++ packet["data"]
		}
	end
end
