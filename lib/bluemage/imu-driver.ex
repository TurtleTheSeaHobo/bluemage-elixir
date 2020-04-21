defmodule Bluemage.IMU do
	alias Circuits.I2C
	use Bitwise
	
	#Convert unsigned integer to bitwise-equivalent signed integer given the integer and word length
	def to_signed(x, w) when x >= (1 <<< (w - 1)), do: x - (1 <<< w)
	def to_signed(x, _w), do: x
	
	#Start the FXOS setup ritual with the given acceleration range (+/- G) and frequency (Hz)
	def start_FXOS(ref, dev, range, frequency) do
		#Set CTRL_REG1 to 0000 0000 to enter standby mode
		I2C.write(ref, dev, <<0x2A, 0x00>>)
		#Set XYZ_DATA_CFG to 0000 00xx select acceleration range
		case range do
			2 -> I2C.write(ref, dev, <<0x0E, 0x00>>)
			4 -> I2C.write(ref, dev, <<0x0E, 0x01>>)
			8 -> I2C.write(ref, dev, <<0x0E, 0x02>>)
		end
		#Set CTRL_REG2 to 0000 0010 to select high-resolution mode
		I2C.write(ref, dev, <<0x2B, 0x02>>)
		#Set CTRL_REG1 to 00xx x101 to select frequency and enter active, normal, low-noise, hybrid mode
		case frequency do
			0.78125	-> I2C.write(ref, dev, <<0x2A, 0x3D>>)
			3.125	-> I2C.write(ref, dev, <<0x2A, 0x35>>)
			6.25	-> I2C.write(ref, dev, <<0x2A, 0x2D>>)
			25.0	-> I2C.write(ref, dev, <<0x2A, 0x25>>)
			50.0	-> I2C.write(ref, dev, <<0x2A, 0x1D>>)
			100.0	-> I2C.write(ref, dev, <<0x2A, 0x15>>)
			200.0	-> I2C.write(ref, dev, <<0x2A, 0x0D>>)
			400.0	-> I2C.write(ref, dev, <<0x2A, 0x05>>)
		end
		#Set MCRTL_REG1 to 0001 1111 to select over-sampling rate 16 and enter hybrid mode
		I2C.write(ref, dev, <<0x5B, 0x1F>>)
		#Set MCRTL_REG2 to 0010 0000 to select jumping to register 0x33 after reading 0x06
		I2C.write(ref, dev, <<0x5C, 0x20>>)
		:ok
	end

	#Get the current FXOS acceloremeter/magnetometer data
	def get_FXOS_data(ref, dev, range) do
		#Set STATUS to 1000 0000 for... some reason (idk, Adafruit does it)
		I2C.write(ref, dev, <<0x00, 0x80>>)
		#Read 13 bytes from starting register 0x00
		<<_status, axhi, axlo, ayhi, aylo, azhi, azlo, mxhi, mxlo, myhi, mylo, mzhi, mzlo>> = I2C.write_read!(ref, dev, <<0x00>>, 13)
		#Recombobulate, convert, and return those numbers (G and microtesla units)
		[
		ax: to_signed(((axhi <<< 8) ||| axlo) >>> 2, 14) * div(range, 2) * 0.000244,
		ay: to_signed(((ayhi <<< 8) ||| aylo) >>> 2, 14) * div(range, 2) * 0.000244,
		az: to_signed(((azhi <<< 8) ||| azlo) >>> 2, 14) * div(range, 2) * 0.000244,
		mx: to_signed((mxhi <<< 8) ||| mxlo, 16) * 0.1,
		my: to_signed((myhi <<< 8) ||| mylo, 16) * 0.1,
		mz: to_signed((mzhi <<< 8) ||| mzlo, 16) * 0.1
		]
	end

	#Start the FXAS setup ritual with the given angular velocity range (+/- DPS) and frequency (Hz)
	def start_FXAS(ref, dev, range, frequency) do
		#Set CTRL_REG1 to 0000 0000 to enter standby mode
		I2C.write(ref, dev, <<0x13, 0x00>>)
		#Set CTRL_REG1 to 0100 0000 to perform full reset
		I2C.write(ref, dev, <<0x13, 0x40>>)
		#Set CTRL_REG0 to 0000 00xx to select angular velocity range
		case range do
			250	-> I2C.write(ref, dev, <<0x0D, 0x03>>)
			500	-> I2C.write(ref, dev, <<0x0D, 0x02>>)
			1000	-> I2C.write(ref, dev, <<0x0D, 0x01>>)
			2000	-> I2C.write(ref, dev, <<0x0D, 0x00>>)
		end
		#Set CTRL_REG1 to 000x xx10 to select frequency and enter active mode
		case frequency do
			12.5	-> I2C.write(ref, dev, <<0x13, 0x1A>>)
			25.0	-> I2C.write(ref, dev, <<0x13, 0x16>>)
			50.0	-> I2C.write(ref, dev, <<0x13, 0x12>>)
			100.0	-> I2C.write(ref, dev, <<0x13, 0x0E>>)
			200.0	-> I2C.write(ref, dev, <<0x13, 0x0A>>)
			400.0	-> I2C.write(ref, dev, <<0x13, 0x06>>)
			800.0	-> I2C.write(ref, dev, <<0x13, 0x02>>)
		end
		:ok
	end

	#Get the current FXAS gyroscope data
	def get_FXAS_data(ref, dev, range) do
		#Set STATUS to 1000 0000 for... some reason (idk, Adafruit does it)
		I2C.write(ref, dev, <<0x00, 0x80>>)
		#Read 7 bytes from starting register 0x00
		<<_status, xhi, xlo, yhi, ylo, zhi, zlo>> = I2C.write_read!(ref, dev, <<0x00>>, 7)
		#Recombobulate, convert, and return those numbers (rad/s units)
		[
		gx: to_signed((xhi <<< 8) ||| xlo, 16) * div(range, 250) * 0.0001363538515625,
		gy: to_signed((yhi <<< 8) ||| ylo, 16) * div(range, 250) * 0.0001363538515625,
		gz: to_signed((zhi <<< 8) ||| zlo, 16) * div(range, 250) * 0.0001363538515625
		]
	end

	#Start both sensor setup rituals with given ranges on a single frequency
	def start_IMU(ref, g_dev, a_dev, g_range, a_range, frequency) do
		start_FXAS(ref, g_dev, g_range, frequency)
		start_FXOS(ref, a_dev, a_range, frequency)
		:ok
	end

	#Get the current IMU data in a quick-succession read
	def get_IMU_data(ref, g_dev, a_dev, g_range, a_range) do
		get_FXAS_data(ref, g_dev, g_range) ++ get_FXOS_data(ref, a_dev, a_range)
	end
end
