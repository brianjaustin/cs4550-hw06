defmodule Bulls.GameTest do
  use ExUnit.Case
  doctest Bulls.Game
  
  test "new generates a 4-digit secret" do
    new_game = Bulls.Game.new(&Function.identity/1)
    {secret, _} = Integer.parse(new_game.secret)
    assert secret > 999
    assert secret < 10000
  end

  test "new generates a secret without repeat digits" do
    new_game = Bulls.Game.new(&Function.identity/1)
    secret_digits = new_game.secret |> String.split("", trim: true)
    assert secret_digits == Enum.dedup(secret_digits)
  end

  test "add_player adds player when game is in setup" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"foo", :player})
    assert result.participants == %{"foo" => {:lobby_player, 0, 0}}
  end

  test "add_player adds observer when game is in setup" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"foo", :observer})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds player when game is in guess" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | round: 1}
    |> Bulls.Game.add_player({"foo", :player})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds observer when game is in guess" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | round: 1}
    |> Bulls.Game.add_player({"foo", :observer})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds player when game is in result" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | round: :result}
    |> Bulls.Game.add_player({"foo", :player})
    assert result.participants == %{"foo" => :observer}
  end

  test "add_player adds observer when game is in result" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | round: :result}
    |> Bulls.Game.add_player({"foo", :observer})
    assert result.participants == %{"foo" => :observer}
  end

  test "guess adds to existing guess list" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "4567")
    |> Bulls.Game.finish_round(1)
    |> Bulls.Game.guess("foo", "1234")
    assert Enum.count(result.guesses) == 1
    assert Map.get(result.guesses, "foo") == [{"1234", 2}, {"4567", 1}]
  end

  test "guess can pass with sentinel value" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "----")
    assert Enum.count(result.guesses) == 1
    assert Map.get(result.guesses, "foo") == [{"----", 1}]
  end

  test "guess does not overwrite if guessed in round" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.guess("foo", "4567")
    |> Bulls.Game.guess("foo", "1234")
    assert Enum.count(result.guesses) == 2
    assert Map.get(result.guesses, "foo") == [{"4567", 1}]
  end

  test "guess does not add duplicate guess" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.finish_round(1)
    |> Bulls.Game.guess("foo", "1234")
    assert Enum.count(result.guesses) == 1
    assert Map.get(result.guesses, "foo") == [{"1234", 1}]
  end

  test "guess returns an error for word" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("foo", "abc1234")
    assert Map.get(result.guesses, "foo") == [{"1234", 1}]
    assert Map.get(result.errors, "foo") ==
      "Invalid guess 'abc1234'. Must be a four-digit number with unique digits"
  end

  test "guess returns an error if game is not started" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Game not yet started."
  end

  test "guess returns an error if participant is an observer" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1234", round: 1}
    |> Bulls.Game.add_player({"foo", :observer})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Only ready players may place guesses."
  end

  test "guess returns an error if participant is an unready player" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1234", round: 1}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Only ready players may place guesses."
  end

  test "guess returns an error for unknown participant" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1234", round: 1}
    |> Bulls.Game.guess("foo", "1234")
    assert Map.get(result.guesses, "foo") == nil
    assert Map.get(result.errors, "foo") == "Only ready players may place guesses."
  end

  test "guess does not allow 1123" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1123")
    assert Map.get(result.guesses, "foo") == []
    assert Map.get(result.errors, "foo") == "Guess may not contain duplicate digits."
  end

  test "finish_round passes for current round" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.finish_round(1)
    assert result.round == 2
    assert Map.get(result.guesses, "foo") == [{"----", 1}]
  end

  test "finish_round does not pass for current round if guessed" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.finish_round(1)
    assert result.round == 2
    assert Map.get(result.guesses, "foo") == [{"1234", 1}]
  end

  test "finish_round does not pass for old round" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111", round: 2}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.finish_round(1)
    assert result.round == 2
    assert Map.get(result.guesses, "foo") == nil
  end

  test "finish_round concludes if someone won" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1234"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.finish_round(1)

    assert result.round == 0
    assert result.participants == %{
      "foo" => {:lobby_player, 1, 0},
      "bar" => {:lobby_player, 0, 1}
    }
  end

  test "conclude reset round, errors, and guesses" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1111", round: 2}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.finish_round(1)
    |> Bulls.Game.conclude()
    assert result.round == 0
    assert result.errors == %{}
    assert result.guesses == %{"foo" => []}
  end

  test "view sets lobby for setup phase" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"bar", :observer})
    |> Bulls.Game.view()

    assert result.lobby
    assert result.participants == %{
      "bar" => [:observer, 0, 0]
    }
  end

  test "view sets lobby and winners for play phase" do
    result = Bulls.Game.new(&Function.identity/1)
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.view()

    refute result.lobby
    assert result.participants == %{
      "bar" => [:player, 0, 0]
    }
  end

  test "view sets lobby and winners for result phase" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1234"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("bar", "1234")
    |> Bulls.Game.view()

    assert result.lobby
    assert result.participants == %{
      "foo" => [:lobby_player, 1, 0],
      "bar" => [:lobby_player, 1, 0],
    }
    assert result.previous_winners == ["foo", "bar"]
  end

  test "view sets bulls and cows" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1245"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.guess("bar", "5432")
    |> Bulls.Game.finish_round(1)
    |> Bulls.Game.view()

    assert result.guesses == %{
      "bar" => [%{guess: "5432", a: 0, b: 3}],
      "foo" => [%{guess: "1234", a: 2, b: 1}]
    }
  end

  test "view suppresses current round results" do
    result = Bulls.Game.new(&Function.identity/1)
    result = %{result | secret: "1245"}
    |> Bulls.Game.add_player({"foo", :player})
    |> Bulls.Game.add_player({"bar", :player})
    |> Bulls.Game.ready_player("bar")
    |> Bulls.Game.ready_player("foo")
    |> Bulls.Game.guess("foo", "1234")
    |> Bulls.Game.view()

    assert result.guesses == %{
      "bar" => [],
      "foo" => []
    }
  end
end
