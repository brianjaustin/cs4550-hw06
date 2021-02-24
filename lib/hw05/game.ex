defmodule Bulls.Game do
  @moduledoc """
  Provides functionality for running a game of Bulls and Cows.

  ## Game Play

    First, a random 4-digit number is generated. This random secret
    must be between 1000 and 9999, and there may be no repeating digits
    (so 1233 and 0123 are invalid secrets). Next, players input
    _valid_ attempts to guess the secret number. The player(s) to guess
    the secret in the fewest number of rounds win.

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
    participants: %{String.t() => :pending_player | :player | :observer},
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

  @type game_view :: %{
    guesses: %{String.t() => guess_view},
    participants: %{String.t() => :player | :observer},
    winners: [String.t()],
    lobby: boolean,
    errors: [String.t()]
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
    %{participants: %{"foo" => :pending_player}, phase: :setup}

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
      %{st | participants: Map.put(ps, pname, :pending_player)}
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

    iex> Bulls.Game.ready_player(%{participants: %{"foo" => :pending_player}, phase: :setup}, "foo")
    %{participants: %{"foo" => :player}, phase: :guess}

    iex> Bulls.Game.ready_player(%{participants: %{"bar" => :observer}, phase: :setup}, "bar")
    %{participants: %{"bar" => :observer}, phase: :setup}
  """
  @spec ready_player(game_state, String.t()) :: game_state
  def ready_player(st, pname) do
    ps = Map.get(st, :participants)

    if Map.get(ps, pname) == :pending_player do
      result = %{st | participants: Map.put(ps, pname, :player)}

      if Enum.all?(Map.get(result, :participants),fn {_, type} -> type != :pending_player end)
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
    - player: name of the player making the guess
    - num: new guess to add to the game state
  """
  @spec guess(game_state, String.t(), String.t()) :: game_state
  def guess(st, player, num) do
    # Pull out some important state keys here,
    # because pattern matching for maps inevitably
    # leads to disappointment.
    es = Map.get(st, :errors)
    ps = Map.get(st, :participants)

    num_digits = String.graphemes(num)
    cond do
      Map.get(st, :phase) == :setup ->
        %{st | errors: Map.put(es, player, "Game not yet started.")}
      Map.get(st, :phase) == :result ->
        %{st | errors: Map.put(es, player, "Game already concluded. Please start a new game.")}
      Map.get(ps, player, :observer) != :player ->
        %{st | errors: Map.put(es, player, "Only ready players may place guesses.")}
      Enum.dedup(num_digits) != num_digits ->
        %{st | errors: Map.put(es, player, "Guess may not contain duplicate digits.")}
      Regex.match?(~r/^[1-9]\d{3}$/, num) ->
        do_guess(%{st | errors: Map.put(es, player, "")}, player, num)
      true ->
        %{st | errors: Map.put(
          es, player, "Invalid guess '#{num}'. Must be a four-digit number with unique digits"
        )}
    end
  end

  defp do_guess(st, player, num) do
    gs = Map.get(st, :guesses)
    player_guesses = Map.get(gs, player, [])
    player_guesses = Enum.dedup([num | player_guesses])

    %{st | guesses: Map.put(gs, player, player_guesses)}
  end

  @doc """
  Does book keeping at the end of a game play round,
  including setting the state if a correct guess has been made.

  ## Arguments

    - st: game state

  ## Examples

    iex> Bulls.Game.finish_round(%{secret: "1234", guesses: %{}, phase: :guess})
    %{secret: "1234", guesses: %{}, phase: :guess}

    iex> Bulls.Game.finish_round(%{secret: "1234", guesses: %{"foo" => ["1234"]}, phase: :guess})
    %{secret: "1234", guesses: %{"foo" => ["1234"]}, phase: :result}
  """
  @spec finish_round(game_state) :: game_state
  def finish_round(st) do
    if Enum.empty?(get_winners(st)) do
      st
    else
      %{st | phase: :result}
    end
  end

  @doc """
  Transforms a game state into something viewable by clients (ie
  not containing the secret).

  ## Parameters
    - st: game state
  """
  @spec view(game_state) :: game_view
  def view(st) do
    guess_views = st.guesses
    |> Enum.map(&view_guesses(&1, st.secret))
    |> Enum.into(%{})
    %{
      guesses: guess_views,
      lobby: st.phase == :setup,
      participants: st.participants,
      winners: get_winners(st),
      errors: Map.get(st, :error, "")
    }
  end

  defp view_guesses({player, guesses}, secret) do
    guesses = Enum.map(guesses, &view_guess(&1, secret))
    {player, guesses}
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

  defp get_winners(st) do
    Enum.reduce(st.guesses, [], fn({player, guesses}, acc) ->
      if st.secret in guesses, do: [player | acc], else: acc
    end)
  end

end
