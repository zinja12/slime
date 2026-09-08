# slime

## Engine
Continuing testing of small (corgispace) games with this engine called usagi. More a framework than an engine since we still have to write our own io, transitions, and other state. Documentation exists in the USGAGI.md file in this repo as well as at https://usagiengine.com/

## General Code Map
Everything is tied through main.lua. world.lua manages the tile map and provides indexing functions. player.lua manages the player and the slime growing and shrinking. undo.lua manages the undo stack and saving off / caching the room via functions that are used in the other files at appropriate steps.

## Getting Started
- Go to https://usagiengine.com/#install to install the engine / framework
- Clone repo down
- Navigate to repo
- run `usagi dev` from the command line
- NOTE: exporting executable files for various platforms can be done via `usagi export` and then navigating via file explorer to the repo to view the different builds

## Level Connections
Levels are built via json files mapping characters to tiles that the world.lua file loads and applies rules to. These levels have a connection dictionary node that tells the engine what level files exist on all sides. In order to add new levels, simply add a json file into the `data/` directory and then connect it into the correct neighbors of the adjacent rooms. 

## Todo
- Trying to build out a levels that makes use of the slime growing / shrinking mechanics. I want to make better use of making the player think about how to grow and shrink appropriately especially when breaking cracked tile blocks
- Need to add some sound effects and music