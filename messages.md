# Game Channel
Messaged passed along this channel are used to advance game state for players.

## Join
This is required for any participants to be assigned to their chosen
Bulls and Cows game, either as an observer or as a player. Once joining,
players must mark themselves as ready in order to be active.

### Request
```javascript
// as a player
let channel = socket.channel("game:game_name", {player: "player_name"});
// as an observer
let channel = socket.channel("game:game_name", {observer: "observer_name"});
```

### Response
```json
{
  "guesses": {
    "foo": [{"guess": "1234", "a": 1, "b": 2}], // Sorted by round
    "bar": [{"guess": "5432", "a": 2, "b": 1}]
  },
  "participants": {
    "foo": "player",
    "bar": "player",
    "baz": "observer"
  },
  "lobby": false, // Represents whether or not new players may join
  "error": "" // Error is specific to participant
}
```
Note: when new players join, this state is pushed to all players.

## Ready
This exchange is only required for players. All players must set themselves
ready for a game to begin.

### Request
```javascript
channel.push("ready", "")
```

### Response
The response is identical to the response for join.
