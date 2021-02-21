defmodule Bulls.GameServer do
  @moduledoc """
  Manages game state for a single game of Bulls and Cows
  with multiple players (and, optionally, observers).

  ## Attribution

    The code in this module is based on lecture notes, see
    https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0219/hangman/lib/hangman/game_server.ex.
  """

  use GenServer

  # Public interface

  def start(name) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [name]},
      restart: :permanent,
      type: :worker
    }
    Bulls.GameSupervisor.start_child(spec)
  end

  def start_link(name) do
    game = Bulls.BackupAgent.get(name) || Bulls.Game.new()
    GenServer.start_link(__MODULE__, game, name: reg(name))
  end

  @doc """
  Adds a player to the game managed by this server.
  If the game has not begun, players and observers both
  may join. If the game is already in progress, any join
  attempt will be interpreted as an observer.

  ## Arguments

    - participant: the person trying to join
  """
  @spec join(String.t(), Bulls.Game.game_participant) :: term
  def join(name, participant) do
    GenServer.call(reg(name), {:join, name, participant})
  end
  
  defp reg(name), do: {:via, Registry, {Bulls.GameRegistry, name}}

  # Implementation

  # TODO: can this be private?
  def init(game) do
    {:ok, game}
  end

  def handle_call({:join, name, participant}, _from, game) do
    game = Bulls.Game.add_player(game, participant)
    Bulls.BackupAgent.put(name, game)
    {:reply, game, game}
  end

end
