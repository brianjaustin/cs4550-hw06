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
    round: non_neg_integer | :result,
    participants: %{
      String.t() =>
      :observer
      | {:lobby_player, non_neg_integer, non_neg_integer}
      | {:player, non_neg_integer, non_neg_integer}
    },
    secret: String.t(),
    guesses: %{String.t() => [String.t()]},
    errors: %{String.t() => String.t()},
    sched: (non_neg_integer -> term)
  }

  @typedoc "Represents a user visible guess result"
  @type guess_view :: %{
    guess: String.t(),
    a: non_neg_integer,
    b: non_neg_integer
  }

  @typedoc "Represents the state as viewable by participants"
  @type game_view :: %{
    guesses: %{String.t() => guess_view},
    participants: %{String.t() => :observer | {:player, non_neg_integer, non_neg_integer}},
    lobby: boolean,
    errors: String.t()
  }

  @doc """
  Produces a blank game state, with empty guesses and a randomly
  generated secret.

  ## Arguments

    - sched_callback: callback function used for round maintenance
  """
  @spec new((non_neg_integer -> term)) :: game_state
  def new(sched_callback) do
    %{
      round: 0,
      participants: %{},
      secret: gen_secret(),
      guesses: %{},
      errors: %{},
      sched: sched_callback,
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
  Adds a participant to the given game. If the game is in its setup round,
  participants may be added as either players (allowed to place guesses)
  or observers (not allowed to guess). For all other states, the requested
  participant will be ignored and the participant will be added as an observer.

  ## Arguments

    - st: the current game state
    - participant: participant, including name and requested type

  ## Examples

    iex> Bulls.Game.add_player(%{round: 0, participants: %{}}, {"foo", :player})
    %{participants: %{"foo" => {:lobby_player, 0, 0}}, round: 0}

    iex> Bulls.Game.add_player(%{round: 0, participants: %{"foo" => {:player, 1, 2}}}, {"bar", :observer})
    %{participants: %{"foo" => {:player, 1, 2}, "bar" => :observer}, round: 0}

    iex> Bulls.Game.add_player(%{round: 1, participants: %{}}, {"foo", :player})
    %{participants: %{"foo" => :observer}, round: 1}
  """
  @spec add_player(game_state, game_participant) :: game_state
  def add_player(st, {pname, :player}) do
    cond do
      registered?(st, pname) ->
        st
      st.round > 0 ->
        %{st | participants: Map.put(st.participants, pname, :observer)}
      true ->
        %{
          st | participants: Map.put(st.participants, pname, {:lobby_player, 0, 0})
        }
    end
  end

  def add_player(st, {pname, :observer}) do
    if registered?(st, pname) do
      st
    else
      %{st | participants: Map.put(st.participants, pname, :observer)}
    end
  end

  defp registered?(st, name), do: name in Map.keys(st.participants)

  @doc """
  Marks a player as ready to play. Observers remain observers
  if they attempt to become ready to play.

  ## Arguments

    - st: current game state
    - pname: name of the player to mark as ready

  ## Examples

    iex> Bulls.Game.ready_player(%{participants: %{"baz" => {:player, 0, 0}}, guesses: %{}, round: 0, sched: &Function.identity/1}, "foo")
    %{participants: %{"baz" => {:player, 0, 0}}, guesses: %{}, round: 0, sched: &Function.identity/1}

    iex> Bulls.Game.ready_player(%{participants: %{"foo" => {:lobby_player, 1, 2}}, guesses: %{}, round: 0, sched: &Function.identity/1}, "foo")
    %{participants: %{"foo" => {:player, 1, 2}}, guesses: %{"foo" => []}, round: 1, sched: &Function.identity/1}

    iex> Bulls.Game.ready_player(%{participants: %{"bar" => :observer}, guesses: %{}, round: 0, sched: &Function.identity/1}, "bar")
    %{participants: %{"bar" => :observer}, guesses: %{}, round: 0, sched: &Function.identity/1}
  """
  @spec ready_player(game_state, String.t()) :: game_state
  def ready_player(st, pname) do
    case Map.get(st.participants, pname) do
      {:lobby_player, ws, ls} ->
        result = %{
          st |
          participants: Map.put(st.participants, pname, {:player, ws, ls}),
          guesses: Map.put(st.guesses, pname, [])
        }

        if Enum.all?(result.participants, fn {_, type} -> type != :lobby_player end)
        do
          st.sched.(1)
          %{result | round: 1}
        else
          result
        end

      _ -> st
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
    num_digits = String.graphemes(num)
    cond do
      st.round == 0 ->
        %{st | errors: Map.put(st.errors, player, "Game not yet started.")}
      active?(Map.get(st.participants, player, :observer)) ->
        %{st | errors: Map.put(st.errors, player, "Only ready players may place guesses.")}
      num == "----" ->
        do_pass(%{st | errors: Map.put(st.errors, player, "")}, player)
      Enum.dedup(num_digits) != num_digits ->
        %{st | errors: Map.put(st.errors, player, "Guess may not contain duplicate digits.")}
      Regex.match?(~r/^[1-9]\d{3}$/, num) ->
        do_guess(%{st | errors: Map.put(st.errors, player, "")}, player, num)
      true ->
        %{st | errors: Map.put(
          st.errors, player, "Invalid guess '#{num}'. Must be a four-digit number with unique digits"
        )}
    end
  end

  defp active?(:observer), do: true
  defp active?({:lobby_player, _, _}), do: true
  defp active?({:player, _, _}), do: false


  defp do_guess(st, player, num) do
    player_guesses = Map.get(st.guesses, player, [])
    cond do
      dup_guess?(player_guesses, num) ->
        st
      guessed_already?(st, player_guesses) ->
        st
      true ->
        player_guesses = [{num, st.round} | player_guesses]
        result = %{st | guesses: Map.put(st.guesses, player, player_guesses)}
        if all_guessed?(result) do
          finish_round(result, st.round)
        else
          result
        end
    end
  end

  defp do_pass(st, player) do
    player_guesses = Map.get(st.guesses, player, [])
    player_guesses = [{"----", st.round} | player_guesses]
    result = %{ st | guesses: Map.put(st.guesses, player, player_guesses)}

    if all_guessed?(result) do
      finish_round(result, st.round)
    else
      result
    end
  end

  defp dup_guess?(guesses, num) do
    Enum.any?(guesses, fn {guess, _} -> guess == num end)
  end

  defp guessed_already?(_, []), do: false
  defp guessed_already?(st, [{_, round} | _]), do: st.round == round

  defp all_guessed?(st) do
    guesses_this_round = st.guesses
    |> Enum.flat_map(fn {_, gs} -> gs end)
    |> Enum.filter(fn {_, r} -> st.round == r end)
    |> Enum.count()

    players = st.participants
    |> Enum.filter(fn
      {_, {role, _, _}} -> role == :player
      _-> false
    end)
    |> Enum.count()

    guesses_this_round == players
  end

  @doc """
  Does book keeping at the end of a game play round,
  including setting the state if a correct guess has been made.
  If the active round is not the one expected, ignore the request.

  ## Arguments

    - st: game state
    - round: the round to target
  """
  @spec finish_round(game_state, non_neg_integer) :: game_state
  def finish_round(st, round) do
    cond do
      st.round != round ->
        st
      Enum.empty?(get_winners(st)) ->
        new_round = st.round + 1
        guesses = st.guesses
        |> Enum.map(fn {player, guesses} -> {player, pass_player(st, guesses)} end)
        |> Enum.into(%{})
        st.sched.(new_round)
        %{st | guesses: guesses, round: new_round}
      true ->
        conclude(st)
    end
  end

  defp pass_player(st, guesses) do
    if not guessed_already?(st, guesses) do
      [{"----", st.round} | guesses]
    else
      guesses
    end
  end

  @doc """
  Concludes the current game by generating a new secret and putting
  players in the lobby.

  ## Arguments

    - st: game to conclude
  """
  @spec conclude(game_state) :: game_state
  def conclude(st) do
    guesses = st.participants
    |> Enum.map(fn {p, _} -> {p, []} end)
    |> Enum.into(%{})

    participants = st.participants
    |> Enum.map(&conclude_player(st, &1))
    |> Enum.into(%{})

    %{
      st |
      round: 0,
      secret: gen_secret(),
      guesses: guesses,
      participants: participants,
      errors: %{},
    }
  end

  defp conclude_player(st, {player, {:player, ws, ls}}) do
    winners = get_winners(st)
    cond do
      Enum.count(winners) < 1 ->
        {player, {:lobby_player, ws, ls}}
      player in winners ->
        {player, {:lobby_player, ws + 1, ls}}
      true ->
        {player, {:lobby_player, ws, ls + 1}}
    end
  end

  defp conclude_player(_, participant), do: participant

  @doc """
  Transforms a game state into something viewable by clients (ie
  not containing the secret).

  ## Parameters
    - st: game state
  """
  @spec view(game_state) :: game_view
  def view(st) do
    guess_views = st.guesses
    |> Enum.map(&view_guesses(&1, st))
    |> Enum.into(%{})

    # Channels don't serialize tuples properly, so make them into lists
    # here (if applicable).
    participants = st.participants
    |> Enum.map(&view_participant/1)
    |> Enum.into(%{})

    %{
      guesses: guess_views,
      lobby: st.round == 0,
      participants: participants,
      errors: st.errors
    }
  end

  defp view_participant({name, {_, _, _} = metadata}) do
    {name, Tuple.to_list(metadata)}
  end

  defp view_participant(participant) do
    participant
  end

  defp view_guesses({player, guesses}, st) do
    guesses = guesses
    |> Enum.drop_while(fn {_, round} -> round == st.round end)
    |> Enum.map(&view_guess(&1, st.secret))
    |> Enum.reverse()
    {player, guesses}
  end

  defp view_guess({guess, _}, secret) do
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
      pguesses = Enum.map(guesses, fn {guess, _} -> guess end)
      if st.secret in pguesses, do: [player | acc], else: acc
    end)
  end

end
