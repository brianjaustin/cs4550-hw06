defmodule BullsWeb.GameChannel do
  @moduledoc """
  Channel for interacting with the browser logic of the
  Bulls and Cows game.

  ## Attributions

    This code is based on the Hangman example shown in lecture,
    minus backup agent changes.
    https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0219/hangman/lib/hangman_web/channels/game_channel.ex
  """

  use BullsWeb, :channel

  @impl true
  def join("game:" <> name, %{"player" => player}, socket) do
    do_join(name, {player, :player}, socket)
  end

  @impl true
  def join("game:" <> name, %{"observer" => observer}, socket) do
    do_join(name, {observer, :observer}, socket)
  end

  defp do_join(name, {pname, _} = participant, socket) do
    name
    |> Bulls.GameServer.start()
    |> Bulls.GameServer.join(participant)
    socket = socket
    |> assign(:name, name)
    |> assign(:participant, pname)

    view = Bulls.GameServer.view(name, pname)
    broadcast(socket, "view", view)
    {:ok, view, socket}
  end

  @impl true
  def handle_in("ready", _payload, socket) do
    name = socket.assigns[:name]
    participant = socket.assigns[:participant]
    view = name
    |> Bulls.GameServer.ready(participant)
    |> Bulls.GameServer.view(participant)

    broadcast(socket, "view", view)
    {:reply, {:ok, view}, socket}
  end

  @impl true
  def handle_in("guess", %{"number" => n}, socket) do
    participant = socket.assigns[:participant]
    view = socket.assigns[:name]
    |> Bulls.GameServer.guess(participant, n)
    |> Bulls.GameServer.view(participant)

    {:reply, {:ok, view}, socket}
  end

  @impl true
  def handle_in("reset", _, socket) do
    # TODO
    {:reply, {:ok, nil}, socket}
  end

end
