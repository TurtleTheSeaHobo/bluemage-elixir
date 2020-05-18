defmodule Bluemage.Diagnostic do
  def make_packet() do
    make_packet(
      [
        "top -b | head -n 5",
        "cat /sys/class/thermal/thermal_zone*/temp",
        "memtester 32M 4 | col -bp | less -R"
      ],
      %{
        "info" => %{
          "name" => "Bluemage",
          "team" => "LSN-SEDS"
        },
        "diag" => %{}
      }
    )
  end

  def make_packet([], packet) do
    packet
  end

  def make_packet([head | tail], packet) do
    make_packet(
      tail,
      %{
        packet
        | "diag" =>
            packet["diag"]
            |> Map.put(
              head,
              to_charlist(head)
              |> :os.cmd()
              |> to_string
            )
      }
    )
  end
end
