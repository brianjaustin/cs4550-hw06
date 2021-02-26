defmodule Bulls.GameSupervisor do
  @moduledoc """
  `DynamicSupervisor` for games of bulls and cows.
  
  ## Attribution

    Based on the code provided in lecture/notes, see
    https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0219/hangman/lib/hangman/game_sup.ex.
  """

  use DynamicSupervisor

  def start_link(arg),
    do: DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    {:ok, _} = Registry.start_link(
      keys: :unique,
      name: Bulls.GameRegistry
    )
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(spec),
    do: DynamicSupervisor.start_child(__MODULE__, spec)

end
