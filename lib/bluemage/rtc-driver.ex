defmodule Bluemage.RTC do
	alias Circuits.I2C

	#Converts a byte of 2 adjacent 4-bit numbers into a single 2-digit decimal number
	def to_decimal(x), do: Integer.to_string(x, 16) |> String.to_integer

	#Converts a single 2-digit decimal number into a byte of 2 adjacent 4-bit numbers
	def to_rtc_byte(x), do: Integer.to_string(x) |> String.to_integer(16)
	
	#Converts RTC time values into UNIX epoch time stamp, accounting for leap years
	def to_epoch([seconds, minutes, hours, _weekday, days, months, years]) do
		seconds			+
		minutes * 60		+
		hours * 3600		+
		days * 86400		+
		to_days(months) * 86400	+
		div(years, 4) * 86400	+
		years * 31536000
	end

	#Converts month number into number of days passed by that month
	def to_days(months), do: to_days(months - 1, 0)
	def to_days(0, days), do: days
	def to_days(2, days), do: to_days(1, days + 28)
	def to_days(months, days) when months in [1, 3, 5, 7, 8, 10, 12], do: to_days(months - 1, days + 31)
	def to_days(months, days), do: to_days(months - 1, days + 30)

	#Gets the RTC's current time in UNIX epoch time stamp format
	def get_epoch(ref, dev) do
		to_epoch(Enum.map(:binary.bin_to_list(I2C.write_read!(ref, dev, <<0>>, 7)), &to_decimal/1))
	end

	#Sets the RTC's current time in UNIX epoch time stamp format
	def set_epoch(ref, dev, epoch) do
		#TODO
	end
end
