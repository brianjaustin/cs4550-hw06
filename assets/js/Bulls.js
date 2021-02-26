/**
 * This code is based on my work for the React
 * browser game assignment (HW 03). It (including
 * the code in `socket.js`) also uses work from lectures,
 * see the scratch repository
 * (https://github.com/NatTuck/scratch-2021-01/tree/master/4550/0212/hangman)
 * for details.
 */

import React, { useState, useEffect } from "react";
import { ch_join, ch_push, ch_start } from "./socket";
import _ from "lodash";

function ErrorMessage({ msg }) {
  if (msg) {
    return (
      <p class="alert alert-danger" role="alert">
        {msg}
      </p>
    );
  } else {
    return null;
  }
}

function LobbyReady({ setReady }) {
  return (
    <div className="row">
      <button onClick={setReady}>Set Ready</button>
    </div>
  );
}

function Lobby({ gameState, addPlayer, addObserver, setGameState }) {
  const [currentName, setCurrentName] = useState({ game: "", name: gameState.player_name });

  function displayPlayer(name, status, wins, losses) {
    return (
      <tr key={name}>
        <td>{name}</td>
        <td>{status}</td>
        <td>{wins}</td>
        <td>{losses}</td>
      </tr>
    );
  }

  function setReady() {
    ch_push("ready", "");
  }

  function updateName(ev) {
    let name = ev.target.value;
    setCurrentName({ name: name, game: currentName.game });
  }

  function updateGame(ev) {
    let game = ev.target.value;
    setCurrentName({ name: currentName.name, game: game });
  }

  function keyPress(ev) {
    if (ev.key === "Enter") {
      addPlayer();
    }
  }

  function addPlayerToState() {
    addPlayer(currentName.game, currentName.name);
  }

  function addObserverToState() {
    addObserver(currentName.game, currentName.name);
  }

  let header = <h2>Error</h2>;

  let lobbyJoin = (
    <div>
      <div className="row">
        <div className="column">
          <h4>Enter Your Game Name:</h4>
        </div>
        <div className="column column-60">
          <input
            type="text"
            value={currentName.game}
            onChange={updateGame}
            onKeyPress={keyPress}
          />
        </div>
      </div>
      <div className="row">
        <div className="column column-100">
          <h4>Enter Your User Name:</h4>
        </div>
        <div className="column column-60">
          <input
            type="text"
            value={currentName.name}
            onChange={updateName}
            onKeyPress={keyPress}
          />
        </div>
      </div>
      <div className="row">
        <div className="column">
          <button onClick={addPlayerToState}>Join as Player</button>
        </div>
        <div className="column">
          <button onClick={addObserverToState}>Join As Observer</button>
        </div>
      </div>
    </div>
  );

  if (currentName.name in gameState.participants) {
    if (gameState.participants[currentName.name][0] == "lobby_player") {
      header = <LobbyReady setReady={setReady} />;
    } else {
      header = <h2>Waiting for other players to join!</h2>;
    }
  } else {
    header = lobbyJoin;
  }

  return (
    <div>
      {header}
      <h2>Players</h2>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Status</th>
            <th>Wins</th>
            <th>Losses</th>
          </tr>
        </thead>
        <tbody>
          {Object.entries(gameState.participants).map((player) =>
            displayPlayer(player[0], player[1][0], player[1][1], player[1][2])
          )}
        </tbody>
      </table>
    </div>
  );
}

function ActiveGame({ reset, gameState, setGameState }) {
  const [currentGuess, setCurrentGuess] = useState("");

  function guess() {
    ch_push("guess", { number: currentGuess });
  }

  function pass() {
    ch_push("guess", {number:"----"});
  }

  // Update functions based on code from lecture from 2021-01-29:
  // https://github.com/NatTuck/scratch-2021-01/blob/master/4550/0129/hangman/src/App.js
  function updateGuess(ev) {
    let guess = ev.target.value;
    setCurrentGuess(guess);
  }

  function keyPress(ev) {
    if (ev.key === "Enter") {
      guess();
    }
  }

  function displayGuesses(player_info) {
    let player_name = player_info[0];
    let guesses = player_info[1];
    return guesses.map((guess, index) =>
      displayGuess(guess, player_name, index)
    );
  }

  function displayGuess(guess, name, index) {
    return (
      <tr key={String(guess.guess).concat(String(name).concat(index))}>
        <td>{name}</td>
        <td>{guess.guess}</td>
        <td>{`${guess.a}A${guess.b}B`}</td>
      </tr>
    );
  }

  let guesses = (
    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>Guess</th>
          <th>Result</th>
        </tr>
      </thead>
      <tbody>
        {Object.entries(gameState.guesses).map((guesses) =>
          displayGuesses(guesses)
        )}
      </tbody>
    </table>
  );

  let input_guess = (
    <div className="row">
      <div className="column column-60">
        <input
          type="text"
          value={currentGuess}
          onChange={updateGuess}
          onKeyPress={keyPress}
        />
      </div>
      <div className="column">
        <button onClick={guess}>Guess</button>
      </div>
      <div className="column">
        <button onClick={pass}>Pass</button>
      </div>
    </div>
  );

  if (gameState.participants[gameState.player_name][0] != "player") {
    input_guess = (<p>Only Ready Players can guess</p>)
  }


  return (
    <div>
      <h1>Bulls</h1>
      <p>Guess a 4 digit number:</p>
      <ErrorMessage msg={gameState.error} />
      {input_guess}
      <div className="column">
        <button
          className="button button-outline"
          onClick={() => {
            reset();
            setCurrentGuess("");
          }}
        >
          Reset Game
        </button>
      </div>
      {guesses}
    </div>
  );
}

function GameOver({ reset }) {
  return (
    <div>
      <h1>Game Over!</h1>
      <p>You failed to guess the secret number.</p>
      <button onClick={reset}>Reset Game</button>
    </div>
  );
}

function GameWon({ reset }) {
  return (
    <div>
      <h1>You won!</h1>
      <p>You correctly guessed the secret number!</p>
      <button onClick={reset}>Play Again</button>
    </div>
  );
}

function Bulls() {
  const [gameState, setGameState] = useState({
    guesses: [],
    participants: [],
    winners: [],
    lobby: true,
    error: "",
    player_name: "",
  });

  function setGameStateWOName(st){
    let new_state = Object.assign(st, {player_name: gameState.player_name})
    setGameState(new_state)
  }

  function setName(name){
    let new_state = gameState
    new_state.player_name = name
    setGameState(new_state)
  }

  useEffect(() => ch_join(setGameStateWOName));

  function addPlayer(game_name, player_name) {
    setName(player_name)
    ch_start(game_name, { player: player_name });
  }

  function addObserver(game_name, player_name) {
    setName(player_name)
    ch_start(game_name, { observer: player_name });
  }

  function reset() {
    ch_push("reset", "");
  }

  if (gameState.lobby) {
    return (
      <Lobby
        gameState={gameState}
        addPlayer={addPlayer}
        addObserver={addObserver}
        setGameState={setGameState}
      />
    );
  } else {
    return (
      <ActiveGame
        reset={reset}
        gameState={gameState}
        setGameState={setGameState}
      />
    );
  }
}

export default Bulls;
