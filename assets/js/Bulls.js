import React, { useState, useEffect } from 'react';
import { ch_join, ch_push } from './socket';
import _ from 'lodash';

function ErrorMessage({msg}) {
  if (msg) {
    return (
      <div className="error">
        <p>{msg}</p>
      </div>
    );
  } else {
    return null;
  }
}

function ActiveGame({reset, gameState, setGameState}) {
  const [currentGuess, setCurrentGuess] = useState("");

  function setError(err) {
    setGameState(Object.assign({}, gameState, {
      error: err,
    }));
  }

  function guess() {
      ch_push("guess", {number: currentGuess});
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
      <div>
        <input type="text"
               value={currentGuess}
               onChange={updateGuess}
               onKeyPress={keyPress} />
        <button onClick={guess}>
          Guess
        </button>
      </div>
      <button className="button button-outline"
              onClick={() => { reset(); setCurrentGuess(""); } }>
        Reset Game
      </button>
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

function GameOver({reset}) {
  return (
    <div>
      <h1>Game Over!</h1>
      <p>You failed to guess the secret number.</p>
      <button onClick={reset}>
        Reset Game
      </button>
    </div>
  );
}

function GameWon({reset}) {
  return (
    <div>
      <h1>You won!</h1>
      <p>You correctly guessed the secret number!</p>
      <button onClick={reset}>
        Play Again
      </button>
    </div>
  );
}

function Bulls() {
  const [gameState, setGameState] = useState({
    guesses: [],
    won: false,
    lost: false,
    error: "",
  });

  useEffect(() => ch_join(setGameState));

  function reset() {
    ch_push("reset", "");
  }

  if (gameState.lost) {
    return (
      <GameOver reset={reset} />
    );
  } else if (gameState.won) {
    return (
      <GameWon reset={reset} />
    );
  }
  else {
    return (
      <ActiveGame reset={reset}
                  gameState={gameState}
                  setGameState={setGameState} />
    );
  }
}

export default Bulls;
