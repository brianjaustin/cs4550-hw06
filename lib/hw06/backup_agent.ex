defmodule Bulls.BackupAgent do
  @moduledoc """
  Agent to backup the state of in-progress Bulls and Cows
  games.
  
  ## Attribution

    Based on the code from lecture notes, see
    https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0219/hangman/lib/hangman/backup_agent.ex.
  """

  use Agent

  def start_link(_arg),
    do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  @doc """
  Stores the given value at the given key.

  ## Parameters

    - name: the key at which to store the value
    - val: the value to store

  ## Examples

    iex> Bulls.BackupAgent.start_link(nil)
    iex> Bulls.BackupAgent.put("foo", %{a: 1})
    :ok
    iex> Bulls.BackupAgent.put("bar", %{b: 1})
    :ok

    iex> Bulls.BackupAgent.start_link(nil)
    iex> Bulls.BackupAgent.put("foo", %{a: 1})
    :ok
    iex> Bulls.BackupAgent.put("foo", %{b: 1})
    :ok
  """
  @spec put(String.t(), Bulls.Game.game_state) :: :ok
  def put(name, val) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, name, val)
    end)
  end

  @doc """
  Retrieves the value at the given key, if available.

  ## Arguments

    - name: the key to query for a value

  ## Examples

    iex> Bulls.BackupAgent.start_link(nil)
    iex> Bulls.BackupAgent.get("foo")
    nil

    iex> Bulls.BackupAgent.start_link(nil)
    iex> Bulls.BackupAgent.put("foo", %{a: 1})
    :ok
    iex> Bulls.BackupAgent.get("foo")
    %{a: 1}
  """
  @spec get(String.t()) :: Bulls.Game.game_state | nil
  def get(name) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state, name)
    end)
  end
end
