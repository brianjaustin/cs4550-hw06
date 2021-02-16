defmodule BullsWeb.GameChannel do
  @moduledoc """
  Channel for interacting with the browser logic of the
  Bulls and Cows game.

  ## Attributions

    This code is based on the Hangman example shown in lecture,
    minus backup agent changes.
    https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0212/hangman/lib/hangman_web/channels/game_channel.ex
  """

  use BullsWeb, :channel

  @impl true
  def join("game:" <> _id, payload, socket) do
    if authorized?(payload) do
      game = Bulls.Game.new()
      socket = assign(socket, :game, game)
      view = Bulls.Game.view(game)
      {:ok, view, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("guess", %{"number" => n}, socket) do
    game_old = socket.assigns[:game]
    game_new = Bulls.Game.guess(game_old, n)
    socket = assign(socket, :game, game_new)
    view = Bulls.Game.view(game_new)
    {:reply, {:ok, view}, socket}
  end

  @impl true
  def handle_in("reset", _, socket) do
    game = Bulls.Game.new()
    socket = assign(socket, :game, game)
    view = Bulls.Game.view(game)
    {:reply, {:ok, view}, socket}
  end

  # We let anyone play at the moment.
  defp authorized?(_payload) do
    true
  end
end
