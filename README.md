# Buzz Club - Flutter + FAAS API

A multiplayer quiz for 1-10 players, including solo play. Enter a name, press OK, then create or join a room. Matches use 10 random questions, 15 seconds to buzz, 15 seconds to answer, and +100 for correct answers. Wrong answers and timeouts earn 0. Correct answers are never revealed.

## Start the API

The backend lives in C:/xampp/htdocs/iconcepts/faas-automation/api/abcs-game and is attached from the API's server.js with require("./abcs-game")(http, app). It shares the existing API server, with default port 8099.

```powershell
cd C:\xampp\htdocs\iconcepts\faas-automation\api
npm.cmd start
```

The API needs its usual environment/database configuration. From the abcs root, npm.cmd run dev also delegates to the API's start script. Nodemon reloads after backend changes; a restart discards active rooms.

Health: http://localhost:8099/abcs-game/health returns {"ok":true,"service":"abcs-game"}.

## Start Flutter web

```powershell
cd C:\xampp\htdocs\me\abcs\client
& "C:\xampp\htdocs\me\selah\.tools\flutter\bin\flutter.bat" pub get
& "C:\xampp\htdocs\me\selah\.tools\flutter\bin\flutter.bat" run -d web-server --web-hostname localhost --web-port 5173 --dart-define=SERVER_URL=http://localhost:8099
```

Open http://localhost:5173 manually. Restart Flutter fully after adding audio dependencies; refreshing an old compiled client is insufficient. Replace any old SERVER_URL override using port 3001 with 8099.

## Phase 3 experience

- Name first: enter a display name and press OK before room actions appear.
- Host chooses Mixed, English, or Mathematics in the lobby; everyone sees the same subject. Every match stays at 10 random questions. Difficulty filtering is unavailable because the banks have no ratings.
- The host can start with 1-10 players. Invite others before starting; joining during a match is blocked.
- The active match centers the question, choices and buzzer in a focused column with a single timer bar. Standings and Room & controls are collapsed by default; expand them to view scores, room details, keyboard help or Leave room. Sections keep their state during timer updates. Final standings are always visible on the results screen.
- Buzz using the button, Space, or B while the quiz has keyboard focus. During your answer turn, use the buttons or number keys 1-4. Tab/Enter work with standard controls. Repeated held keys are ignored.
- Both timers start at 15 seconds. Buzz time pauses during an answer turn, then resumes with the unused time if the player is wrong or times out. That player is ineligible until the next question.
- Correct answers earn +100. Wrong answers/timeouts earn 0. Only outcomes and scores are shown; correct choices and hints are never sent to clients.
- Four seconds between questions; ten rounds finish the match. Standings use tied ranks, and results include all tied winners.
- Host can Play again with the same subject, or Back to lobby to keep the room code and players, reset scores, change subject, and invite additional players. Guests follow the host's transition automatically.
- Sound is muted by default. Use the speaker button to enable/mute short cues for new questions, buzzes, points, and match completion. The setting lasts for the page session. Browser/device audio restrictions may prevent playback; visual feedback always remains available.
- Keyboard focus, live announcements for turn/outcome changes, readable disabled choices, large touch controls, text scaling, and reduced-motion support are included. Actual screen-reader/audio device checks remain manual.

## Question banks

The backend loads data/eng-q-100.json and data/math-q-100.json (100 entries each). Mixed draws from all 200 with a random subject split. English and Mathematics draw only from their respective files. Every match samples 10 unique items; later matches can reuse questions. Source letter answer keys are mapped to option text; duplicate numeric IDs across subjects are handled separately. The old questions.json starter bank is not loaded. Restart the API after editing banks.

## Configuration and mobile

- API PORT defaults to 8099.
- ABCS_CLIENT_ORIGINS is a comma-separated list of browser origins for Socket.IO; default http://localhost:5173.
- Flutter SERVER_URL is a compile-time setting passed with --dart-define. Use the backend origin without /abcs-game appended; the socket path is /socket.io.

Android emulator: SERVER_URL=http://10.0.2.2:8099. Physical phones: use the API computer's LAN IP and permit port 8099 in the firewall. Release builds should use your actual HTTPS API URL. iOS builds require macOS/Xcode. Proxy/IIS hosting must forward /socket.io requests and WebSocket upgrades. One Node process owns in-memory rooms; restarts discard them. Disconnects remove players immediately; reconnection recovery is Phase 4.

## Checks

From the abcs root: npm.cmd test runs the backend engine tests.
From client: flutter analyze, flutter test, flutter build web.
With API running, from client:

```sh
dart run tool/check_rooms.dart http://localhost:8099
dart run tool/check_phase3.dart http://localhost:8099
```

The Phase 3 check creates its own room and plays ten rounds, then verifies lobby return, a new join, and a Mathematics rematch. It takes about 45 seconds plus first-run Dart dependency hooks. Audio WAV assets are generated by tools/generate-sounds.ps1 without external downloads.

Verification: 16 backend tests, 7 Flutter widget tests, static analysis and standard JavaScript web build passed. The full-match Socket.IO check passed against an isolated Express/HTTP server loading the actual backend module. Manual browser, audio, screen-reader and mobile device acceptance remains pending. The full FAAS API/database routes were not exercised. Dependency Wasm dry-run warnings remain; standard JavaScript web output is supported.

See DEVELOPMENT.md for remaining phases. guide.md is the original brief; subsequent user decisions supersede it.

## GitHub Pages

Repository: https://github.com/jhombalz/abcs
Frontend: https://jhombalz.github.io/abcs/
Production backend: https://api.iconcept-faas.lguapp.com

.github/workflows/pages.yml builds and tests the Flutter client using pinned Flutter 3.47.9, sets base href /abcs/ and SERVER_URL to the HTTPS API, then publishes via GitHub Actions. Pushes to main deploy automatically; workflow_dispatch allows manual deployment. GitHub repository Settings > Pages must use GitHub Actions as its source. Release clients also default to the HTTPS API when no SERVER_URL override is supplied; local debug builds still default to port 8099.

Manual production build from client:

```sh
flutter build web --release --base-href /abcs/ --dart-define=SERVER_URL=https://api.iconcept-faas.lguapp.com
```

The Node backend is intentionally maintained in the separate FAAS API checkout. Root npm commands and backend smoke tests require that local sibling checkout; the Pages CI runs only Flutter checks. This repository does not publish the API server or question-bank answers as web assets.

The API's server.js and abcs-game/index.js allow the Pages origin https://jhombalz.github.io (without /abcs/). Deploy those updated files plus the complete abcs-game folder on the API host and restart its Node process. Ensure the reverse proxy forwards /socket.io/ and supports WebSocket upgrades. Check /abcs-game/health and /socket.io/?EIO=4&transport=polling on the public API; both must return successful responses. A Pages frontend deployment does not deploy the separate FAAS API.
