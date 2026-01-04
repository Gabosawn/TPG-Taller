defmodule TpgTest do
  use ExUnit.Case
  doctest Tpg

  test "greets the world" do
    assert Tpg.hello() == :world
  end
end
