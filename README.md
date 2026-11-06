# Love Game Jam 2026 B Side

## Game loop idea
Korean Webcomic Manhwa gate genre (action combat)

Pitch: Player goes gate diving for fruit, to make into jams which increase player stats.

Player has the lore class "Preserver", maybe mistaken for like survivor. Ability to enter a kitchen when outside of a gate. Some fruit collect from killing monsters (drops), some are by trees, some are still on trees/bushes (hit tree to drop them).

Environments:
- Player kitchen
- Simple one/two road Town/City (For moving to different Gates, and such)
- Dungeons
  - Forest
  - Cave
  - Desert (Stretch)

Timeline:
Day 1-3: Core gameplay - player combat, enemies (incl. art assets)
Day 3-4: Kitchen - Player can enter the kitchen conditionally
Day 4-6: Dungeons - Simple entrance, build them out - probably static, or we can make a few rooms that stick together
Day 7: City - Skyscrapers, camera on rail, Gate (dungeon entrance), crowds, cars
Day 8-10: Hope you're finished on time


##### archetypes

Player: Heavy stats + state machine + controller input + 2-Dir Renderer

Monster: Medium state + State machine + 2-Dir Renderer

NPC/Crowd: Minimal stats + Simple State machine (idle/walk) + Feeler/Flocking Logic + 4-Dir (or 2-Dir) Silhouette Renderer