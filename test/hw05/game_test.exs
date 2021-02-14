defmodule Bulls.GameTest do
  use ExUnit.Case
  doctest Bulls.Game
  
  test "new generates a 4-digit secret" do
    new_game = Bulls.Game.new()
    {secret, _} = Integer.parse(new_game.secret)
    assert secret > 999
    assert secret < 10000
  end

  test "new generates a secret without repeat digits" do
    new_game = Bulls.Game.new()
    secret_digits = new_game.secret |> String.split("", trim: true)
    assert secret_digits == Enum.dedup(secret_digits)
  end

  test "guess adds to existing guess list" do
    result = Bulls.Game.new()
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.guess("4567")
    assert MapSet.size(result.guesses) == 2
    assert MapSet.to_list(result.guesses) == ["1234", "4567"]
  end

  test "guess does not add duplicate guess" do
    result = Bulls.Game.new()
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.guess("1234")
    assert MapSet.size(result.guesses) == 1
    assert MapSet.to_list(result.guesses) == ["1234"]
  end

  test "guess returns an error for word" do
    result = Bulls.Game.new()
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.guess("abc1234")
    assert MapSet.to_list(result.guesses) == ["1234"]
    assert result.error == "Invalid guess 'abc1234'"
  end

  test "guess returns an error if game already lost" do
    result = %{secret: "1111", guesses: MapSet.new}
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.guess("4321")
    |> Bulls.Game.guess("5678")
    |> Bulls.Game.guess("8765")
    |> Bulls.Game.guess("1235")
    |> Bulls.Game.guess("4325")
    |> Bulls.Game.guess("5674")
    |> Bulls.Game.guess("8764")
    |> Bulls.Game.guess("9876")
    assert MapSet.to_list(result.guesses) == [
      "1234",
      "1235",
      "4321",
      "4325",
      "5674",
      "5678",
      "8764",
      "8765"
    ]
    assert result.error == "Game lost. Please start a new game."
  end

  test "guess returns an error if game already won" do
    result = %{secret: "1234", guesses: MapSet.new}
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.guess("5678")
    assert MapSet.to_list(result.guesses) == ["1234"]
    assert result.error == "Game already won. Please start a new game."
  end

  test "view converts guess with no hits" do
    result = %{secret: "1234", guesses: MapSet.new}
    |> Bulls.Game.guess("5678")
    |> Bulls.Game.view()
    refute result.won
    refute result.lost

    [guess | _ ] = result.guesses
    assert guess == %{
      guess: "5678",
      a: 0,
      b: 0
    }
  end

  test "view converts guesses with hits" do
    result = %{secret: "1234", guesses: MapSet.new}
    |> Bulls.Game.guess("1432")
    |> Bulls.Game.guess("1256")
    |> Bulls.Game.guess("1235")
    |> Bulls.Game.guess("4321")
    |> Bulls.Game.view()
    refute result.won
    refute result.lost

    assert Enum.sort(result.guesses) == [
      %{a: 0, b: 4, guess: "4321"},
      %{a: 2, b: 0, guess: "1256"},
      %{a: 2, b: 2, guess: "1432"},
      %{a: 3, b: 0, guess: "1235"}
    ]
  end

  test "view notifies win" do
    result = %{secret: "1234", guesses: MapSet.new}
    |> Bulls.Game.guess("4321")
    |> Bulls.Game.guess("5678")
    |> Bulls.Game.guess("8765")
    |> Bulls.Game.guess("1235")
    |> Bulls.Game.guess("4325")
    |> Bulls.Game.guess("5674")
    |> Bulls.Game.guess("8764")
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.view()

    assert result.won
    refute result.lost
  end

  test "view notifies loss" do
    result = %{secret: "1111", guesses: MapSet.new}
    |> Bulls.Game.guess("4321")
    |> Bulls.Game.guess("5678")
    |> Bulls.Game.guess("8765")
    |> Bulls.Game.guess("1235")
    |> Bulls.Game.guess("4325")
    |> Bulls.Game.guess("5674")
    |> Bulls.Game.guess("8764")
    |> Bulls.Game.guess("9876")
    |> Bulls.Game.guess("1234")
    |> Bulls.Game.view()

    refute result.won
    assert result.lost
  end
end
