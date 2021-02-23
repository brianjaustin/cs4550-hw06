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
    assert result.participants == %{"foo" => :pending_player}
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
    |> Bulls.Game.finish_round()
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
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1123")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Guess may not contain duplicate digits."
  end

  test "view sets lobby and winners for setup phase" do
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"bar", :observer})
    |> Bulls.Game.view()

    assert result.lobby
    assert result.winners == []
  end

  test "view sets lobby and winners for play phase" do
    result = Bulls.Game.new()
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.view()

    refute result.lobby
    assert result.winners == []
  end

  test "view sets lobby and winners for result phase" do
    result = Bulls.Game.new()
    result = %{result | secret: "1234"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("bar", "1234")
    |> Bulls.Game.view()

    refute result.lobby
    assert result.winners == ["foo", "bar"]
  end

  test "view sets bulls and cows" do
    result = Bulls.Game.new()
    result = %{result | secret: "1245"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("bar", "5432")
    |> Bulls.Game.view()

    assert result.guesses == %{
      "bar" => [%{guess: "5432", a: 0, b: 3}],
      "foo" => [%{guess: "1234", a: 2, b: 1}]
    }
  end
end
