defmodule Bluemage.RTC do
	alias Circuits.I2C

	#Converts a byte of 2 adjacent 4-bit numbers into a single 2-digit decimal number
	def to_decimal(x), do: Integer.to_string(x, 16) |> String.to_integer

	#Converts a single 2-digit decimal number into a byte of 2 adjacent 4-bit numbers
	def to_rtc_byte(x), do: Integer.to_string(x) |> String.to_integer(16)
	
	#Converts RTC time values into UNIX epoch time stamp, accounting for leap years
	def to_epoch([second, minute, hour, _weekday, day, month, year]) do
		DateTime.to_unix(%DateTime{
			year: year + 1970, month: month, day: day, zone_abbr: "UTC",
			hour: hour, minute: minute, second: second, microsecond: {0, 0},
			utc_offset: 0, std_offset: 0, time_zone: "Etc/UTC"
			})
	end

	#Gets the RTC's current time in UNIX epoch time stamp format
	def get_epoch(ref, dev) do
		to_epoch(Enum.map(:binary.bin_to_list(I2C.write_read!(ref, dev, <<0>>, 7)), &to_decimal/1))
	end

	#Sets the RTC's current time in UNIX epoch time stamp format
	def set_epoch(ref, dev, epoch) when is_integer(epoch) do
		set_epoch(ref, dev, DateTime.from_unix!(epoch))
	end
	def set_epoch(ref, dev, datetime) do
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
