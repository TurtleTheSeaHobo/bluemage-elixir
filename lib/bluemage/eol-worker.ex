defmodule Bluemage.EoL do
  alias Bluemage.Packetizer
  #EoL counter activity. Set to false to enable safety for ground testing.
  @eol_ctactive false
  #Seconds from first boot until EoL operations (cur. 30 days)
  @eol_lifetime 2592000
  #EoL lifetime persistance file name (charlist for :os.cmd)
  @eol_filename 'eol'

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
    Process.register(pid, Bluemage.EoL)
    {:ok, pid}
  end

  def init(_opts) do
    loop(
      :os.cmd('cat ' ++ @eol_filename)
      |> to_string()
      |> String.to_integer()
    )
  end

  def loop(lifetime) when lifetime == @eol_lifetime - 300 do
    send(Packetizer, {:push_packet,
      %{
        "info" => %{
          "name" => "Bluemage",
          "team" => "LSN-SEDS"
        },
        "warn" => "This system is approaching its EoL lifetime.
                  In 5 minutes, this system will permanently shut down.
                  In the event that power is disturbed and the system
                  reboots, it will immediately shut down again upon
                  execution of the Bluemage application. This process
                  is irreversible and cannot be stopped."
      }
    })
    receive do
      {:tick, _pid} -> tick(lifetime)
    end
    |> loop()
  end

  def loop(lifetime) when lifetime >= @eol_lifetime do
    #IO.puts("fake shutting down")
    receive do
      {:tick, _pid} -> tick(lifetime)
    end
    |> loop()
    #DEFINITELY COMMENT THIS OUT FOR TESTING!!!
    :os.cmd('shutdown now')
  end

  def loop(lifetime) do
    receive do
      {:tick, _pid} -> tick(lifetime)
    end
    |> loop()
  end

  def tick(lifetime) when @eol_ctactive == true do
    :os.cmd(
      Integer.to_charlist(lifetime + 1) ++ ' > ' ++ @eol_filename
    )
    lifetime + 1
  end

  def tick(lifetime) do
    lifetime
  end
end
