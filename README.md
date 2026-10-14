# Steal a Kaiju

A Roblox game about stealing kaiju eggs from guarded nests, hatching them into monsters that earn you money, and stealing from other players' pens.

Written in Luau in Roblox Studio. This repo holds the game's code. The UI (`StarterGui`) is left out, and so are the place file, models and assets.

## The game

- **The run:** one long canyon heads out from the hub. It crosses biome after biome: Pebble Plains, Lava Lagoon and Frostfang Peaks, with Venom Jungle, Sunken Abyss, Storm Spires and Cosmic Rift coming soon.
- **Eggs and guardians:** each biome has a nest of eggs guarded by a sleeping boss kaiju. Take an egg and the guardian wakes and chases you all the way back to the safe zone.
- **Hatching:** eggs come in seven rarities and four sizes. A bigger egg hatches a bigger kaiju that earns more.
- **Your kaiju:** they roam your pen and pay out every second. Feed them to level them up, or sell them.
- **Stealing:** hold E on someone else's egg or kaiju to steal it. Defenders can tackle a thief, and bases can be locked for a short time.
- **Getting faster:** personal treadmills raise your Speed, and trails come with their own auras.
- **The Kaiju Citadel:** the hub, with a fortress, a market and champion statues of the top players.

## Layout

Folders follow Roblox's services, Rojo-style:

| File | What it is |
|---|---|
| `Name.lua` | ModuleScript |
| `Name.server.lua` | Script |
| `Name.client.lua` | LocalScript |
| `Name/init*.lua` | a script that has child modules |

```
src/
  ReplicatedStorage/Shared/      config tables and shared utilities (both sides)
  ServerScriptService/
    Bootstrap.server.lua         starts every service
    Services/                    gameplay services (data, eggs, guardians, hatching, economy, stealing, ...)
    Lib/                         model builders and helpers (ProfileStore is vendored)
  ServerStorage/Tools/           edit-time builders: run from the Studio command bar, never at runtime
  StarterPlayer/StarterPlayerScripts/Gameplay/   client effects, animation and input
```

## Some interesting parts

- **`Tools/KaijuSculpt` + `Tools/KaijuSculptSpecs`:** procedural "sculpted voxel" monsters.
  - Each species is a `Build(K)` function that places blocks, tubes with shingled tiles, ridges, horns and claws onto a rig.
  - The builder merges and textures the result into an animated model.
- **`Tools/CanyonBuilder`:** builds each biome's canyon.
  - It generates terrain, rugged cliffs and landmarks, and a gate for each biome.
  - Locked biomes get a "Coming Soon" barrier at their gate.
  - One shared template (`NewBiome`) plus a theme module per biome.
- **`Tools/CitadelBuilder`:** the hub fortress, built procedurally around the plots and market without touching anything gameplay scripts reference.
- **`Services/GuardianService` + `Gameplay/KaijuFX`:** every thief gets a personal guardian.
  - Its run cycle is matched to stride, so the feet stay planted.
  - It roars when it wakes, banks into turns and snaps its jaws.
- **`Services/StealService`:** server-timed steals. The server checks the steal at the start, while the player holds E, and at delivery, and anti-teleport checks send stolen items home.
- **`Gameplay/WorldCuller` + `Tools/MapOptimizer`:** performance.
  - The client unloads distant map detail.
  - Hidden stud textures and tiny shadow casters are stripped at build time.

## Credits

- **Built by** Andy Nguyen with Claude (Anthropic's AI) as pair programmer. Those commits carry a `Co-Authored-By` trailer.
- **Teammates:** they built the UI, which isn't in this repo. They also built the weather, mutation, day/night, luck, rewards, pets, leaderboard, AFK and admin systems, which arrive in one commit authored to them.
- **ProfileStore** is by loleris (MAD STUDIO).

## History

Development happens in Roblox Studio, and this repo was set up partway through.

The commits before it existed were rebuilt from the development session logs and the versioned backups kept in the place. Each one is dated to when that change was made. A few changes whose exact order couldn't be recovered are grouped into neighbouring commits.

From the repo's creation on, every change is committed as it's made.
