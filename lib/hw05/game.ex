defmodule Bulls.Game do
  @moduledoc """
  Provides functionality for running a game of Bulls and Cows.

  ## Game Play

    First, a random 4-digit number is generated. This random secret
    must be between 1000 and 9999, and there may be no repeating digits
    (so 1233 and 0123 are invalid secrets). Next, a single player inputs
    _valid_ attempts to guess the secret number. If the player guesses
    correctly in fewer than 8 attempts, the game is won; otherwise, they lose.

  ## Attribution

    This module is based on the example shown in lecture.
    [Notes are here](https://github.com/NatTuck/scratch-2021-01/blob/master/notes-4550/07-phoenix/notes.md).
  """

  @typedoc "Participant in a game, either active (player) or passive (observer)"
  @type game_participant :: {String.t(), :player} | {String.t(), :observer}

  @typedoc "Represents a guess with number of bulls and cows"
  @type game_guess :: {String.t(), String.t(), non_neg_integer, non_neg_integer}

  @typedoc "Represents internal game state"
  @type game_state :: %{
    phase: :setup | :guess | :result,
    participants: %{String.t() => :lobby_player | :player | :observer},
    secret: String.t(),
    guesses: %{String.t() => [game_guess]},
    errors: %{String.t() => String.t()}
  }

  @typedoc "Represents a user visible guess result"
  @type guess_view :: %{
    guess: String.t(),
    a: non_neg_integer,
    b: non_neg_integer
  }

  @doc """
  Produces a blank game state, with empty guesses and a randomly
  generated secret.
  """
  @spec new() :: game_state
  def new() do
    %{
      phase: :setup,
      participants: %{},
      secret: gen_secret(),
      guesses: %{},
      errors: %{}
    }
  end

  defp gen_secret do
    secret = Enum.take_random(0..9, 4) |> Enum.join
    {num, _} = Integer.parse(secret)
    if num < 1000 do
      gen_secret()
    else
      secret
    end
  end

  @doc """
  Adds a participant to the given game. If the game is in its setup phase,
  participants may be added as either players (allowed to place guesses)
  or observers (not allowed to guess). For all other states, the requested
  participant will be ignored and the participant will be added as an observer.

  ## Arguments

    - st: the current game state
    - participant: participant, including name and requested type

  ## Examples

    iex> Bulls.Game.add_player(%{phase: :setup, participants: %{}}, {"foo", :player})
    %{participants: %{"foo" => :lobby_player}, phase: :setup}

    iex> Bulls.Game.add_player(%{phase: :setup, participants: %{"foo" => :player}}, {"bar", :observer})
    %{participants: %{"foo" => :player, "bar" => :observer}, phase: :setup}

    iex> Bulls.Game.add_player(%{phase: :play, participants: %{}}, {"foo", :player})
    %{participants: %{"foo" => :observer}, phase: :play}
  """
  @spec add_player(game_state, game_participant) :: game_state
  def add_player(st, {pname, :player}) do
    ps = Map.get(st, :participants)

    if  Map.get(st, :phase) != :setup do
      %{st | participants: Map.put(ps, pname, :observer)}
    else
      %{st | participants: Map.put(ps, pname, :lobby_player)}
    end
  end

  def add_player(st, {pname, :observer}) do
    ps = Map.get(st, :participants)
    %{st | participants: Map.put(ps, pname, :observer)}
  end

  @doc """
  Marks a player as ready to play. Observers remain observers
  if they attempt to become ready to play.

  ## Arguments

    - st: current game state
    - pname: name of the player to mark as ready

  ## Examples

    iex> Bulls.Game.ready_player(%{participants: %{"baz" => :player}, phase: :setup}, "foo")
    %{participants: %{"baz" => :player}, phase: :setup}

    iex> Bulls.Game.ready_player(%{participants: %{"foo" => :lobby_player}, phase: :setup}, "foo")
    %{participants: %{"foo" => :player}, phase: :guess}

    iex> Bulls.Game.ready_player(%{participants: %{"bar" => :observer}, phase: :setup}, "bar")
    %{participants: %{"bar" => :observer}, phase: :setup}
  """
  @spec ready_player(game_state, String.t()) :: game_state
  def ready_player(st, pname) do
    ps = Map.get(st, :participants)

    if Map.get(ps, pname) == :lobby_player do
      result = %{st | participants: Map.put(ps, pname, :player)}

      if Enum.all?(Map.get(result, :participants),fn {_, type} -> type != :lobby_player end)
      do
        %{result | phase: :guess}
      else
        result
      end
    else
      st
    end
  end

  @doc """
  Update an existing game state with a new guess. The guess will
  be validated in the process.

  ## Parameters

    - st: existing game state, including secret and previous guesses
    - num: new guess to add to the game state

  ## Examples

    iex> state = Bulls.Game.guess(%{secret: 1234, guesses: MapSet.new, error: ""}, "4567")
    iex> state.secret
    1234
    iex> state.guesses
    #MapSet<["4567"]>

    iex> state = Bulls.Game.guess(%{secret: 1234, guesses: MapSet.new, error: ""}, "0123")
    iex> state.error
    "Invalid guess '0123'. Must be a four-digit number with unique digits"
  """
  @spec guess(game_state, String.t()) :: game_state
  def guess(st, num) do
    num_digits = String.graphemes(num)
    cond do
      won?(st) ->
        %{st | error: "Game already won. Please start a new game."}
      lost?(st) ->
        %{st | error: "Game lost. Please start a new game."}
      Enum.dedup(num_digits) != num_digits ->
        %{st | error: "Guess may not contain duplicate digits."}
      Regex.match?(~r/^[1-9]\d{3}$/, num) ->
        %{st | guesses: MapSet.put(st.guesses, num), error: ""}
      true -> %{st | error: "Invalid guess '#{num}'. Must be a four-digit number with unique digits"}
    end
  end

  @doc """
  Transforms a game state into something viewable by clients (ie
  not containing the secret).

  ## Parameters
    - st: game state
  """
  @spec view(game_state) :: %{guesses: [guess_view], won: boolean, lost: boolean}
  def view(st) do
    game_won = won?(st)
    %{
      guesses: Enum.map(st.guesses, &(view_guess(&1, st.secret))),
      won: game_won,
      lost: lost?(st) and not game_won,
      error: Map.get(st, :error, "")
    }
  end

  defp view_guess(guess, secret) do
    secret_list = String.graphemes(secret)
    guess_list = String.graphemes(guess)
    
    Enum.zip(secret_list, guess_list)
    |> Enum.reduce(%{a: 0, b: 0}, fn {s, g}, %{a: correct, b: displaced} ->
      cond do
        g == s -> %{a: correct + 1, b: displaced}
        g in secret_list -> %{a: correct, b: displaced + 1}
        true -> %{a: correct, b: displaced}
      end
    end)
    |> Map.put(:guess, guess)
  end

  defp won?(st), do: st.secret in st.guesses
  
  defp lost?(st), do: MapSet.size(st.guesses) > 7
end
