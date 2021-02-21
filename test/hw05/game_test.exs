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

  test "add_player adds player when game is in setup" do
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"foo", :player})
    assert result.participants == %{"foo" => :lobby_player}
  end

  test "add_player adds observer when game is in setup" do
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"foo", :observer})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds player when game is in guess" do
    result = Bulls.Game.new()
    result = %{result | phase: :guess}
    |> Bulls.Game.add_player({"foo", :player})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds observer when game is in guess" do
    result = Bulls.Game.new()
    result = %{result | phase: :guess}
    |> Bulls.Game.add_player({"foo", :observer})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds player when game is in result" do
    result = Bulls.Game.new()
    result = %{result | phase: :result}
    |> Bulls.Game.add_player({"foo", :player})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds observer when game is in result" do
    result = Bulls.Game.new()
    result = %{result | phase: :result}
    |> Bulls.Game.add_player({"foo", :observer})
    assert result.participants == %{"foo" => :observer}
  end

  test "guess adds to existing guess list" do
    result = Bulls.Game.new()
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "4567")
    |> Bulls.Game.guess("foo", "1234")
    assert Enum.count(result.guesses) == 1
    assert Map.get(result.guesses, "foo") == ["1234", "4567"]
  end

  test "guess does not add duplicate guess" do
    result = Bulls.Game.new()
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("foo", "1234")
    assert Enum.count(result.guesses) == 1
    assert Map.get(result.guesses, "foo") == ["1234"]
  end

  test "guess returns an error for word" do
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("foo", "abc1234")
    assert Map.get(result.guesses, "foo") == ["1234"]
    assert Map.get(result.errors, "foo") ==
      "Invalid guess 'abc1234'. Must be a four-digit number with unique digits"
  end

  test "guess returns an error if game is not started" do
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Game not yet started."
  end

  test "guess returns an error if game already concluded" do
    result = Bulls.Game.new()
    result = %{result | secret: "1234"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("foo", "5678")
    assert Map.get(result.guesses, "foo") == ["1234"]
    assert Map.get(result.errors, "foo") == "Game already concluded. Please start a new game."
  end

  test "guess returns an error if participant is an observer" do
    result = Bulls.Game.new()
    result = %{result | secret: "1234", phase: :guess}
    |> Bulls.Game.add_player({"foo", :observer})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Only ready players may place guesses."
  end

  test "guess returns an error if participant is an unready player" do
    result = Bulls.Game.new()
    result = %{result | secret: "1234", phase: :guess}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Only ready players may place guesses."
  end

  test "guess returns an error for unknown participant" do
    result = Bulls.Game.new()
    result = %{result | secret: "1234", phase: :guess}
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Only ready players may place guesses."
  end

  test "guess does not allow 1123" do
    result = Bulls.Game.new
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1123")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Guess may not contain duplicate digits."
  end

  #test "view converts guess with no hits" do
  #  result = %{secret: "1234", guesses: MapSet.new , error: ""}
  #  |> Bulls.Game.guess("5678")
  #  |> Bulls.Game.view()
  #  refute result.won
  #  refute result.lost

  #  [guess | _ ] = result.guesses
  #  assert guess == %{
  #    guess: "5678",
  #    a: 0,
  #    b: 0
  #  }
  #end

  #test "view converts guesses with hits" do
  #  result = %{secret: "1234", guesses: MapSet.new, error: ""}
  #   |> Bulls.Game.guess("1432")
  #   |> Bulls.Game.guess("1256")
  #   |> Bulls.Game.guess("1235")
  #   |> Bulls.Game.guess("4321")
  #   |> Bulls.Game.view()
  #   refute result.won
  #   refute result.lost

  #   assert Enum.sort(result.guesses) == [
  #     %{a: 0, b: 4, guess: "4321"},
  #     %{a: 2, b: 0, guess: "1256"},
  #     %{a: 2, b: 2, guess: "1432"},
  #     %{a: 3, b: 0, guess: "1235"}
  #   ]
  # end

  # test "view notifies win" do
  #   result = %{secret: "1234", guesses: MapSet.new, error: ""}
  #   |> Bulls.Game.guess("4321")
  #   |> Bulls.Game.guess("5678")
  #   |> Bulls.Game.guess("8765")
  #   |> Bulls.Game.guess("1235")
  #   |> Bulls.Game.guess("4325")
  #   |> Bulls.Game.guess("5674")
  #   |> Bulls.Game.guess("8764")
  #   |> Bulls.Game.guess("1234")
  #   |> Bulls.Game.view()

  #   assert result.won
  #   refute result.lost
  # end

  # test "view notifies loss" do
  #   result = %{secret: "1111", guesses: MapSet.new, error: ""}
  #   |> Bulls.Game.guess("4321")
  #   |> Bulls.Game.guess("5678")
  #   |> Bulls.Game.guess("8765")
  #   |> Bulls.Game.guess("1235")
  #   |> Bulls.Game.guess("4325")
  #   |> Bulls.Game.guess("5674")
  #   |> Bulls.Game.guess("8764")
  #   |> Bulls.Game.guess("9876")
  #   |> Bulls.Game.guess("1234")
  #   |> Bulls.Game.view()

  #   refute result.won
  #   assert result.lost
  # end
end
