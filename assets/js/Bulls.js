/**
 * This code is based on my work for the React
 * browser game assignment (HW 03). It (including
 * the code in `socket.js`) also uses work from lectures,
 * see the scratch repository
 * (https://github.com/NatTuck/scratch-2021-01/tree/master/4550/0212/hangman)
 * for details.
 */

import React, { useState, useEffect } from "react";
import { ch_join, ch_push, lobby_join, lobby_push } from "./socket";
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

function LobbyJoin({join}) {
  const [currentName, setCurrentName] = useState({game: "", name: ""})

  function updateName(ev) {
    let name = ev.target.value;
    setCurrentName({name: name, game: currentName.game});
  }

  function updateGame(ev) {
    let game = ev.target.value;
    setCurrentName({name:currentName.name, game: game})
  }

  function keyPress(ev) {
    if (ev.key === "Enter") {
      addPlayer()
    }
  }

  function addPlayer(){
    join(currentName.name)
    setCurrentName("")
  }

  return (
    <div className="row">
      <div className="column column-100">
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
      <div className="column">
        <button onClick={addPlayer}>Guess</button>
      </div>
    </div>
  );
}

function LobbyReady({setReady}){

  return (
    <div className="row">
      <button onClick={setReady}>Set Ready</button>
    </div>
  );

}

function Lobby({ startGame }) {
  const [lobbyState, setLobbyState] = useState({
    joined: false,
    ready: false,
    name: "",
    role: "",
    players: [["David", "Waiting"], ["Patrick", "Ready"], ["Alexis", "Waiting"]],
    observers: ["Roland", "Johnny", "Moira"],
  });

  function displayPlayer(name, status){
    return (
      <tr key={name}>
        <td>{name}</td>
        <td>{status}</td>
      </tr>
    )
  }

  function displayStatus(){
    if (lobbyState.ready){
      return "Ready"
    } else {
      return "Waiting for Ready"
    }
  }

  function displaySelf(){
    if (lobbyState.joined && lobbyState.role == "Player"){
      return (
        <table>
          <tbody>
            <tr>
              <td>Name</td>
              <td>{lobbyState.name}</td>
            </tr>
            <tr>
              <td>Role</td>
              <td>{lobbyState.role}</td>
            </tr>
            <tr>
              <td>Status</td>
              <td>{displayStatus()}</td>
            </tr>
          </tbody>
        </table>)
    } else {
      return (
        <table>
          <tbody>
            <tr>
              <td>Name</td>
              <td>{lobbyState.name}</td>
            </tr>
            <tr>
              <td>Role</td>
              <td>{lobbyState.role}</td>
            </tr>
          </tbody>
        </table>
      );
    }
  }

  function addPlayer(player_name){
    setLobbyState({joined: true, ready: false, name: player_name, role: "Player", players: lobbyState.players, observers: lobbyState.observers})
  }

  function setReady(){
    console.log("Made ready")
    setLobbyState({joined:true, ready: true, name: lobbyState.name, role: lobbyState.role, players: lobbyState.players, observers: lobbyState.observers})
  }

  let header = (<h2>Error</h2>)

  if (lobbyState.joined && !lobbyState.ready){
    header = (<LobbyReady setReady={setReady}/>);
  } else if (lobbyState.ready){
    header = (<h2>Waiting for other players to join!</h2>);
  } else {
    header = (<LobbyJoin join={addPlayer} />);
  }

  let self = displaySelf();


  return (
    <div>
      {header}
      {self}
      <h2>Players</h2>
      <table>
        <thead>
          <tr>
            <th>Name</th>
          </tr>
        </thead>
        <tbody>
          {lobbyState.observers.map((observer) => (
            <tr key={observer}>
              <td>{observer}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {lobbyState.players.map((player) =>
            displayPlayer(player[0], player[1])
          )}
        </tbody>
      </table>
    </div>
  );
}

function ActiveGame({ reset, gameState, setGameState }) {
  const [currentGuess, setCurrentGuess] = useState("");

  function setError(err) {
    setGameState(
      Object.assign({}, gameState, {
        error: err,
      })
    );
  }

  function guess() {
    ch_push("guess", { number: currentGuess });
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

  function displayGuess(guess, index) {
    return (
      <tr key={index}>
        <td>{index + 1}</td>
        <td>{guess.guess}</td>
        <td>{`${guess.a}A${guess.b}B`}</td>
      </tr>
    );
  }

  return (
    <div>
      <h1>Bulls</h1>
      <p>Guess a 4 digit number:</p>
      <ErrorMessage msg={gameState.error} />
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
      </div>
      <h2>Guesses:</h2>
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Guess</th>
            <th>Result</th>
          </tr>
        </thead>
        <tbody>
          {gameState.guesses.map((guess, index) => displayGuess(guess, index))}
        </tbody>
      </table>
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
    won: false,
    lost: false,
    startGame: false,
    error: "",
  });

  useEffect(() => ch_join(setGameState));

  function startGame() {
    setGameState({
      guesses: [],
      won: false,
      lost: false,
      startGame: true,
      error: "",
    });
  }

  function reset() {
    ch_push("reset", "");
  }

  if (gameState.lost) {
    return <GameOver reset={reset} />;
  } else if (gameState.won) {
    return <GameWon reset={reset} />;
  } else if (!gameState.startGame) {
    return <Lobby startGame={startGame}/>;
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
