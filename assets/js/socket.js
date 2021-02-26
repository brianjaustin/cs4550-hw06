import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: ""}});
socket.connect();

let channel = null;

let gameState = {
  guesses: [],
  participants: [],
  previous_winners: [],
  lobby: true,
  won: false,
  lost: false,
  error: "",
};

let callback = null;

function state_update(st) {
  gameState = st;
  if (callback) {
    callback(st);
  }
}

export function ch_start(game_name, role) {
  channel = socket.channel(`game:${game_name}`, role);
  channel
    .join()
    .receive("ok", state_update)
    .receive("error", (resp) => console.log("Unable to join", resp));
  channel.on("view", state_update);
}

export function ch_join(cb) {
  console.log(gameState)
  callback = cb;
  callback(gameState);
}

export function ch_push(type, msg) {
  channel.push(type, msg)
    .receive("ok", state_update)
    .receive("error", resp => console.log("Unable to push", resp));
}
