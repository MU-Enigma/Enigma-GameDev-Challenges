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
@onready var white_pieces: Control = $"../PromotionLayer/white_pieces"
@onready var black_pieces: Control = $"../PromotionLayer/black_pieces"

@onready var banner2D: Sprite2D = $"../EndLayer/Banner"
@onready var checkmate2D: Sprite2D = $"../EndLayer/Checkmate"
@onready var stalemate2D: Sprite2D = $"../EndLayer/Stalemate"
@onready var draw2D: Sprite2D = $"../EndLayer/Draw"
@onready var white_wins2D: Sprite2D = $"../EndLayer/White Wins"
@onready var black_wins2D: Sprite2D = $"../EndLayer/Black Wins"
@onready var go_to_menu_button: Button = $"../EndLayer/GoToMenuButton"

@onready var check2D: Sprite2D = $"../CheckLayer/check"

# Variable declarations
var board : Array
var white : bool = true # White's (default) / Black's turn
var state : bool = false # Confirming destination / Selecting a piece to move (default)
var moves = [] # All possible moves by selected piece
var selected_piece : Vector2 # Position (Col, Row) (Note: Y-axis is inverted)

var promotion_square = null

var white_king = false # bool("White king moved") (or better, bool("White King doesn't have castling rights"))
var black_king = false
var white_rook_left = false
var white_rook_right = false
var black_rook_left = false
var black_rook_right = false

var en_passant = null # Stores the move made by a pawn, now capturable by en passant

var white_king_pos = Vector2(4, 0)
var black_king_pos = Vector2(4, 7)

var fifty_moves_rule = 0

var unique_board_moves : Array = []
var frequency : Array = []

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
	
	# get_tree returns the instance of SceneTree that contains the Viewport etc etc
	# (Essentially the 'Main' scene tree, I suppose)
	var white_buttons = get_tree().get_nodes_in_group("white_pieces")
	var black_buttons = get_tree().get_nodes_in_group("black_pieces")
	
	# Connecting the signal 'button.pressed' to a special user-defined signal-handler (a callable) with 'button' 
	# as the callable's argument for each button
	# ('bind' arguments are passed as arguments after the those given by the signal;
	# But button.pressed has nothing to pass, so it's fine)
	for button in white_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button)) # Uses user-defined signal-handler
	for button in black_buttons:
		button.pressed.connect(self._on_button_pressed.bind(button)) # Uses user-defined signal-handler

func _input(event):
	if (event is InputEventMouseButton) && event.pressed && promotion_square == null:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_mouse_out(): return # User-defined function
			var varCol = snapped(get_global_mouse_position().x, 0) / CELL_WIDTH
			var varRow = abs(snapped(get_global_mouse_position().y, 0) / CELL_WIDTH)
			if !state && ((white && board[varRow][varCol] > 0) || (!white && board[varRow][varCol] < 0)):
				selected_piece = Vector2(varCol, varRow)
				state = true
				show_options() # User-defined function
			elif state:
				set_move(varCol, varRow) # User-defined function

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
	moves = get_moves(selected_piece) # User-defined function
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
	var just_now = false
	if moves.has(Vector2(varCol, varRow)):
		fifty_moves_rule += 1
		if is_enemy(Vector2(varCol, varRow)): fifty_moves_rule = 0 # User-defined function
		match board[selected_piece.y][selected_piece.x]:
			1:
				fifty_moves_rule = 0
				if varRow == 7: promote(varCol, varRow) # User_defined function
				if varRow == 3 && selected_piece.y == 1:
					en_passant = Vector2(varCol, varRow) # White Pawn at en_passant is now vulnerable to en passant
					just_now = true
				elif en_passant != null: # Checking if a White Pawn can do en passant
					# Vulnerable piece's position & this piece's destination - Same column
					# This piece's position & this piece's destination - Different columns
					# This piece's position & vulnerable piece's position - Same row
					# (Checking if destination is indeed an en passant destination by looking at its properties)
					if en_passant.x == varCol && selected_piece.x != varCol && selected_piece.y == en_passant.y:
						board[en_passant.y][en_passant.x] = 0 # Black Pawn captured by en passant
			-1:
				fifty_moves_rule = 0
				if varRow == 0: promote(varCol, varRow) # User_defined function
				if varRow == 4 && selected_piece.y == 6:
					en_passant = Vector2(varCol, varRow) # Black Pawn at en_passant is now vulnerable to en passant
					just_now = true
				elif en_passant != null: # Checking if a Black Pawn can do en passant
					# Vulnerable piece's position & this piece's destination - Same column
					# This piece's position & this piece's destination - Different columns
					# This piece's position & vulnerable piece's position - Same row
					# (Checking if destination is indeed an en passant destination by looking at its properties)
					if en_passant.x == varCol && selected_piece.x != varCol && selected_piece.y == en_passant.y:
						board[en_passant.y][en_passant.x] = 0 # White Pawn captured by en passant
			4:
				if selected_piece.y == 0:
					if selected_piece.x == 0: white_rook_left = true
					elif selected_piece.x == 7: white_rook_right = true
			-4: 
				if selected_piece.y == 7:
					if selected_piece.x == 0: black_rook_left = true
					elif selected_piece.x == 7: black_rook_right = true
			6:
				if selected_piece.y == 0 && selected_piece.x == 4:
					white_king = true
					if varCol == 2:
						white_rook_left = true
						white_rook_right = true # To indicate loss of castling rights
						board[0][0] = 0
						board[0][3] = 4
					elif varCol == 6:
						white_rook_left = true # To indicate loss of castling rights
						white_rook_right = true
						board[0][7] = 0
						board[0][5] = 4
				white_king_pos = Vector2(varCol, varRow)
			-6:
				if selected_piece.y == 7 && selected_piece.x == 4:
					black_king = true
					if varCol == 2:
						black_rook_left = true
						black_rook_right = true # To indicate loss of castling rights
						board[7][0] = 0
						board[7][3] = -4
					elif varCol == 6:
						black_rook_left = true # To indicate loss of castling rights
						black_rook_right = true
						board[7][7] = 0
						board[7][5] = -4
				black_king_pos = Vector2(varCol, varRow)
		if !just_now: en_passant = null # En passant can no longer be made as it isn't 'just now'
		board[varRow][varCol] = board[selected_piece.y][selected_piece.x]
		board[selected_piece.y][selected_piece.x] = 0
		white = !white
		if threefold_position(): draw_display() # User-defined functions
		display_board() # User-defined function
	delete_dots() # User-defined functiom
	state = false
	
	if white && is_in_check(white_king_pos): # User-defined function
		check2D.global_position = Vector2((white_king_pos.x + 0.5) * CELL_WIDTH, -(white_king_pos.y + 0.75) * CELL_WIDTH)
		check2D.visible = true
	elif !white && is_in_check(black_king_pos): # User-defined function
		check2D.global_position = Vector2((black_king_pos.x + 0.5) * CELL_WIDTH, -(black_king_pos.y + 0.75) * CELL_WIDTH)
		check2D.visible = true
	else:
		check2D.visible = false
	
	# If the square you clicked on is not a valid move for the selected piece as it has another piece already (apart from the selected piece)...
	if (selected_piece.x != varCol || selected_piece.y != varRow) && ((white && board[varRow][varCol] > 0) || (!white && board[varRow][varCol] < 0)):
		selected_piece = Vector2(varCol, varRow)
		state = true
		show_options() # User-defined function
	# If the square you clicked on is just empty (neither a valid move of the selected piece nor the selected piece position)...
	elif is_stalemate(): # User-defined function
		if (white && is_in_check(white_king_pos)) || (!white && is_in_check(black_king_pos)): # User-defined function
			checkmate_display() # User-defined function
		else:
			stalemate_display() # User-defined function
	if fifty_moves_rule == 50:
		draw_display() # User-defined function
	if insufficient_material():
		draw_display() # User-defined function

# Note: selected_piece has been localised to other variables from now on

func get_moves(selected : Vector2):
	var _moves = []
	match abs(board[selected.y][selected.x]): # selected_piece = Vector2(varCol, varRow)
		1: _moves = get_pawn_moves(selected) # User-defined function
		2: _moves = get_knight_moves(selected) # User-defined function
		3: _moves = get_bishop_moves(selected) # User-defined function
		4: _moves = get_rook_moves(selected) # User-defined function
		5: _moves = get_queen_moves(selected) # User-defined function
		6: _moves = get_king_moves(selected) # User-defined function
		
	return _moves

func get_rook_moves(piece_position : Vector2):
	var _moves = []
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	for direction in directions:
		var pos = piece_position
		pos += direction
		while is_valid_position(pos): # User-defined function
			if is_empty(pos): # User-defined function
				# Piece is moved to check if it stops CHECK and placed back
				board[pos.y][pos.x] = 4 if white else -4
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = 0
				board[piece_position.y][piece_position.x] = 4 if white else -4
			elif is_enemy(pos): # User-defined function
				 # Piece captures to check if it stops CHECK and undoes the capture
				var temp = board[pos.y][pos.x]
				board[pos.y][pos.x] = 4 if white else -4
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = temp
				board[piece_position.y][piece_position.x] = 4 if white else -4
				break
			else: break # It's an ally (You can't capture it)
			pos += direction
	
	return _moves

func get_bishop_moves(piece_position : Vector2):
	var _moves = []
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]
	
	for direction in directions:
		var pos = piece_position
		pos += direction
		while is_valid_position(pos): # User-defined function
			if is_empty(pos): # User-defined function
				# Piece is moved to check if it stops CHECK and placed back
				board[pos.y][pos.x] = 3 if white else -3
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = 0
				board[piece_position.y][piece_position.x] = 3 if white else -3
			elif is_enemy(pos): # User-defined function
				# Piece captures to check if it stops CHECK and undoes the capture
				var temp = board[pos.y][pos.x]
				board[pos.y][pos.x] = 3 if white else -3
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = temp
				board[piece_position.y][piece_position.x] = 3 if white else -3
				break
			else: break # It's an ally (You can't capture it)
			pos += direction
	
	return _moves

func get_queen_moves(piece_position : Vector2):
	var _moves = []
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	for direction in directions:
		var pos = piece_position
		pos += direction
		while is_valid_position(pos): # User-defined function
			if is_empty(pos): # User-defined function
				# Piece is moved to check if it stops CHECK and placed back
				board[pos.y][pos.x] = 5 if white else -5
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = 0
				board[piece_position.y][piece_position.x] = 5 if white else -5
			elif is_enemy(pos): # User-defined function
				# Piece captures to check if it stops CHECK and undoes the capture
				var temp = board[pos.y][pos.x]
				board[pos.y][pos.x] = 5 if white else -5
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = temp
				board[piece_position.y][piece_position.x] = 5 if white else -5
				break
			else: break # It's an ally (You can't capture it)
			pos += direction
	
	return _moves

func get_king_moves(piece_position : Vector2):
	var _moves = []
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	# To ensure CHECK-checking mechanism isn't blocked by the King...
	if white:
		board[white_king_pos.y][white_king_pos.x] = 0
	else:
		board[black_king_pos.y][black_king_pos.x] = 0
	
	for direction in directions:
		var pos = piece_position + direction
		if is_valid_position(pos) && !is_in_check(pos): # User-defined functions
			if is_empty(pos) || is_enemy(pos): _moves.append(pos) # User-defined functions
	
	if white && !white_king  && !is_in_check(Vector2(4, 0)): # User-defined function
		if !white_rook_left && is_empty(Vector2(3, 0)) && !is_in_check(Vector2(3, 0)) && is_empty(Vector2(2, 0)) && !is_in_check(Vector2(2, 0)) && is_empty(Vector2(1, 0)): # User-defined functions
			_moves.append(Vector2(2, 0))
		if !white_rook_right && is_empty(Vector2(5, 0)) && !is_in_check(Vector2(5, 0)) && is_empty(Vector2(6, 0)) && !is_in_check(Vector2(6, 0)): # User-defined functions
			_moves.append(Vector2(6, 0))
	elif !white && !black_king && !is_in_check(Vector2(4, 7)):
		if !black_rook_left && is_empty(Vector2(3, 7)) && !is_in_check(Vector2(3, 7)) && is_empty(Vector2(2, 7)) && !is_in_check(Vector2(2, 7)) && is_empty(Vector2(1, 7)): # User-defined functions
			_moves.append(Vector2(2, 7))
		if !black_rook_right && is_empty(Vector2(5, 7)) && !is_in_check(Vector2(5, 7)) && is_empty(Vector2(6, 7)) && !is_in_check(Vector2(6, 7)): # User-defined functions
			_moves.append(Vector2(6, 7))
	
	# Restoring values...
	if white:
		board[white_king_pos.y][white_king_pos.x] = 6
	else:
		board[black_king_pos.y][black_king_pos.x] = -6
	
	return _moves

func get_knight_moves(piece_position : Vector2):
	var _moves = []
	var directions = [Vector2(2, -1), Vector2(2, 1), Vector2(-2, 1), Vector2(-2, -1),
	Vector2(1, -2), Vector2(1, 2), Vector2(-1, 2), Vector2(-1, -2)]
	
	for direction in directions:
		var pos = piece_position + direction
		if is_valid_position(pos): # User-defined function
			if is_empty(pos): # User-defined function
				# Piece is moved to check if it stops CHECK and placed back
				board[pos.y][pos.x] = 2 if white else -2
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = 0
				board[piece_position.y][piece_position.x] = 2 if white else -2
			elif is_enemy(pos): # User-defined function
				# Piece captures to check if it stops CHECK and undoes the capture
				var temp = board[pos.y][pos.x]
				board[pos.y][pos.x] = 2 if white else -2
				board[piece_position.y][piece_position.x] = 0
				if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
					_moves.append(pos)
				board[pos.y][pos.x] = temp
				board[piece_position.y][piece_position.x] = 2 if white else -2
	
	return _moves

func get_pawn_moves(piece_position : Vector2):
	var _moves = []
	var direction
	var pos
	var is_first_move = false
	
	if white: direction = Vector2(0 , 1)
	else: direction = Vector2(0, -1)
	
	if (white && piece_position.y == 1) || (!white && piece_position.y == 6): is_first_move = true
	
	# Last condition ensures the attacking pawn is in one of the adjacent columns to perform en passant
	if en_passant != null && ((white && piece_position.y == 4) || (!white && piece_position.y == 3)) && abs(piece_position.x - en_passant.x) == 1:
		pos = en_passant + direction
		# Performing en passant, checking if CHECK is moved out of, and returning to initial positions
		board[pos.y][pos.x] = 1 if white else -1
		board[piece_position.y][piece_position.x] = 0
		board[en_passant.y][en_passant.x] = 0
		if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
			_moves.append(pos)
		board[pos.y][pos.x] = 0
		board[piece_position.y][piece_position.x] = 1 if white else -1
		board[en_passant.y][en_passant.x] = -1 if white else 1
	
	pos = piece_position
	
	pos += direction # Looking one step ahead
	if is_empty(pos): # User-defined function
		# Piece is moved to check if it stops CHECK and placed back
		board[pos.y][pos.x] = 1 if white else -1
		board[piece_position.y][piece_position.x] = 0
		if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
			_moves.append(pos)
		board[pos.y][pos.x] = 0
		board[piece_position.y][piece_position.x] = 1 if white else -1
	
	
	pos += Vector2(1, 0) # Looking to the global right of relative front
	if is_valid_position(pos) && is_enemy(pos): # User-defined functions
		# Piece captures to check if it stops CHECK and undoes the capture
		var temp = board[pos.y][pos.x]
		board[pos.y][pos.x] = 1 if white else -1
		board[piece_position.y][piece_position.x] = 0
		if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
			_moves.append(pos)
		board[pos.y][pos.x] = temp
		board[piece_position.y][piece_position.x] = 1 if white else -1
	pos += Vector2(-2, 0) # Looking to the global left of relative front
	if is_valid_position(pos) && is_enemy(pos): # User-defined functions
		# Piece captures to check if it stops CHECK and undoes the capture
		var temp = board[pos.y][pos.x]
		board[pos.y][pos.x] = 1 if white else -1
		board[piece_position.y][piece_position.x] = 0
		if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
			_moves.append(pos)
		board[pos.y][pos.x] = temp
		board[piece_position.y][piece_position.x] = 1 if white else -1
	
	pos += Vector2(1, 0) + direction # Looking two steps ahead
	if is_first_move && is_empty(pos) && is_empty(pos - direction): # User-defined function
		# Piece is moved to check if it stops CHECK and placed back
		board[pos.y][pos.x] = 1 if white else -1
		board[piece_position.y][piece_position.x] = 0
		if (white && !is_in_check(white_king_pos)) || (!white && !is_in_check(black_king_pos)): # User-defined function
			_moves.append(pos)
		board[pos.y][pos.x] = 0
		board[piece_position.y][piece_position.x] = 1 if white else -1
	
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

func promote(varCol, varRow):
	promotion_square = Vector2(varCol, varRow)
	white_pieces.visible = white
	black_pieces.visible = !white

func _on_button_pressed(button):
	var num_char = int(button.name.substr(0, 1))
	# 'minus' num_char because by the time this is executed, the opponent gets the turn
	board[promotion_square.y][promotion_square.x] = -num_char if white else num_char
	white_pieces.visible = false
	black_pieces.visible = false
	promotion_square = null
	display_board() # User-defined function

func is_in_check(king_pos : Vector2):
	var directions = [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	# Eg: White King under attack by a Black Pawn - Black Pawn in the row right above the one with White King
	var pawn_direction = 1 if white else -1
	var pawn_attacks = [king_pos + Vector2(1, pawn_direction), king_pos + Vector2(-1, pawn_direction)]
	
	for attack in pawn_attacks:
		if is_valid_position(attack): # User-defined function
			if (white && board[attack.y][attack.x] == -1) || (!white && board[attack.y][attack.x] == 1): return true
	
	for direction in directions:
		var pos = king_pos + direction
		if is_valid_position(pos): # User-defined function
			if (white && board[pos.y][pos.x] == -6) || (!white && board[pos.y][pos.x] == 6): return true
	
	for direction in directions:
		var pos = king_pos + direction
		while is_valid_position(pos): # User-defined function
			if !is_empty(pos): # User-defined function
				var piece = board[pos.y][pos.x]
				if (direction.y == 0 || direction.x == 0) && ((white && piece in [-4, -5]) || (!white && piece in [4, 5])):
					return true # CHECK in horizontal/vertical direction by Rook or Queen
				elif (direction.y != 0 && direction.x != 0) && ((white && piece in [-3, -5]) || (!white && piece in [3, 5])):
					return true # CHECK in diagonal direction by Bishop or Queen
				break
			pos += direction
	
	var knight_directions = [Vector2(2, -1), Vector2(2, 1), Vector2(-2, 1), Vector2(-2, -1),
	Vector2(1, -2), Vector2(1, 2), Vector2(-1, 2), Vector2(-1, -2)]
	for direction in knight_directions:
		var pos = king_pos + direction
		if is_valid_position(pos): # User-defined function
			if (white && board[pos.y][pos.x] == -2) || (!white && board[pos.y][pos.x] == 2):
				return true
				
	return false

func is_stalemate():
	if white:
		for i in BOARD_SIZE:
			for j in BOARD_SIZE:
				if board[i][j] > 0 && get_moves(Vector2(j, i)) != []: return false
	else:
		for i in BOARD_SIZE:
			for j in BOARD_SIZE:
				if board[i][j] < 0 && get_moves(Vector2(j, i)) != []: return false
	return true

func insufficient_material():
	var white_pieces_num = 0
	var black_pieces_num = 0
	
	for i in BOARD_SIZE:
			for j in BOARD_SIZE:
				match board[i][j]:
					2, 3:
						if white_pieces_num == 0: white_pieces_num += 1
						else: return false
					-2, -3:
						if black_pieces_num == 0: black_pieces_num += 1
						else: return false
					6, -6, 0: pass
					_: return false
	
	return true

func threefold_position():
	for index in unique_board_moves.size():
		if board == unique_board_moves[index]: # Found a match
			frequency[index] += 1
			if frequency[index] >= 3: return true # Draw?
			return false # No Draw!
	unique_board_moves.append(board.duplicate(true)) # Deep copying
	frequency.append(1)

func checkmate_display():
	banner2D.visible = true
	checkmate2D.visible = true
	if white: black_wins2D.visible = true
	else: white_wins2D.visible = true
	go_to_menu_button.visible = true

func stalemate_display():
	banner2D.visible = true
	stalemate2D.visible = true
	go_to_menu_button.visible = true

func draw_display():
	banner2D.visible = true
	draw2D.visible = true
	go_to_menu_button.visible = true
