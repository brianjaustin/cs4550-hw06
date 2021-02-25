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
    game = Bulls.BackupAgent.get(name) || Bulls.Game.new(&sched_round/1)
    GenServer.start_link(__MODULE__, game, name: reg(name))
  end

  defp sched_round(round) do
    Process.send_after(self(), {:maintain_round, round}, 30_000)
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

  @doc """
  Mark a player as ready. Observers are assumed to be ready,
  so marking one as 'ready' has no impact.

  ## Argument

    - name: name of the game in which to mark someone ready
    - participant: name of the participant to mark
  """
  @spec ready(String.t(), String.t()) :: term
  def ready(name, participant) do
    GenServer.call(reg(name), {:ready, name, participant})
  end

  @doc """
  Renders the current game in a user-viewable format.
  Internal information like secret is stripped out.

  ## Arguments

    - name: name of the game to view
    - participant: name of the participant who is viewing the game
  """
  @spec view(String.t(), String.t()) :: term
  def view(name, participant) do
    GenServer.call(reg(name), {:view, name, participant})
  end

  @doc """
  Submits a guess for a game participant. Note that only active players
  may guess, other guesses will be ignored.

  ## Arguments

    - name: name of the game in which to guess
    - participant: name of the participant who is guessing
    - number: string guess
  """
  @spec guess(String.t(), String.t(), String.t()) :: term
  def guess(name, participant, number) do
    GenServer.call(reg(name), {:guess, name, participant, number})
  end
  
  defp reg(name), do: {:via, Registry, {Bulls.GameRegistry, name}}

  # Implementation

  def init(game) do
    {:ok, game}
  end

  def handle_call({:join, name, participant}, _from, game) do
    game = Bulls.Game.add_player(game, participant)
    Bulls.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_call({:ready, name, participant}, _from, game) do
    game = Bulls.Game.ready_player(game, participant)
    Bulls.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_call({:view, _name, participant}, _from, game) do
    view = Bulls.Game.view(game, participant)
    {:reply, view, game}
  end

  def handle_call({:guess, name, participant, number}, _from, game) do
    game = Bulls.Game.guess(game, participant, number)
    Bulls.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_info({:maintain_round, round}, game) do
    game = Bulls.Game.finish_round(game, round)
    {:noreply, game}
  end

end
