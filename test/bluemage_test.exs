defmodule BluemageTest do
  use ExUnit.Case
  doctest Bluemage

  test "greets the world" do
    assert Bluemage.hello() == :world
  end
end
