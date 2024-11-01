extends Sprite2D

const BOARD_SIZE = 8
const CELL_WIDTH = 250

const TEXTURE_HOLDER = preload("res://Scenes/texture_holder.tscn")

const BLACK_BISHOP = preload("res://Assets/chess-bishop-black.png")
const WHITE_BISHOP = preload("res://Assets/chess-bishop-white.png")
const BLACK_KING = preload("res://Assets/chess-king-black.png")
const WHITE_KING = preload("res://Assets/chess-king-white.png")
const BLACK_KNIGHT = preload("res://Assets/chess-knight-black.png")
const WHITE_KNIGHT = preload("res://Assets/chess-knight-white.png")
const BLACK_PAWN = preload("res://Assets/chess-pawn-black.png")
const WHITE_PAWN = preload("res://Assets/chess-pawn-white.png")
const BLACK_QUEEN = preload("res://Assets/chess-queen-black.png")
const WHITE_QUEEN = preload("res://Assets/chess-queen-white.png")
const BLACK_ROOK = preload("res://Assets/chess-rook-black.png")
const WHITE_ROOK = preload("res://Assets/chess-rook-white.png")

const TURN_WHITE = preload("res://Assets/turn-white.png")
const TURN_BLACK = preload("res://Assets/turn-black.png")

const PIECE_MOVE = preload("res://Assets/Piece_move.png")

# @onready is shorthand for variable declaration inside _ready(); This is executed before _ready()
@onready var pieces = $Pieces
@onready var dots = $Dots
@onready var turn = $Turn

# Variable declarations
var board : Array
var white : bool = true # White's (default) / Black's turn
var state : bool = false # Confirming location / Selecting a piece to move (default)
var moves = [] # All possible moves by selected piece
var selected_piece : Vector2 # Position (Col, Row) (Note: Y-axis is inverted)

# Convention for square occupancy
# 6 = King, 5 = Queen, 4 = Rook, 3 = Bishop, 2 = Knight, 1 = Pawn, 0 = Empty
# Add '-' sign for Black pieces

# Position convention
# Board[i][j] <-> Conventional position (j, i) <-> Global position (j, - i)

# Called only once for the first time when "node enters tree"
func _ready() -> void:
	board.append([4, 2, 3, 5, 6, 3, 2, 4])
	board.append([1, 1, 1, 1, 1, 1, 1, 1])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([0, 0, 0, 0, 0, 0, 0, 0])
	board.append([-1, -1, -1, -1, -1, -1, -1, -1])
	board.append([-4, -2, -3, -5, -6, -3, -2, -4])
	
	display_board() # User-defined function
	
func _input(event):
	if event is InputEventMouseButton && event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_mouse_out(): return # User-defined function
			var varCol = snapped(get_global_mouse_position().x, 0) / CELL_WIDTH
			var varRow = abs(snapped(get_global_mouse_position().y, 0) / CELL_WIDTH)
			if !state && ((white && board[varRow][varCol] > 0) || (!white && board[varRow][varCol] < 0)):
				selected_piece = Vector2(varCol, varRow)
				state = true
				show_options() # User-defined function
			elif state: set_move(varCol, varRow) # User-defined function

func is_mouse_out():
	var pos = get_global_mouse_position()
	# Assuming the bottom-left corner of the board is at (0,0)... (Recall the note about Y-axis)
	if pos.x < 0 || pos.x > 8 * CELL_WIDTH || pos.y > 0 || pos.y < -8 * CELL_WIDTH: return true
	return false

func display_board():
	
	# Removing old pieces before displaying new ones
	for child in pieces.get_children():
		child.queue_free()
	
	# Displaying who's turn it is
	if white: 
		turn.texture = TURN_WHITE
		turn.global_position = $".".position + Vector2(0, 4.25 * CELL_WIDTH)
	else:
		turn.texture = TURN_BLACK
		turn.global_position = $".".position + Vector2(0, -4.25 * CELL_WIDTH)
	turn.scale = Vector2(1, 1) * (1 + 2 * CELL_WIDTH / 1000.0)
	
	# Reverse traversal so that there is proper overlapping/positioning of sprites
	for i in range(BOARD_SIZE - 1, -1, -1):
		for j in BOARD_SIZE: # (BOARD_SIZE - 1, -1, -1):
			var holder = TEXTURE_HOLDER.instantiate()
			pieces.add_child(holder)
			holder.global_position = Vector2((j + 0.5) * CELL_WIDTH, -(i + 0.75) * CELL_WIDTH)
			
			# Similar to switch-case in C
			match board[i][j]:
				-6: holder.texture = BLACK_KING; holder.global_position += Vector2(0, -0.15 * CELL_WIDTH)
				-5: holder.texture = BLACK_QUEEN
				-4: holder.texture = BLACK_ROOK
				-3: holder.texture = BLACK_BISHOP; holder.global_position += Vector2(0, -0.075 * CELL_WIDTH)
				-2: holder.texture = BLACK_KNIGHT; holder.global_position += Vector2(0, 0.05 * CELL_WIDTH)
				-1: holder.texture = BLACK_PAWN
				0: holder.texture = null
				6: holder.texture = WHITE_KING; holder.global_position += Vector2(0, -0.15 * CELL_WIDTH)
				5: holder.texture = WHITE_QUEEN
				4: holder.texture = WHITE_ROOK
				3: holder.texture = WHITE_BISHOP; holder.global_position += Vector2(0, -0.075 * CELL_WIDTH)
				2: holder.texture = WHITE_KNIGHT; holder.global_position += Vector2(0, 0.05 * CELL_WIDTH)
				1: holder.texture = WHITE_PAWN

func show_options():
	moves = get_moves() # User-defined function
	if moves == []:
		state = false
		return
	show_dots() # User-defined function
	
func show_dots():
	for move in moves: # Here, row = move.y and col = move.x
		var holder = TEXTURE_HOLDER.instantiate()
		dots.add_child(holder)
		holder.texture = PIECE_MOVE
		holder.global_position = Vector2((move.x + 0.5) * CELL_WIDTH, -(move.y + 0.5) * CELL_WIDTH)

func delete_dots():
	# Removing the dots
	for child in dots.get_children():
		child.queue_free()

func set_move(varCol, varRow):
	if moves.has(Vector2(varCol, varRow)):
		board[varRow][varCol] = board[selected_piece.y][selected_piece.x]
		board[selected_piece.y][selected_piece.x] = 0
		white = !white
		display_board() # User-defined function
	delete_dots() # User-defined functiom
	state = false

func get_moves():
	var _moves = []
	match abs(board[selected_piece.y][selected_piece.x]): # selected_piece = Vector2(varCol, varRow)
		1: _moves = get_pawn_moves() # User-defined function
		2: _moves = get_knight_moves() # User-defined function
		3: _moves = get_bishop_moves() # User-defined function
		4: _moves = get_rook_moves() # User-defined function
		5: _moves = get_queen_moves() # User-defined function
		6: _moves = get_king_moves() # User-defined function
		
	return _moves

func get_rook_moves():
	var _moves = []
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	for direction in directions:
		var pos = selected_piece
		pos += direction
		while is_valid_position(pos): # User-defined function
			if is_empty(pos): _moves.append(pos) # User-defined function
			elif is_enemy(pos): # User-defined function
				_moves.append(pos)
				break
			else: break # It's an ally (You can't capture it)
			pos += direction
	
	return _moves

func get_bishop_moves():
	var _moves = []
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]
	
	for direction in directions:
		var pos = selected_piece
		pos += direction
		while is_valid_position(pos): # User-defined function
			if is_empty(pos): _moves.append(pos) # User-defined function
			elif is_enemy(pos): # User-defined function
				_moves.append(pos)
				break
			else: break # It's an ally (You can't capture it)
			pos += direction
	
	return _moves
	
func get_queen_moves():
	var _moves = []
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	for direction in directions:
		var pos = selected_piece
		pos += direction
		while is_valid_position(pos): # User-defined function
			if is_empty(pos): _moves.append(pos) # User-defined function
			elif is_enemy(pos): # User-defined function
				_moves.append(pos)
				break
			else: break # It's an ally (You can't capture it)
			pos += direction
	
	return _moves
	
func get_king_moves():
	var _moves = []
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	for direction in directions:
		var pos = selected_piece + direction
		if is_valid_position(pos): # User-defined function
			if is_empty(pos) || is_enemy(pos): _moves.append(pos) # User-defined function
	
	return _moves

func get_knight_moves():
	var _moves = []
	var directions = [Vector2(2, -1), Vector2(2, 1), Vector2(-2, 1), Vector2(-2, -1),
	Vector2(1, -2), Vector2(1, 2), Vector2(-1, 2), Vector2(-1, -2)]
	
	for direction in directions:
		var pos = selected_piece + direction
		if is_valid_position(pos): # User-defined function
			if is_empty(pos) || is_enemy(pos): _moves.append(pos) # User-defined function
	
	return _moves
	
func get_pawn_moves():
	var _moves = []
	var direction
	var is_first_move = false
	var pos = selected_piece
	
	if white: direction = Vector2(0 , 1)
	else: direction = Vector2(0, -1)
	
	if (white && pos.y == 1) || (!white && pos.y == 6): is_first_move = true
	
	pos += direction # Looking ahead
	if is_empty(pos): _moves.append(pos) # User-defined function
	
	pos += Vector2(1, 0) # Looking to the global right of relative front
	if is_valid_position(pos) && is_enemy(pos): _moves.append(pos) # User-defined functions
	pos += Vector2(-2, 0) # Looking to the global left of relative front
	if is_valid_position(pos) && is_enemy(pos): _moves.append(pos) # User-defined functions
	
	pos += Vector2(1, 0) + direction # Looking two steps ahead
	if is_first_move && is_empty(pos) && is_empty(pos - direction): _moves.append(pos)
	
	return _moves

func is_valid_position(pos : Vector2):
	if pos.y >= 0 && pos.y < BOARD_SIZE && pos.x >= 0 && pos.x < BOARD_SIZE: return true
	return false

func is_empty(pos : Vector2):
	if !board[pos.y][pos.x]: return true
	return false

func is_enemy(pos : Vector2):
	if (white && board[pos.y][pos.x] < 0) || (!white && board[pos.y][pos.x] > 0): return true
	return false
