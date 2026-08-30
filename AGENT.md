# Agent Instructions for Metropolis-Project-City-Builder

## Overview
Metropolis is a task/project tracker skinned as an visually stunning and realistic city-builder
game. Each task or project becomes a specific type of building on a specific section of terrain/land. (playing area) the terrain/playing area is under-layed by a grid system that appears as an overlay when selecting any area/point on the land, or when creating a project or task, or when moving buildings around. each building, road etc takes up minimum one space or slot. for larger buildings etc they may take up more then one space. the landscape, an terrain is not flat but has hills, maybe some mountains, valleys, waterways, forests, etc. normal rules would apply (where buildings etc can be placed according to the type of terrain.) when 1st starting only a small area on the landscape is playable and as more tasks are created and less landscape is available the bigger the landscape gets and then as the player/user completes tasks/buildings every so many levels, or points it unlocks the playing area size (the total playing area expands/playing area gets bigger an bigger as you progress, unlock it or level up. 
As you make real-world progress on a task, its building visibly grows through various
construction stages; completing task then completes/finishes the construction of the building. XP and a
level/badge system reward real effort with cosmetic unlocks (new building
styles, decorative extras) — never with gameplay-mechanic changes. no failure state, and no time pressure beyond a purely visual
overdue marker. The goal is a lightweight app that makes real task-tracking
feel visually rewarding without becoming stressful.
Design and implement a "tasks, and projects tracker app as the essential, main overall point of the app/the 2nd point is the unique and central focal point of the app and its core aspects is the visually stunning landscape and the intricate detailed buildings that eventually develop into a complete developed city the more tasks are completed over time. 
The app/games main menu/main UI screens focal point is of the large stunning landscape with some slight rolling hills, trees, shrubs, maybe some rock formations, rivers, lakes etc laid throughout  the landscapes. landscape should have some depth and texture. any app icons would overlay on any of the outer edges of the screen.  The visual style should be  animated realistic style art and building animations, building destruction animations, and building completion animations and any character, landscape scenery, layout, or character animations. the main purpose of the app is to track projects an tasks etc. the user opens the app, the app opens to the main ui screen which is of the open view of the landscape. the user can scroll around using his fingers,  or zoom in or farther out to get a wider overall view of the landscape. everytime the user touches the landscape a grid that under-lays the land appears then dissappears after a certain amount of time if no further actions are taken. the grid is a 1 by 1 square that spans all the way across horizontally and vertically  covering the entire landscape. if the user selects an area on the landscape the user will be on that specific grid area and by pressing on that specific spot along with the grid appearing a create a task or project option appears by selecting the create a task or project option, several more options appear such as task name, date, description of task and all the normal task options can be filled out here. if the user then wants to finish and create the task he presses the confirm create task  button  (task or project equals 1 building basically) basically you the user will select an area on the land and then input the task or project details for whatever you are tracking and by selecting confirm on create task will start a building being built by tiny villagers.  depending on the length of the project or task and your experience level will define the type of building and how long it'll take to complete (so you can't jus create and finish a task just to build a building) the more projects an tasks you have and completed without any issues the more variety of buildings you'll have or be able to unlock as you go and the bigger your city or village or town will become. Metropolis is a task/project tracker skinned as an isometric city-builder game. Each task or project becomes a specific type of building on a specific section of terrain/land. (playing area) the terrain/playing area is overlayed by a fixed grid system that appears as an overlay when selecting a specific area when creating a project or task, or when moving buildings around. each building, road etc takes up minimum one grid space or slot. for larger buildings etc they may take up more then one grid space. the task map/playing field terrain isnt flat but has hills, mountains, valleys, waterways, forests, etc so normal rules would apply (where buildings etc can be placed according to the terrain.) when first starting out maybe the app starts by creating a random or pre-made/pre-fixed terrain, scenery etc, The whole land area could take up about 50x50 on smaller side or 100x100 plus grid squares. an idea is for when 1st starting out that maybe the new user only gets to use a certain amount like a 5x5 grid as starting point instead of having the whole land available right-away and then as the player/user completes tasks/buildings every so many levels, or points it unlocks the playing area size (the grid expands/playing area gets bigger an bigger as you progress, unlock it or level up. As you make real-world progress on a task, its building visibly grows through construction stages; completing it completes/finishes the building. XP and a level/badge system reward real effort with cosmetic unlocks (new building styles, decorative extras) — never with gameplay-mechanic changes. no failure state, and no time pressure beyond a purely visual overdue marker. The goal is a lightweight app that makes real task-tracking feel visually rewarding without becoming stressful.
Deliverables include app and gameplay design, core code structure, basic asset plan, and a runnable simple demo. the repository address is  and read an follow AGENTS.md file 


## Project Structure
- `state.js` — task data model + `localStorage` persistence (CRUD only, no
  calculation logic)
- `progress.js` — pure functions that turn task data into visual state:
  `getProgressIncrement`, `getVisualStage`, `getBuildingHeight`,
  `advanceProgress`, `getXPReward`, `isOverdue`
- `index.html` — app shell; loads `state.js` then `progress.js` then future
  UI/render scripts via plain `<script>` tags, in that order
- `base.css` — resets, typography, page layout
- `isometric.css` — the world's isometric tilt and cube-face styling for
  buildings and grid tiles
- `ui.css` — HUD elements: XP bar, level badge, "add task" modal
- `AGENT.md` — this file
- `TASKS.md` — build-order backlog

## Code Style & Conventions

## Rules & Constraints

## Development Workflow


## Testing Requirements


## Key Patterns to Follow


## Things to Avoid

## Integration Points

## Performance Considerations

## Security Considerations

