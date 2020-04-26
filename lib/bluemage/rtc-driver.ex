defmodule Bluemage.RTC do
	alias Circuits.I2C
	require Logger

	#Converts a byte of 2 adjacent 4-bit numbers into a single 2-digit decimal number
	defp to_decimal(x), do: Integer.to_string(x, 16) |> String.to_integer

	#Converts a single 2-digit decimal number into a byte of 2 adjacent 4-bit numbers
	defp to_rtc_byte(x), do: Integer.to_string(x) |> String.to_integer(16)
	
	#Converts RTC time values into UNIX epoch time stamp, accounting for leap years
	defp to_epoch([second, minute, hour, _weekday, day, month, year]) do
		DateTime.to_unix(%DateTime{
			year: year + 1970, month: month, day: day, zone_abbr: "UTC",
			hour: hour, minute: minute, second: second, microsecond: {0, 0},
			utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"
			})
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
		Process.register(pid, Bluemage.RTC)
		{:ok, pid}
	end

	def init(_opts) do
		{:ok, ref} = I2C.open("i2c-1")

		config = %{
			ref: ref,	#I2C bus reference
			dev: 0x68	#RTC device address
			}

		#Check if RTC was reset and use system time if so.
		if DateTime.from_unix!(get_epoch(config)).year == 1970 do
			Logger.info("RTC thinks it\'s 1970. Syncing to system time.")
			set_epoch(config, System.cmd("date", ["+%s"])
				|> elem(0)
				|> String.trim
				|> String.to_integer
				)
		end

		loop(config)
	end

	def loop(config) do
		receive do
			{:ready?, pid}				-> send(pid, {true, self()})
			{:get_epoch, pid}			-> send(pid, {get_epoch(config), self()})
			{:set_epoch, pid, epoch}	-> send(pid, {set_epoch(config, epoch), self()})
		end
		loop(config)
	end

	#Gets the RTC's current time in UNIX epoch time stamp format
	def get_epoch(%{ref: ref, dev: dev}) do
		to_epoch(Enum.map(:binary.bin_to_list(I2C.write_read!(ref, dev, <<0>>, 7)), &to_decimal/1))
	end

	#Sets the RTC's current time in UNIX epoch time stamp format
	def set_epoch(config, epoch) when is_integer(epoch) do
		set_epoch(config, DateTime.from_unix!(epoch))
	end
	def set_epoch(%{ref: ref, dev: dev}, datetime) do
		I2C.write(ref, dev, <<0x00, to_rtc_byte(datetime.second)>>)
		I2C.write(ref, dev, <<0x01, to_rtc_byte(datetime.minute)>>)
		I2C.write(ref, dev, <<0x02, to_rtc_byte(datetime.hour)>>)
		#Skip weekday because its unimportant (it's at address 0x03)
		I2C.write(ref, dev, <<0x04, to_rtc_byte(datetime.day)>>)
		I2C.write(ref, dev, <<0x05, to_rtc_byte(datetime.month)>>)
		I2C.write(ref, dev, <<0x06, to_rtc_byte(datetime.year - 1970)>>)
		:ok
	end
end