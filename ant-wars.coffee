
SENSE_FRIEND  = -1      # cell contains an ant of the same color
SENSE_FOE     = -2      # cell contains an ant of the other color
SENSE_FRIEND_FOOD = -3  # cell contains an ant of the same color carrying food
SENSE_FOE_FOOD = -4     # cell contains an ant of the other color carrying food
SENSE_FOOD = -5         # cell contains food (not being carried by an ant)
SENSE_ROCK = -6         # cell is rocky
SENSE_HOME = -7         # cell belongs to this ant's anthill
SENSE_FOE_HOME = -8     # cell belongs to the other anthill
SENSE_FOE_MARKER = -9   # cell is marked with *some* marker of the other color
# SENSE_ > 0            # cell is marked with a marker of this ant's color


DIR_RIGHT = 0
DIR_RIGHT_DOWN = 1
DIR_LEFT_DOWN = 2
DIR_LEFT = 3
DIR_LEFT_UP = 4
DIR_RIGHT_UP = 5


# Example Board:
#
#     # # # # # # # #
#      # . . . . . . #
#     # . - - . . . #
#      # . . . . . . #
#     # . . 5 5 . . #
#      # . . . . . . #
#     # . . . + + . #
#      # . . . . . . #
#     # # # # # # # #
newXY = (dir, x, y) ->
  switch dir
    when DIR_RIGHT      then [x+1,  y]
    when DIR_LEFT       then [x-1,  y]
    when DIR_RIGHT_DOWN then [x,    y+1]
    when DIR_LEFT_DOWN  then [x-1,  y+1]
    when DIR_RIGHT_UP   then [x+1,  y-1]
    when DIR_LEFT_UP    then [x,    y-1]
    else throw 'BUG: Invalid Direction!'

LEFT = -1
RIGHT = 1
AHEAD = 0

newDir = (dir, leftOrRight) ->
  switch leftOrRight
    when LEFT  then (dir+6 -1) % 6
    when RIGHT then (dir+6 +1) % 6
    when AHEAD then dir
    else throw 'BUG: Invalid Direction!'

class Instruction
  execute: (map, ant) -> throw 'BUG: Subclass must implement!'

# Go to state `st1` if `cond` holds in `sensedir` and to state st2 otherwise
class Sense extends Instruction
  constructor: (@sensedir, @st1, @st2, @cond) ->
  execute: (map, ant) ->
    [x, y] = newXY(newDir(ant.direction, @sensedir), ant.x, ant.y)
    found = switch @cond
      when SENSE_ROCK then map.getTileAt(x, y).isRock()
      when SENSE_FRIEND then map.getAntAt(x, y)?.isFriend(ant)
      when SENSE_FOE then map.getAntAt(x, y)?.isFoe(ant)
      when SENSE_FRIEND_FOOD then map.getAntAt(x, y)?.isFriend(ant).hasFood
      when SENSE_FOE_FOOD then map.getAntAt(x, y)?.isFoe(ant).hasFood
      when SENSE_FOOD then map.hasFood(x, y)
      when SENSE_HOME then map.getTileAt(x, y).isHomeAndMatches(ant)
      when SENSE_FOE_HOME then map.getTileAt(x, y).isHomeAndMatchesFoe(ant)
      when SENSE_FOE_MARKER then throw 'BUG: Unimplemented!' # map.getTileAt(x, y)
      else throw 'BUG: Unimplemented!'
    return @st1 if found
    return @st2 # Otherwise


# Set mark `i` in current cell and go to `st`.
class Mark extends Instruction
  constructor: (@i, @st) ->

# Clear mark `i` in current cell and go to `st`
class Unmark extends Instruction
  constructor: (@i, @st) ->

# Pick up food from current cell and go to `st1`;
# go to `st2` if there is no food in the current cell
class PickUp extends Instruction
  constructor: (@st1, @st2) ->
  execute: (map, ant) ->
    return @st2 if ant.hasFood

    pickedUp = map.pickupFood(ant.x, ant.y)
    if pickedUp
      ant.hasFood = true
      return @st1
    else
      return @st2

# Drop food in current cell and go to `st`
class Drop extends Instruction
  constructor: (@st) ->
  execute: (map, ant) ->
    if ant.hasFood
      map.dropFood(ant.x, ant.y)
      ant.hasFood = false
    return @st

# Turn left or right and go to `st`
class Turn extends Instruction
  constructor: (@lr, @st) ->
  execute: (map, ant) ->
    ant.direction = newDir(ant.direction, @lr)
    return @st

# Move forward and go to `st1`;
# go to `st2` if the cell ahead is blocked
class Move extends Instruction
  constructor: (@st1, @st2) ->
  execute: (map, ant) ->
    [x, y] = newXY(ant.direction, ant.x, ant.y)
    if map.isEmpty(x, y)
      map.moveAnt(ant, x, y)
      return @st1
    else
      return @st2

# Choose a random number x from 0 to p-1;
# go to `st1` if `x=0` and `st2` otherwise.
class Flip extends Instruction
  constructor: (@p, @st1, @st2) ->
  execute: (map, ant) ->
    switch Math.floor(Math.random() * 6)
      when 0 then @st1
      else @st2








class Tile
  constructor: (@x, @y, @char) ->
  toString: -> "#{@x}-#{@y}-#{@char}"
  getClasses: -> TILE_CLASSES[@char]

class MapTile extends Tile
  isRock: -> '#' == @char
  isHomeAndMatches: (ant) ->
    switch @char
      when '-' then ant.char == '-'
      when '+' then ant.char == '+'
      else false
  isHomeAndMatchesFoe: (ant) ->
    switch @char
      when '-' then ant.char == '+'
      when '+' then ant.char == '-'
      else false


NO_TILE = new MapTile(-1, -1, '?')

class Ant extends Tile
  id = 0
  constructor: (@x, @y, @char) ->
    @id = id++
    @programCounter = 0
    @direction = 0
    @hasFood = false
  getClasses: ->
    "#{ANT_CLASSES[@char]}#{if @hasFood then ' has-food' else ''}"
  toString: -> @id

class Map
  # Map of `#{x}-#{y}` to an Ant (or null)
  ants = {}
  # Map of `#{x}-#{y}` to a MapTile
  tiles = {}
  #
  food = {}

  addAnt: (ant) -> ants["#{ant.x}-#{ant.y}"] = ant
  addTile: (tile) -> tiles["#{tile.x}-#{tile.y}"] = tile
  isEmpty: (x, y) ->
    tile = tiles["#{x}-#{y}"]
    throw 'Invalid coords' if not tile
    return false if tile.isRock() #BLOCK
    # Check if there is already an ant
    return !ants["#{x}-#{y}"]

  hasFood: (x, y) -> food["#{x}-#{y}"]
  dropFood: (x, y, amount=1) ->
    count = food["#{x}-#{y}"] or 0
    # Decrement the amount of food
    food["#{x}-#{y}"] = count + amount
  pickupFood: (x, y) ->
    count = food["#{x}-#{y}"] or 0
    return false if not count

    # Decrement the amount of food
    food["#{x}-#{y}"] = count - 1
    return true


  moveAnt: (ant, x, y) ->
    delete ants["#{ant.x}-#{ant.y}"]
    ant.x = x
    ant.y = y
    ants["#{ant.x}-#{ant.y}"] = ant

  getTileAt: (x, y) ->
    return tiles["#{x}-#{y}"] or NO_TILE

  getTiles: -> d3.values(tiles)
  getAnts: -> d3.values(ants)
  getFoods: ->
    foods = []
    for tile in @getTiles()
      if @hasFood(tile.x, tile.y)
        foods.push new Tile(tile.x, tile.y, '@')
    return foods




RED_BRAIN = [
  new Sense(AHEAD, 1, 3, SENSE_FOOD) # state 0:  [SEARCH] is there food in front of me?
  new Move(2, 0)               # state 1:  YES: move onto food (return to state 0 on failure)
  new PickUp(8, 0)             # state 2:       pick up food and jump to state 8 (or 0 on failure)
  new Flip(3, 4, 5)            # state 3:  NO: choose whether to...
  new Turn(LEFT, 0)            # state 4:      turn left and return to state 0
  new Flip(2, 6, 7)            # state 5:      ...or...
  new Turn(RIGHT, 0)           # state 6:      turn right and return to state 0
  new Move(0, 3)               # state 7:      ...or move forward and return to state 0 (or 3 on failure)
  new Sense(AHEAD, 9, 11, SENSE_HOME) # state 8:  [GO HOME] is the cell in front of me my anthill?
  new Move(10, 8)              # state 9:  YES: move onto anthill
  new Drop(0)                  # state 10:     drop food and return to searching
  new Flip(3, 12, 13)          # state 11: NO: choose whether to...
  new Turn(LEFT, 8)            # state 12:     turn left and return to state 8
  new Flip(2, 14, 15)          # state 13:     ...or...
  new Turn(RIGHT, 8)           # state 14:     turn right and return to state 8
  new Move(8, 11)              # state 15:     ...or move forward and return to state 8
]



MAP = new Map()
window.MAP = MAP

update = (layer, data) ->
  grid = layer.selectAll('.hexagon').data(data, (p) ->
    p.toString()
  )

  grid # .transition()
    .attr('transform', (d) ->
      dx = RADIUS + d.x * RADIUS * 1.74
      dy = RADIUS + d.y * RADIUS * 1.5
      dx = dx + RADIUS * .9  unless d.y % 2 is 0
      return "translate(#{dx},#{dy})"
    )
    .attr 'class', (d) ->
      "hexagon #{d.getClasses()}"

  #FIXME: Why 1.74?

  #Shift odd rows

  #FIXME: Why .9?
  grid.enter()
    .append('path')
    .attr('d', hexagon(RADIUS))
    .attr('transform', (d) ->
      dx = RADIUS + d.x * RADIUS * 1.74
      dy = RADIUS + d.y * RADIUS * 1.5
      dx = dx + RADIUS * .9  unless d.y % 2 is 0
      return "translate(#{dx},#{dy})"
    )
    .attr 'class', (d) ->
      "hexagon #{d.getClasses()}"

  grid.exit().remove()

margin =
  top: 20
  right: 20
  bottom: 30
  left: 40

width = 960 - margin.left - margin.right
height = 500 - margin.top - margin.bottom
randomX = d3.random.normal(width / 2, 80)
randomY = d3.random.normal(height / 2, 80)
points = d3.range(2000).map(->
  [randomX(), randomY()]
)
RADIUS = 10

# Generates a hexagon path. From d3 hexbin
hexagon = (radius) ->
  hexAngles = d3.range(0, 2 * Math.PI, Math.PI / 3)
  hex = (radius) ->
    x0 = 0
    y0 = 0
    return hexAngles.map (angle) ->
      x1 = Math.sin(angle) * radius
      y1 = -Math.cos(angle) * radius
      dx = x1 - x0
      dy = y1 - y0

      x0 = x1
      y0 = y1
      return [dx, dy]

  return "m#{hex(radius).join('l')}z"


width = RADIUS * 2 * 100
height = RADIUS * 2 * 100

svg = d3.select('body')
  .append('svg')
  .attr('width', width + margin.left + margin.right)
  .attr('height', height + margin.top + margin.bottom)
  .append('g')
    .attr('transform', "translate(#{margin.left},#{margin.top})")

svg.append('clipPath')
  .attr('id', 'clip')
  .append('rect')
    .attr('class', 'mesh')
    .attr('width', width)
    .attr('height', height)

mapBoard = '''
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
# . . . . . . - - - - - - . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . + + + + + + . . . . . #
 # . . . . . - - - - - - - . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . + + + + + + + . . . . . #
# . . . . . - - - - - - - - . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . + + + + + + + + . . . . #
 # . . . . - - - - - - - - - . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . + + + + + + + + + . . . . #
# . . . . - - - - - - - - - - . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . + + + + + + + + + + . . . #
 # . . . - - - - - - - - - - - . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . + + + + + + + + + + + . . . #
# . . . . - - - - - - - - - - . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . + + + + + + + + + + . . . #
 # . . . . - - - - - - - - - . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . + + + + + + + + + . . . . #
# . . . . . - - - - - - - - . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . + + + + + + + + . . . . #
 # . . . . . - - - - - - - . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . + + + + + + + . . . . . #
# . . . . . . - - - - - - . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . + + + + + + . . . . . #
 # . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
'''


mapBoardSMALL = '''
# # # # # # # # # #
 # . . . . . . . . #
# . - - . . . . . #
 # . - . . . . . . #
# . . . . . . . . #
 # . . . 2 . . . . #
# . . . 2 2 . . . #
 # . . . 2 . . . . #
# . . . . . . . . #
 # . . . . . + . . #
# . . . . . + + . #
 # . . . . . . . . #
# # # # # # # # # #
'''


TILE_CLASSES =
  '+': 'tile red-home'
  '-': 'tile blue-home'
  '.': 'tile grass'
  '#': 'tile wall'
  '@': 'tile food' # Food

ANT_CLASSES =
  '-': 'ant blue'
  '+': 'ant red'


for rowStr, dy in mapBoard.split('\n')
  row = rowStr.trim().split(' ')
  for char, dx in row

    switch char
      when '.' then MAP.addTile(new MapTile(dx, dy, char))
      when '#' then MAP.addTile(new MapTile(dx, dy, char))
      when '-'
        MAP.addTile(new MapTile(dx, dy, char))
        MAP.addAnt(new Ant(dx, dy, char))
      when '+'
        MAP.addTile(new MapTile(dx, dy, char))
        MAP.addAnt(new Ant(dx, dy, char))
      else
        MAP.addTile(new MapTile(dx, dy, '.'))
        MAP.dropFood(dx, dy, parseInt(char))



MAP_LAYER = svg.append('g').attr('clip-path', 'url(#clip)')
FOOD_LAYER = svg.append('g').attr('clip-path', 'url(#clip)')
ANT_LAYER = svg.append('g').attr('clip-path', 'url(#clip)')

# Render the map once
update MAP_LAYER, MAP.getTiles()


# Step each ant every so often
setInterval (->
  ants = MAP.getAnts()
  # Randomly move them around
  for ant in ants
    ant.programCounter = RED_BRAIN[ant.programCounter].execute(MAP, ant)

), 10

# Redraw the game every so often
setInterval (->
  update FOOD_LAYER, MAP.getFoods()
  update ANT_LAYER, MAP.getAnts()
), 10
