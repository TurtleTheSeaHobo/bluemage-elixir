defmodule Bluemage.Quaternion do
  @derive Jason.Encoder
  defstruct q1: 1.0, q2: 0.0, q3: 0.0, q4: 0.0

  def map(quat, fun) do
    [
      q1: q1,
      q2: q2,
      q3: q3,
      q4: q4
    ] = Map.from_struct(quat) |> Enum.map(fun)

    %Bluemage.Quaternion{
      q1: q1,
      q2: q2,
      q3: q3,
      q4: q4
    }
  end
end
