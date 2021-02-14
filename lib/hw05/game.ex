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

  @type guess_view :: {
    guess :: String.t(),
    a :: non_neg_integer,
    b :: non_neg_integer
  }
  @type game_state :: {secret :: String.t(), guesses :: [String.t()]}

  @doc """
  Produces a blank game state, with empty guesses and a randomly
  generated secret.
  """
  @spec new :: game_state
  def new do
    %{
      secret: gen_secret(),
      guesses: MapSet.new
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
  Update an existing game state with a new guess. The guess will
  be validated in the process.

  ## Parameters

    - st: existing game state, including secret and previous guesses
    - num: new guess to add to the game state

  ## Examples

    iex> state = Bulls.Game.guess(%{secret: 1234, guesses: MapSet.new}, "4567")
    iex> state.secret
    1234
    iex> state.guesses
    #MapSet<["4567"]>

    iex> state = Bulls.Game.guess(%{secret: 1234, guesses: MapSet.new}, "0123")
    iex> state.error
    "Invalid guess '0123'"
  """
  @spec guess(game_state, String.t()) :: game_state
  def guess(st, num) do
    cond do
      won?(st) ->
        Map.put(st, :error, "Game already won. Please start a new game.")
      lost?(st) ->
        Map.put(st, :error, "Game lost. Please start a new game.")
      Regex.match?(~r/^[1-9]\d{3}$/, num) ->
        %{st | guesses: MapSet.put(st.guesses, num)}
      true -> Map.put(st, :error, "Invalid guess '#{num}'")
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
      lost: lost?(st) and not game_won
    }
  end

  defp view_guess(guess, secret) do
    secret_list = secret |> String.split("", trim: true)
    guess_list = guess |> String.split("", trim: true)
    
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
