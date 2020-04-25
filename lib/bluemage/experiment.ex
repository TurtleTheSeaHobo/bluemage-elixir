defmodule Bluemage.Experiment do
	alias Circuits.I2C
	alias Bluemage.IMU
	alias Bluemage.RTC
	alias Bluemage.Ahrs

	defp reverse(list), do: reverse(list, [])
	defp reverse([head | []], list), do: [head] ++ list
	defp reverse([head | tail], list), do: reverse(tail, [head] ++ list)

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
		{:ok, ref} = I2C.open("i2c-1")

		config = %{
		:ref	 => ref,		#I2C bus reference
		:c_dev	 => 0x68,		#RTC device address
		:g_dev	 => 0x21,		#IMU gyro device address
		:a_dev	 => 0x1F,		#IMU acc/mag device address 
		:g_range => 250,		#IMU gyro sensor range (DPS)
		:a_range => 2			#IMU acc/mag sensor range (+/-G)
		}

		packet = %{
		"info" => %{
			"name" => "Bluemage",
			"team" => "LSN-SEDS"
		},
		"data" => [[%Bluemage.Quaternion{}]]
		}

		IMU.start_IMU(config.ref, config.g_dev, config.a_dev, config.g_range, config.a_range, 100.0)
		loop(packet, config)	
	end

	def trigger_push(), do: send(self(), :push)

	def loop(packet, config) do
		receive do
			:push	-> push(packet, RTC.get_epoch(config.ref, config.c_dev))
		after
			0_020	-> update(packet, config)
		end |> loop(config)
	end
	
	def push(packet, time) do
		{:ok, file} = File.open("/tmp/experiment/" <> Integer.to_string(time) <> ".json", [:write])
		IO.binwrite(file, Jason.encode!(%{packet | "data" => reverse(tl(packet["data"]))}))
		File.close(file)
		%{packet | "data" => [hd(packet["data"])]}
	end

	def update(packet, config) do
		[
		gx: gx, gy: gy, gz: gz,
		ax: ax, ay: ay, az: az,
		mx: mx, my: my, mz: mz
		] = IMU.get_IMU_data(config.ref, config.g_dev, config.a_dev, config.g_range, config.a_range)
		%{packet | "data" => 
			[[
			Ahrs.update(gx, gy, gz, ax, ay, az, mx, my, mz, 0.02, hd(hd(packet["data"]))),
			gx, gy, gz, ax, ay, az, mx, my, mz
			]] ++ packet["data"]
		}
	end
end
