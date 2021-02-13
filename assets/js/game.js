import _ from 'lodash';

/* Function for generating the random 4-digit secret number a game player 
 * will guess. Digits will be unique, so 7777 would never be returned.
 *
 * randomSecret :: () -> int
 */
export function randomSecret() {
    let digits = _([0, 1, 2, 3, 4, 5, 6, 7, 8]);
    let result = 0;
    
    while (result < 1000) {
        let secretStr = digits.shuffle().slice(0, 4).join('');
        result = parseInt(secretStr);
    }

    return result;
}

/* Function for determining the correctness of a guess
 * for a given secret. If a digit is in the secret at
 * the same index as in the guess, it is 'correct'. If
 * it is at a different index, it is 'displaced'.
 * 
 * validateQuess :: int -> string -> {correct: int, displaced: int}
 */
export function validateGuess(secret, guess) {
    let result = {
        correct: 0,
        displaced: 0
    };
    let strSecret = secret.toString();

    for (let i = 0; i < guess.length; i++) {
        let digit = guess[i];
        if (digit === strSecret[i]) {
            result.correct++;
        } else if (strSecret.includes(digit)) {
            result.displaced++;
        }
    }

    return result;
}

/* Given the secret and a guess, return a string describing
 * the guess's correctness. The format is XAYB, where
 * X = total correct digits and Y = total digits present
 * but in the wrong place.
 * 
 * guessResult :: int -> string -> string
 */
export function guessResult(secret, guess) {
    let result = validateGuess(secret, guess);
    return `${result.correct}A${result.displaced}B`;
}

/* Given a list of guesses, determine if the game is over.
 * This is defined as there being 8 or more guesses present.
 *
 * isGameOver :: [_] -> boolean
 */
export function isGameOver(guesses) {
    return guesses.length >= 8;
}

/* Given a list of guesses and the game's secret, determine
 * if the game has been won (the guesses contain the secret).
 *
 * isGameWon :: [int] -> string -> boolean
 */
export function isGameWon(guesses, secret) {
    // eslint-disable-next-line eqeqeq
    return guesses.filter(guess => guess == secret).length > 0;
}
