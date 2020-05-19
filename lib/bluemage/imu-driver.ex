defmodule Bluemage.IMU do
  alias Circuits.I2C
  use Bitwise

  # Convert unsigned integer to bitwise-equivalent signed integer given the integer and word length
  defp to_signed(x, w) when x >= 1 <<< (w - 1), do: x - (1 <<< w)
  defp to_signed(x, _w), do: x

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
    Process.register(pid, Bluemage.IMU)
    {:ok, pid}
  end

  def init(_opts) do
    {:ok, ref} = I2C.open("i2c-1")

    config = %{
      # I2C bus reference
      :ref => ref,
      # IMU gyro device address
      :g_dev => 0x21,
      # IMU acc/mag device address
      :a_dev => 0x1F,
      # IMU gyro sensor range (DPS)
      :g_range => 250,
      # IMU acc/mag sensor range (+/-G)
      :a_range => 2,
      # Sensor frequncy/data rate (Hz)
      :frequency => 100.0
    }

    start_IMU(config)
    loop(config)
  end

  def loop(config) do
    receive do
      {:ready?, pid} -> send(pid, {true, self()})
      {:get_IMU_data, pid} -> send(pid, {get_IMU_data(config), self()})
      {:get_IMU_test, pid} -> send(pid, {get_IMU_test(config), self()})
    end

    loop(config)
  end

  # Start the FXOS setup ritual with the given acceleration range (+/- G) and frequency (Hz)
  def start_FXOS(%{ref: ref, a_dev: dev, a_range: range, frequency: frequency}) do
    # Set CTRL_REG1 to 0000 0000 to enter standby mode
    I2C.write(ref, dev, <<0x2A, 0x00>>)
    # Set XYZ_DATA_CFG to 0000 00xx select acceleration range
    case range do
      2 -> I2C.write(ref, dev, <<0x0E, 0x00>>)
      4 -> I2C.write(ref, dev, <<0x0E, 0x01>>)
      8 -> I2C.write(ref, dev, <<0x0E, 0x02>>)
    end

    # Set CTRL_REG2 to 0000 0010 to select high-resolution mode
    I2C.write(ref, dev, <<0x2B, 0x02>>)

    # Set CTRL_REG1 to 00xx x101 to select frequency and enter active, normal, low-noise, hybrid mode
    case frequency do
      0.78125 -> I2C.write(ref, dev, <<0x2A, 0x3D>>)
      3.125 -> I2C.write(ref, dev, <<0x2A, 0x35>>)
      6.25 -> I2C.write(ref, dev, <<0x2A, 0x2D>>)
      25.0 -> I2C.write(ref, dev, <<0x2A, 0x25>>)
      50.0 -> I2C.write(ref, dev, <<0x2A, 0x1D>>)
      100.0 -> I2C.write(ref, dev, <<0x2A, 0x15>>)
      200.0 -> I2C.write(ref, dev, <<0x2A, 0x0D>>)
      400.0 -> I2C.write(ref, dev, <<0x2A, 0x05>>)
    end

    # Set MCRTL_REG1 to 0001 1111 to select over-sampling rate 16 and enter hybrid mode
    I2C.write(ref, dev, <<0x5B, 0x1F>>)
    # Set MCRTL_REG2 to 0010 0000 to select jumping to register 0x33 after reading 0x06
    I2C.write(ref, dev, <<0x5C, 0x20>>)
    :ok
  end

  # Get the results of the FXOS self test function for error correction
  def get_FXOS_test(%{ref: ref, a_dev: dev, a_range: range}, tests \\ 16) do
    # Read CTRL_REG2 and rewrite it with ST bit high (1xxx xxxx)
    <<reg>> = I2C.write_read!(ref, dev, <<0x2B>>, 1)
    I2C.write(ref, dev, <<0x2B, reg ||| 0x80>>)
    # Recurse and get the post-test FXOS datapoints
    get_FXOS_test(
      %{ref: ref, a_dev: dev, a_range: range},
      tests - 1,
      [get_FXOS_data(%{ref: ref, a_dev: dev, a_range: range})]
    )
  end

  def get_FXOS_test(%{ref: ref, a_dev: dev, a_range: _range}, 0, data) do
    # Read CTRL_REG2 and rewrite it with ST bit low (0xxx xxxx)
    <<reg>> = I2C.write_read!(ref, dev, <<0x2B>>, 1)
    I2C.write(ref, dev, <<0x2B, reg ^^^ 0x80>>)
    # Reverse and return final self-test data list
    Enum.reverse(data)
  end

  def get_FXOS_test(%{ref: ref, a_dev: dev, a_range: range}, tests, data) do
    get_FXOS_test(
      %{ref: ref, a_dev: dev, a_range: range},
      tests - 1,
      [get_FXOS_data(%{ref: ref, a_dev: dev, a_range: range})] ++ data
    )
  end

  # Get the current FXOS acceloremeter/magnetometer data
  def get_FXOS_data(%{ref: ref, a_dev: dev, a_range: range}) do
    # Set STATUS to 1000 0000 for... some reason (idk, Adafruit does it)
    I2C.write(ref, dev, <<0x00, 0x80>>)
    # Read 13 bytes from starting register 0x00
    <<_status, axhi, axlo, ayhi, aylo, azhi, azlo, mxhi, mxlo, myhi, mylo, mzhi, mzlo>> =
      I2C.write_read!(ref, dev, <<0x00>>, 13)

    # Recombobulate, convert, and return those numbers (G and microtesla units)
    [
      ax: to_signed((axhi <<< 8 ||| axlo) >>> 2, 14) * div(range, 2) * 0.000244,
      ay: to_signed((ayhi <<< 8 ||| aylo) >>> 2, 14) * div(range, 2) * 0.000244,
      az: to_signed((azhi <<< 8 ||| azlo) >>> 2, 14) * div(range, 2) * 0.000244,
      mx: to_signed(mxhi <<< 8 ||| mxlo, 16) * 0.1,
      my: to_signed(myhi <<< 8 ||| mylo, 16) * 0.1,
      mz: to_signed(mzhi <<< 8 ||| mzlo, 16) * 0.1
    ]
  end

  # Start the FXAS setup ritual with the given angular velocity range (+/- DPS) and frequency (Hz)
  def start_FXAS(%{ref: ref, g_dev: dev, g_range: range, frequency: frequency}) do
    # Set CTRL_REG1 to 0000 0000 to enter standby mode
    I2C.write(ref, dev, <<0x13, 0x00>>)
    # Set CTRL_REG1 to 0100 0000 to perform full reset
    I2C.write(ref, dev, <<0x13, 0x40>>)
    # Set CTRL_REG0 to 0000 00xx to select angular velocity range
    case range do
      250 -> I2C.write(ref, dev, <<0x0D, 0x03>>)
      500 -> I2C.write(ref, dev, <<0x0D, 0x02>>)
      1000 -> I2C.write(ref, dev, <<0x0D, 0x01>>)
      2000 -> I2C.write(ref, dev, <<0x0D, 0x00>>)
    end

    # Set CTRL_REG1 to 000x xx10 to select frequency and enter active mode
    case frequency do
      12.5 -> I2C.write(ref, dev, <<0x13, 0x1A>>)
      25.0 -> I2C.write(ref, dev, <<0x13, 0x16>>)
      50.0 -> I2C.write(ref, dev, <<0x13, 0x12>>)
      100.0 -> I2C.write(ref, dev, <<0x13, 0x0E>>)
      200.0 -> I2C.write(ref, dev, <<0x13, 0x0A>>)
      400.0 -> I2C.write(ref, dev, <<0x13, 0x06>>)
      800.0 -> I2C.write(ref, dev, <<0x13, 0x02>>)
    end

    :ok
  end

  # Get the results of the FXAS self test function for error correction
  def get_FXAS_test(%{ref: ref, g_dev: dev, g_range: range}, tests \\ 16) do
    # Read CTRL_REG1 and rewrite it with ST bit high (xx1x xxxx)
    <<reg>> = I2C.write_read!(ref, dev, <<0x13>>, 1)
    I2C.write(ref, dev, <<0x13, reg ||| 0x20>>)
    # Recurse and get the post-test FXAS datapoints
    get_FXAS_test(
      %{ref: ref, g_dev: dev, g_range: range},
      tests - 1,
      [get_FXAS_data(%{ref: ref, g_dev: dev, g_range: range})]
    )
  end

  def get_FXAS_test(%{ref: ref, g_dev: dev, g_range: _range}, 0, data) do
    # Read CTRL_REG1 and rewrite it with ST bit low (xx0x xxxx)
    <<reg>> = I2C.write_read!(ref, dev, <<0x13>>, 1)
    I2C.write(ref, dev, <<0x13, reg ^^^ 0x20>>)
    # Reverse and return final mean self-test data
    Enum.reverse(data)
  end

  def get_FXAS_test(%{ref: ref, g_dev: dev, g_range: range}, tests, data) do
    get_FXAS_test(
      %{ref: ref, g_dev: dev, g_range: range},
      tests - 1,
      [get_FXAS_data(%{ref: ref, g_dev: dev, g_range: range})] ++ data
    )
  end

  # Get the current FXAS gyroscope data
  def get_FXAS_data(%{ref: ref, g_dev: dev, g_range: range}) do
    # Set STATUS to 1000 0000 for... some reason (idk, Adafruit does it)
    I2C.write(ref, dev, <<0x00, 0x80>>)
    # Read 7 bytes from starting register 0x00
    <<_status, xhi, xlo, yhi, ylo, zhi, zlo>> = I2C.write_read!(ref, dev, <<0x00>>, 7)
    # Recombobulate, convert, and return those numbers (rad/s units)
    [
      gx: to_signed(xhi <<< 8 ||| xlo, 16) * div(range, 250) * 0.0001363538515625,
      gy: to_signed(yhi <<< 8 ||| ylo, 16) * div(range, 250) * 0.0001363538515625,
      gz: to_signed(zhi <<< 8 ||| zlo, 16) * div(range, 250) * 0.0001363538515625
    ]
  end

  # Start both sensor setup rituals with given ranges on a single frequency
  def start_IMU(config) do
    start_FXAS(config)
    start_FXOS(config)
    :ok
  end

  # Get the current IMU data in a quick-succession read
  def get_IMU_data(config) do
    get_FXAS_data(config) ++ get_FXOS_data(config)
  end

  def get_IMU_test(config, tests \\ 16) do
    [get_FXOS_test(config, tests), get_FXAS_test(config, tests)]
    |> Enum.zip()
    |> Enum.map(fn {x, y} -> x ++ y end)
  end
end
