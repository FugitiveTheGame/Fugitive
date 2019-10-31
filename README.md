# fugitive
 A multiplayer hide and seek game written in Godot

## How to make a map
1. Create a new directory under maps/
2. Menu: Scene -> New Inherited Scene
3. Go to: res://maps/base and select BaseMap.tscn
4. Save your scene as MapName.tscn inside the directory you created in Step 1
5. Now you need to select a Tile Set work work with.
6. Under the "map" node in your new scene, add a child: TileMap
7. Rename it to "ground"
8. On the new TileMap node, set it's Tile Set. Click load, and select: res://maps/tilesets/neighborhood/ground.tres
9. Under Cell, set size to: 256x256
10. Under Colision, set layer to: car_walls, set mask to nothing
11 Under the "map" node in your new scene, add a child: TileMap
12. Rename it to "walls"
13. On the new TileMap node, set it's Tile Set. Click load, and select: res://maps/tilesets/neighborhood/walls.tres
14. Under Cell, set size to: 128x128
15. Under Colision, set layer to: walls, set mask to nothing
16. Under the "map" node in your new scene, add a child: TileMap
17. Rename it to "features"
18. On the new TileMap node, set it's Tile Set. Click load, and select: res://maps/tilesets/neighborhood/features.tres
19. Under Cell, set size to: 64x64
20. Under Colision, set layer to: walls, set mask to nothing

Now your setup to use the Neighborhood tileset!

Now paint your ground tiles first, then enclose the map with walls. And finally pepper in some features.

## Other map making notes
Make sure you spread out the spawn points so they are not on top of each other.

Make sure to move the win zone area to where ever your win zone is.

If you have a section of map where a Car could possibly escape the road, you can create an instance of the actor: RoadWall and block it off, for instance where parking lot tiles are.

Other actors you maybe interested in:
* Street Light
* Motion Sensor
