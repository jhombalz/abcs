BUTBUTAY
Multiplayer Card Game – Development Guide

Version: 1.0
Platform: Android and iOS
Frontend: Flutter
Backend: Node.js + Express
Real-time Communication: Socket.IO
Database: PostgreSQL

1. Project Overview

Butbutay is a real-time multiplayer bluffing card game.

Players receive cards from a standard 52-card deck. During their turn, a player drops cards face down and declares a quantity and rank, such as "4 Kings."

Other players can challenge the declaration by calling "LIE."

The server secretly validates the dropped cards and determines who picks up the cards and who gets the next turn.

The objective is to be the first player to empty their hand.

2. Official Game Rules
2.1 Game Setup
Minimum players: 3.
Initial recommended maximum: 6.
Deck: Standard 52 playing cards.
Jokers: Not allowed.
Cards are shuffled randomly.
All cards are distributed as equally as possible.
Remaining cards are distributed one at a time.
First player is randomly selected.
Turn direction is clockwise.
2.2 Card Distribution

All 52 cards must be distributed.

Examples:

Players	Distribution
3	18, 17, 17
4	13, 13, 13, 13
5	11, 11, 10, 10, 10
6	9, 9, 9, 9, 8, 8
2.3 Playing a Turn
The current player selects cards from their hand.
The player drops the selected cards face down.
The player declares a quantity and rank.
Other players can decide whether to call LIE.
Only the first valid LIE challenge is accepted.
If nobody calls LIE, the cards are accepted into the hidden discard pile.
The same player gets another drop.
The player can declare a different quantity and rank on the next drop.

Examples of declarations:

4 Kings
3 Queens
2 Aces
1 Jack

The declared quantity must match the number of cards dropped.

2.4 Declaration Validation

A declaration is TRUE only when every dropped card has the declared rank.

Examples:

TRUE:

King of Hearts
King of Diamonds
King of Clubs
King of Spades

Declaration: 4 Kings.

LIE:

King of Hearts
King of Diamonds
Queen of Hearts
King of Spades

Declaration: 4 Kings.

The server validates the actual cards.

Players cannot see the dropped cards until someone calls LIE.

2.5 LIE Challenge

Any player other than the dropper can call LIE.

Only the first valid challenge is accepted.

Scenario A: Successful LIE Challenge
Player 1 drops four cards.
Player 1 declares 4 Kings.
Player 2 calls LIE.
The server reveals the dropped cards.
The declaration is determined to be false.
Player 1 picks up all four dropped cards.
Player 2 gets the next turn.
Scenario B: Incorrect LIE Challenge
Player 1 drops four cards.
Player 1 declares 4 Kings.
Player 2 calls LIE.
The server reveals the dropped cards.
All four cards are Kings.
Player 2 picks up all four dropped cards.
Player 1 gets another turn.
Scenario C: Nobody Calls LIE
Player 1 drops four cards.
Player 1 declares 4 Kings.
Nobody calls LIE.
The cards remain in the hidden discard pile.
Player 1 gets another drop.
Player 1 can declare a new quantity and rank.
3. Player Information and Visibility

Information security is important because Butbutay depends on hidden cards and bluffing.

Information	Visible to players?
Own cards	Yes
Other players' cards	No
Current declaration	Yes
Current dropped cards	No
Previous discarded cards	No
Previous declarations	Yes
Challenge result	Yes
Other players' card counts	Yes
Information Rules

Players can only use their own cards to decide whether to call LIE.

They cannot inspect other players' hands.

Previously discarded cards remain hidden and are excluded from player knowledge.

The server maintains the actual game state and validates every declaration.

4. Game Flow
text
CREATE ROOM
    |
JOIN ROOM
    |
WAIT FOR 3+ PLAYERS
    |
HOST STARTS GAME
    |
SHUFFLE 52 CARDS
    |
DISTRIBUTE CARDS
    |
RANDOMIZE FIRST PLAYER
    |
PLAYER SELECTS CARDS
    |
DECLARE QUANTITY AND RANK
    |
WAIT FOR LIE CHALLENGE
    |
    +-------------------------+
    |                         |
 NOBODY CHALLENGES       SOMEONE CALLS LIE
    |                         |
 ACCEPT DROP              REVEAL CARDS
    |                         |
 SAME PLAYER             VALIDATE DECLARATION
 DROPS AGAIN                   |
                         +-----+-----+
                         |           |
                       TRUE        FALSE
                         |           |
                    CHALLENGER    DROPPER
                     PICKS UP     PICKS UP
                         |           |
                    DROPPER      CHALLENGER
                    CONTINUES    PLAYS NEXT
                         |           |
                         +-----+-----+
                               |
                         CHECK WINNER
                               |
                         GAME CONTINUES

5. Technology Stack
Frontend

Flutter

Responsibilities:

Mobile user interface.
Login or guest entry.
Room creation and joining.
Player lobby.
Card selection.
Declaration interface.
LIE challenge button.
Game animations.
Game results.

Recommended packages:

socket_io_client – Real-time communication.
flutter_riverpod – State management.
go_router – Navigation.
shared_preferences – Local preferences.
audioplayers – Game sound effects.
Backend

Node.js + Express + Socket.IO

Responsibilities:

Room management.
Player management.
Card shuffling.
Card distribution.
Game state management.
Declaration validation.
LIE challenge resolution.
Turn management.
Winner detection.
Database

PostgreSQL

Suggested database records:

Users
Player profiles
Game rooms
Match history
Match participants
Player statistics

Active game state should be maintained by the backend and persisted appropriately for reconnection and recovery.

6. Recommended Project Structure
Flutter Frontend
text
butbutay/
├── lib/
│   ├── main.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── theme/
│   │   └── socket/
│   │       └── socket_service.dart
│   │
│   ├── models/
│   │   ├── player.dart
│   │   ├── playing_card.dart
│   │   ├── game_room.dart
│   │   └── game_state.dart
│   │
│   ├── services/
│   │   ├── game_service.dart
│   │   └── room_service.dart
│   │
│   ├── providers/
│   │   ├── game_provider.dart
│   │   └── room_provider.dart
│   │
│   ├── screens/
│   │   ├── home/
│   │   ├── lobby/
│   │   ├── waiting_room/
│   │   └── game/
│   │
│   └── widgets/
│       ├── playing_card_widget.dart
│       ├── player_seat.dart
│       ├── challenge_button.dart
│       └── declaration_selector.dart
│
└── pubspec.yaml

Node.js Backend
text
butbutay-server/
├── src/
│   ├── server.js
│   │
│   ├── socket/
│   │   ├── socket_handler.js
│   │   └── game_events.js
│   │
│   ├── game/
│   │   ├── game_engine.js
│   │   ├── deck.js
│   │   ├── card_validator.js
│   │   ├── turn_manager.js
│   │   └── challenge_manager.js
│   │
│   ├── rooms/
│   │   └── room_manager.js
│   │
│   ├── database/
│   │   └── database.js
│   │
│   └── models/
│
├── package.json
└── .env

7. Socket.IO Event Specification

The following events establish communication between Flutter and Node.js.

Event	Direction	Description
room:create	Client → Server	Create a room
room:join	Client → Server	Join a room
room:state	Server → Client	Update room information
game:start	Client → Server	Request game start
game:started	Server → Client	Notify game start
game:my_hand	Server → Client	Send private cards
game:drop	Client → Server	Submit selected cards
game:drop_update	Server → Client	Broadcast declaration
game:call_lie	Client → Server	Challenge a drop
game:challenge_result	Server → Client	Reveal challenge result
game:turn_update	Server → Client	Update current turn
game:my_hand_update	Server → Client	Update private hand
game:state	Server → Client	Update public game state
game:finished	Server → Client	Announce winner
player:reconnect	Client → Server	Restore player session

All client actions must be validated by the server.

Private card information must only be sent to the owning player.

8. Backend Game Engine
8.1 Deck Generator

Generate 52 unique cards.

Four suits:

Hearts
Diamonds
Clubs
Spades

Thirteen ranks:

Ace
2 through 10
Jack
Queen
King
8.2 Shuffle and Distribution

Use a secure server-side random generator.

Shuffle the deck and distribute cards one at a time to players in clockwise order.

8.3 Card Declaration Validator

Example:

javascript
function isDeclarationTrue(cards, declaredRank) {
  return cards.every(
    card => card.rank === declaredRank
  );
}


The validator must check:

The player owns every selected card.
The selected cards are unique.
At least one card is selected.
The declared quantity matches the selected card count.
The declared rank is valid.
8.4 Challenge Manager

Responsibilities:

Verify that the current drop is waiting for a challenge.
Verify that the challenger is a valid player.
Reject the dropper's own challenge.
Accept only the first valid challenge.
Reveal the cards.
Validate the declaration.
Assign the cards to the correct player.
Update the next player.
Check for a winner.
Broadcast the result.

Challenge resolution must be atomic to prevent two simultaneous LIE calls from both being accepted.

8.5 Turn Manager

The turn manager handles:

Random first player.
Clockwise turn order.
Repeated drops by the same player.
Successful challenge transitions.
Incorrect challenge transitions.
Winner detection.
9. Game State Design

The backend should maintain two separate representations.

Internal Game State

Only the server can access this information.

json
{
  "roomId": "BUT123",
  "currentPlayerId": "PLAYER1",
  "gameStatus": "ACTIVE",
  "players": [
    {
      "id": "PLAYER1",
      "hand": ["KH", "KD", "QC", "JS"]
    },
    {
      "id": "PLAYER2",
      "hand": ["KC", "KS", "7H"]
    }
  ],
  "currentDrop": {
    "dropId": "DROP001",
    "playerId": "PLAYER1",
    "cards": ["KH", "KD", "QC"],
    "declaredQuantity": 3,
    "declaredRank": "KING",
    "status": "WAITING_FOR_CHALLENGE"
  }
}

Public Game State

This information can be broadcast to all players.

json
{
  "roomId": "BUT123",
  "currentPlayerId": "PLAYER1",
  "gameStatus": "ACTIVE",
  "players": [
    {
      "id": "PLAYER1",
      "cardCount": 4
    },
    {
      "id": "PLAYER2",
      "cardCount": 3
    }
  ],
  "currentDrop": {
    "dropId": "DROP001",
    "playerId": "PLAYER1",
    "declaredQuantity": 3,
    "declaredRank": "KING",
    "status": "WAITING_FOR_CHALLENGE"
  }
}


Never expose actual card identities through public game state.

10. Flutter UI Screens
Screen 1: Home
Create Game
Join Game
Player Profile
Game History
Settings
Screen 2: Create Room
Player name
Room name
Maximum players
Create button
Screen 3: Join Room
Enter room code
Join button
Screen 4: Waiting Room
Room code
List of players
Player ready status
Host start button
Minimum three players validation
Screen 5: Game Table

Display:

Other players' names.
Other players' card counts.
Current player indicator.
Current declaration.
Hidden dropped cards.
Challenge timer, if enabled.
CALL LIE button.
Screen 6: Player Hand
Display private cards.
Select multiple cards.
Confirm selected cards.
Select declared rank.
Submit drop.
Screen 7: Challenge Result
Reveal dropped cards.
Display TRUE or LIE.
Display who picked up the cards.
Display next player.
Screen 8: Game Results
Winner announcement.
Final player standings.
Rematch button.
Return to lobby.
11. Security Requirements

Security is critical because players have hidden cards.

Requirements:

The backend must be authoritative.
Never trust card selections without validating ownership.
Never send private hands to other players.
Never expose hidden discard cards.
Validate all Socket.IO events.
Prevent duplicate challenges.
Reject actions outside the current game phase.
Use authenticated player sessions.
Validate room membership.
Rate-limit sensitive actions.
Use secure random shuffling.
Protect against replayed or duplicated game actions.
12. Edge Cases
Scenario	Expected behavior
Fewer than 3 players	Cannot start
More than room capacity	Reject joining
Invalid card selection	Reject
Player drops cards they do not own	Reject
Incorrect declared quantity	Reject
Invalid rank	Reject
Dropper calls LIE	Reject
Multiple simultaneous challenges	Accept first valid challenge
No challenge	Accept drop
Player disconnects	Preserve game state
Player reconnects	Restore private hand and game state
Player empties hand	Check pending challenge before winning
Winner detected	Finish match
13. Development Roadmap
Phase 1 – Backend Foundation
Initialize Node.js project.
Configure Express and Socket.IO.
Implement card deck generator.
Implement secure shuffle.
Implement card distribution.
Implement player and room management.
Phase 2 – Game Engine
Implement card selection validation.
Implement declaration validation.
Implement hidden discard pile.
Implement LIE challenge logic.
Implement card pickup.
Implement turn management.
Implement winner detection.
Phase 3 – Multiplayer
Create rooms.
Join rooms.
Manage player readiness.
Start games.
Synchronize game state.
Handle player disconnections.
Handle reconnections.
Phase 4 – Flutter Application
Build home screen.
Build lobby.
Build waiting room.
Build game table.
Build playing card widgets.
Build card selection.
Build declaration selector.
Build LIE challenge interaction.
Build results screen.
Phase 5 – Testing

Test with 3–6 players.

Test cases:

Correct declaration.
Incorrect declaration.
Successful LIE challenge.
Incorrect LIE challenge.
No challenge.
Multiple consecutive drops.
Simultaneous LIE challenges.
Player disconnects.
Player reconnects.
Player wins.
Phase 6 – Deployment
Deploy Node.js backend.
Configure PostgreSQL.
Configure production Socket.IO.
Configure HTTPS and secure WebSocket connections.
Build Android application.
Build iOS application.
Conduct multiplayer testing.
14. Recommended Development Settings
Setting	Recommended value
Minimum players	3
Maximum players	6 initially
Deck size	52
Jokers	Disabled
Turn direction	Clockwise
Challenge timer	7 seconds, configurable
Room code	6 characters
State management	Riverpod
Backend	Node.js
Communication	Socket.IO
Database	PostgreSQL

The maximum number of cards per drop and the final challenge timeout behavior should remain configurable until confirmed.

15. Important Implementation Principle

The game engine must be implemented before the complete Flutter interface.

The backend is responsible for:

Knowing all cards.
Knowing every player's hand.
Validating declarations.
Resolving challenges.
Assigning picked-up cards.
Controlling turns.
Determining the winner.

Flutter is responsible for:

Displaying the game.
Showing the player's own cards.
Sending player actions.
Receiving real-time updates.
Displaying animations and results.

Never let Flutter determine whether a declaration is true or false. The server must make that decision.

16. Definition of Done

The first version of Butbutay is considered complete when:

Players can create and join rooms.
At least three players can start a game.
All 52 cards are distributed correctly.
First player is randomly selected.
Players can drop multiple cards.
Players can declare quantity and rank.
Other players can call LIE.
Only the first valid challenge is accepted.
The server correctly validates declarations.
Correct and incorrect challenges apply the proper penalties.
Unchallenged drops allow the same player to continue.
Hidden cards remain private.
Game state synchronizes in real time.
The first eligible player to empty their hand wins.
Players can reconnect without losing their game state.

Final Project Goal: Deliver a secure, real-time multiplayer Butbutay card game for Android and iOS using Flutter, Node.js, Socket.IO, and PostgreSQL.