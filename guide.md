# Multiplayer Quiz Game – First-to-Buzz System

## 1. Project Overview

A real-time multiplayer multiple-choice quiz game where 3 or more players compete by answering randomly selected questions.

The game uses a **First-to-Buzz** mechanism. Players compete to press the buzzer first, and the first player gets the opportunity to answer.

### Technology Stack

| Technology | Purpose |
|---|---|
| ReactJS | Frontend application |
| Material UI (MUI) | User interface |
| Socket.IO Client | Real-time communication |
| Node.js | Game server and game logic |
| Socket.IO | Multiplayer communication |
| JavaScript JSON files | Question bank |
| In-memory JavaScript objects | Active game rooms, players, and scores |

**Important:** The initial version does not require a database, Laravel, PostgreSQL, or Redis.

---

## 2. System Architecture

```text
MULTIPLAYER QUIZ GAME
│
├── CLIENT (ReactJS)
│   ├── Home Page
│   ├── Create Room
│   ├── Join Room
│   ├── Waiting Lobby
│   ├── Game Interface
│   ├── Buzzer
│   ├── Answer Selection
│   ├── Leaderboard
│   └── Game Results
│
└── SERVER (Node.js)
    │
    ├── Socket.IO
    │   ├── Room Events
    │   ├── Player Events
    │   ├── Buzzer Events
    │   ├── Answer Events
    │   └── Score Events
    │
    ├── Game Manager
    │   ├── Create Room
    │   ├── Join Room
    │   ├── Start Game
    │   ├── Next Question
    │   ├── Validate Answer
    │   └── Calculate Score
    │
    ├── In-Memory Storage
    │   ├── Active Rooms
    │   ├── Players
    │   ├── Scores
    │   ├── Current Questions
    │   └── Game Status
    │
    └── JSON Question Bank
        ├── Questions
        ├── Choices
        ├── Correct Answers
        └── Difficulty
```

---

## 3. Project Structure

```text
quiz-game/
│
├── client/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Buzzer.jsx
│   │   │   ├── QuestionCard.jsx
│   │   │   ├── AnswerChoices.jsx
│   │   │   ├── PlayerList.jsx
│   │   │   ├── GameTimer.jsx
│   │   │   └── Leaderboard.jsx
│   │   │
│   │   ├── pages/
│   │   │   ├── Home.jsx
│   │   │   ├── CreateRoom.jsx
│   │   │   ├── JoinRoom.jsx
│   │   │   ├── Lobby.jsx
│   │   │   ├── Game.jsx
│   │   │   └── Results.jsx
│   │   │
│   │   ├── hooks/
│   │   │   └── useGameSocket.js
│   │   │
│   │   ├── store/
│   │   │   └── gameStore.js
│   │   │
│   │   ├── socket.js
│   │   └── App.jsx
│   │
│   └── package.json
│
└── server/
    ├── data/
    │   └── questions.json
    │
    ├── managers/
    │   └── gameManager.js
    │
    ├── events/
    │   ├── roomEvents.js
    │   ├── gameEvents.js
    │   └── answerEvents.js
    │
    ├── rooms.js
    ├── index.js
    └── package.json
```

---

## 4. Game Rules

### Players

- Minimum players: 2
- Recommended players: 3–10
- Players can create or join a room.
- Each room has a unique room code.
- Players do not need accounts or login.
- All players receive the same question simultaneously.

### First-to-Buzz Mechanism

1. A new question is displayed to all players.
2. The buzzer becomes available to everyone.
3. The first player to press the buzzer gets the opportunity to answer.
4. Other players are temporarily prevented from answering.
5. If the answer is correct, award points.
6. If the answer is incorrect, allow the remaining eligible players to buzz.
7. If everyone answers incorrectly, reveal the correct answer.
8. Move to the next question.

**Important:** The buzzer resets after every question.

---

## 5. Question Lifecycle

Each question follows this sequence:

| Status | Description |
|---|---|
| WAITING | Waiting for the next question |
| QUESTION_ACTIVE | All eligible players can buzz |
| ANSWERING | A player has won the buzzer |
| ANSWER_RESULT | Server validates the answer |
| QUESTION_FINISHED | Question is completed |
| NEXT_QUESTION | Reset state and load another question |

---

## 6. Player Answering Rules

| Situation | System Behavior |
|---|---|
| New question | Unlock all players |
| First player buzzes | Reserve answering opportunity |
| Correct answer | Award points |
| Incorrect answer | Eliminate player from this question |
| Another player buzzes | Give that player an opportunity |
| All players incorrect | Reveal correct answer |
| Timer expires | End question |
| Next question | Reset player eligibility |

A player who answers incorrectly cannot buzz again for the same question, but can participate in the next question.

---

## 7. Scoring System

Suggested scoring:

| Action | Points |
|---|---:|
| Correct answer | +100 |
| Incorrect answer | -20 |
| Correct answer in bonus round | +200 |
| No answer | 0 |

All scoring must be calculated on the Node.js server.

---

## 8. Question Bank (JSON)

Questions will be stored in a JSON file instead of a database.

File: `server/data/questions.json`

```json
[
  {
    "id": 1,
    "question": "What has keys but cannot open locks?",
    "choices": [
      "Door",
      "Keyboard",
      "Car",
      "Box"
    ],
    "correctAnswer": "Keyboard",
    "difficulty": "hard",
    "category": "Logic"
  },
  {
    "id": 2,
    "question": "Which planet has the shortest day?",
    "choices": [
      "Mars",
      "Jupiter",
      "Venus",
      "Mercury"
    ],
    "correctAnswer": "Jupiter",
    "difficulty": "hard",
    "category": "Science"
  }
]
```

### Question Features

- Random question selection.
- Multiple-choice questions.
- Four choices per question.
- Difficulty levels: Easy, Medium, Hard, Expert.
- Categories: Science, Mathematics, History, Logic, Bible, General Knowledge.
- Avoid repeating questions within the same game.
- Correct answers must only be accessible to the server.

---

## 9. In-Memory Game Management

No database is required to manage active game rooms.

File: `server/rooms.js`

```javascript
const rooms = {};

function createRoom(roomId) {
  rooms[roomId] = {
    roomId,

    players: [],

    currentQuestion: null,

    eligiblePlayers: [],

    answeredPlayers: [],

    currentAnsweringPlayer: null,

    scores: {},

    status: "waiting",

    timer: 20
  };

  return rooms[roomId];
}

module.exports = {
  rooms,
  createRoom
};
```

Each room maintains its own:

- Players
- Current question
- Buzzer eligibility
- Answering player
- Scores
- Game status
- Timer

Rooms are stored in Node.js memory.

---

## 10. First-to-Buzz Server Logic

The Node.js server determines who successfully buzzed first.

File: `server/events/gameEvents.js`

```javascript
socket.on("buzz", ({ roomId }) => {

  const game = rooms[roomId];

  if (!game) return;

  if (game.status !== "question_active") {
    return;
  }

  const playerId = socket.data.playerId;

  if (!game.eligiblePlayers.includes(playerId)) {
    return;
  }

  // First valid player gets the opportunity.
  game.currentAnsweringPlayer = playerId;

  game.status = "answering";

  io.to(roomId).emit("player_buzzed", {
    playerId
  });

});
```

For production, protect this operation with atomic locking when multiple server instances are used.

---

## 11. Submit Answer Logic

The server validates the player's selected answer.

```javascript
socket.on("submit_answer", ({ roomId, answer }) => {

  const game = rooms[roomId];

  if (!game) return;

  if (game.status !== "answering") return;

  const playerId = socket.data.playerId;

  if (game.currentAnsweringPlayer !== playerId) {
    return;
  }

  const isCorrect =
    answer === game.currentQuestion.correctAnswer;

  if (isCorrect) {

    game.scores[playerId] += 100;

    game.status = "question_finished";

    io.to(roomId).emit("answer_result", {
      playerId,
      isCorrect: true,
      scores: game.scores
    });

    return;
  }

  game.scores[playerId] -= 20;

  game.answeredPlayers.push(playerId);

  game.eligiblePlayers =
    game.eligiblePlayers.filter(
      id => id !== playerId
    );

  game.currentAnsweringPlayer = null;

  if (game.eligiblePlayers.length === 0) {

    game.status = "question_finished";

    io.to(roomId).emit("answer_result", {
      playerId,
      isCorrect: false,
      correctAnswer: game.currentQuestion.correctAnswer,
      scores: game.scores
    });

    return;
  }

  game.status = "question_active";

  io.to(roomId).emit("answer_result", {
    playerId,
    isCorrect: false,
    scores: game.scores
  });

});
```

This is simplified example code. Production implementation must also validate the answer against the question's choices, use authenticated room membership, prevent duplicate submissions, and handle timeouts and disconnections.

---

## 12. Reset State for Every New Question

Every new question starts with all active players eligible to buzz.

```javascript
function startNextQuestion(game, question) {

  game.currentQuestion = question;

  game.eligiblePlayers =
    game.players
      .filter(player => player.connected)
      .map(player => player.id);

  game.answeredPlayers = [];

  game.currentAnsweringPlayer = null;

  game.status = "question_active";

  game.timer = 20;

}
```

This guarantees that players eliminated from the previous question can participate again.

---

## 13. Socket.IO Events

| Event | Direction | Purpose |
|---|---|---|
| join_room | Client → Server | Join game room |
| player_joined | Server → Client | Notify players |
| start_game | Client → Server | Request game start |
| new_question | Server → Client | Broadcast question |
| buzz | Client → Server | Request answering opportunity |
| player_buzzed | Server → Client | Announce first player |
| submit_answer | Client → Server | Submit selected answer |
| answer_result | Server → Client | Broadcast result |
| timer_update | Server → Client | Synchronize timer |
| leaderboard_update | Server → Client | Broadcast scores |
| game_finished | Server → Client | Announce winner |

---

## 14. Game Timer

The Node.js server controls the timer.

Suggested settings:

- 20 seconds per question.
- 10 seconds for the answering player.
- Timer starts when the question is activated.
- Timer pauses or ends according to the selected game rules.
- Server broadcasts timer updates.
- When time expires, the question ends or the answering opportunity is released, depending on the current state.

The ReactJS countdown is only a visual representation. The server is authoritative.

---

## 15. Additional Game Modes

The application can support:

- **Solo Mode:** Answer random questions and beat your own score.
- **Multiplayer Mode:** Compete against other players.
- **First-to-Buzz Mode:** First player to buzz gets the opportunity to answer.
- **Simultaneous Mode:** All players answer independently.
- **Survival Mode:** Continue until you answer incorrectly.
- **Bonus Round:** Special questions with double points.
- **Team Battle:** Players compete in teams.

---

## 16. Important Development Rules

1. The Node.js server controls the entire game state.
2. The server determines the first valid buzzer.
3. Never trust scores submitted by ReactJS.
4. Never expose correct answers before validation.
5. Reset buzzer eligibility for every new question.
6. Prevent players from submitting multiple answers.
7. Synchronize timers through the server.
8. Validate player membership for every game event.
9. Handle network disconnections and reconnections.
10. Prevent room codes from being duplicated.
11. Remove inactive rooms after a specified period.
12. Avoid repeating questions within a game.

---

## 17. Database-Free Architecture: Limitations

| Feature | Supported |
|---|---|
| Create game room | Yes |
| Join using room code | Yes |
| First-to-buzz | Yes |
| Live leaderboard | Yes |
| Random questions | Yes |
| Multiple-choice questions | Yes |
| Player accounts | No |
| Permanent game history | No |
| Persistent scores | No |
| Recover games after server restart | No |

### Important Considerations

- Active game data exists only in Node.js memory.
- A server restart removes all active game rooms and scores.
- JSON question files remain available after server restarts.
- Use a room cleanup mechanism to remove inactive rooms.
- For a single Node.js server, in-memory game state is sufficient.
- If multiple Node.js instances are introduced later, shared state or a message adapter will be needed.

---

## 18. Recommended Initial Development Scope

Build the first version with:

- 3–10 players per room.
- Room code generation.
- Join room without login.
- Random multiple-choice questions.
- 20-second question timer.
- First-to-Buzz functionality.
- Incorrect answer elimination per question.
- Automatic buzzer reset.
- Live scoring.
- Real-time leaderboard.
- Final winner announcement.
- Database-free game management.

### Core Principle

Every new question starts with all active players eligible to buzz.

The first player gets the opportunity to answer. If incorrect, the remaining eligible players can buzz again. The process repeats until someone answers correctly or everyone fails.

**Initial Architecture: ReactJS + Node.js + Socket.IO + JSON + In-Memory Game State. No database required.**