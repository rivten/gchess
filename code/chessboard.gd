extends Node2D

# TODO(hugo):
#    - error : when checking for castling, a rook could have not moved, but have been taken
#              therefore invalidating the castling... (null error)

enum PieceColor {WHITE, BLACK}
enum PieceType {KING, QUEEN, ROOK, KNIGHT, BISHOP, PAWN}

const piece_color_name = ["White", "Black"]
const piece_type_name = ["King", "Queen", "Rook", "Knight", "Bishop", "Pawn"]

#####################################################
# {
class Piece:
	var color
	var type
	var chess_pos

	func _init(piece_color, piece_type, piece_pos):
		color = piece_color;
		type = piece_type;
		chess_pos = piece_pos;

	func str_piece():
		return(piece_type_name[type] + " " + piece_color_name[color] + " " + str(chess_pos))
# }
#####################################################

#####################################################
# {
class CastlingTracker:
	var has_king_rook_moved
	var has_queen_rook_moved
	var has_king_moved

	func _init():
		has_king_rook_moved = false
		has_queen_rook_moved = false
		has_king_moved = false
# }
#####################################################


#####################################################
# {
class ChessMove:
	var from = null
	var to = null
	var is_castling_king_side = false
	var is_castling_queen_side = false
	var deleted_pieces = []
	var moved_piece = null

	func _init(move_from, move_to):
		from = move_from
		to = move_to
# }
#####################################################

const TILE_SIZE = 64.0
const color_white = Color(1.0, 1.0, 1.0, 1.0)
const color_green = Color(64.0 / 255.0, 146.0 / 255.0, 59.0 / 255.0)
const color_highlight = Color(0.0, 0.0, 1.0, 0.0)

var highlighted_tiles = []
var piece_textures = []
var color_to_move = WHITE
var pawn_that_doubled_last_move = null
var piece_list = []
var selected_piece = null
var stop_game = false

var castling_trackers = []

func chess_pos_to_absolute(chess_pos):
	return(Vector2(TILE_SIZE * chess_pos.x, TILE_SIZE * (7 - chess_pos.y)))

func load_textures():
	for type in range(6):
		for color in range(2):
			piece_textures.append(load("res://data/images/" + piece_color_name[color] + piece_type_name[type] + ".png"))

func create_chessboard():
	for i in range(8):
		create_piece(BLACK, PAWN, Vector2(i, 6))
		create_piece(WHITE, PAWN, Vector2(i, 1))

	create_piece(WHITE, ROOK, Vector2(0, 0))
	create_piece(WHITE, ROOK, Vector2(7, 0))
	create_piece(BLACK, ROOK, Vector2(0, 7))
	create_piece(BLACK, ROOK, Vector2(7, 7))

	create_piece(WHITE, KNIGHT, Vector2(1, 0))
	create_piece(WHITE, KNIGHT, Vector2(6, 0))
	create_piece(BLACK, KNIGHT, Vector2(1, 7))
	create_piece(BLACK, KNIGHT, Vector2(6, 7))

	create_piece(WHITE, BISHOP, Vector2(2, 0))
	create_piece(WHITE, BISHOP, Vector2(5, 0))
	create_piece(BLACK, BISHOP, Vector2(2, 7))
	create_piece(BLACK, BISHOP, Vector2(5, 7))

	create_piece(WHITE, QUEEN, Vector2(3, 0))
	create_piece(BLACK, QUEEN, Vector2(3, 7))
	create_piece(WHITE, KING, Vector2(4, 0))
	create_piece(BLACK, KING, Vector2(4, 7))

func _ready():
	load_textures()
	create_chessboard()
	castling_trackers = [CastlingTracker.new(), CastlingTracker.new()]

func _draw():
	# NOTE(hugo): Draw background
	for y in range(8):
		for x in range(8):
			var rect = Rect2(x * TILE_SIZE, (7 - y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var is_white_tile = ((x + y) % 2 != 0)
			var color = color_white
			if !is_white_tile:
				color = color_green
			if is_highlighted(Vector2(x, y)):
				color = color_highlight
			draw_rect(rect, color, true)

	for piece in piece_list:
		var texture = piece_textures[2 * piece.type + piece.color]
		var pos = chess_pos_to_absolute(piece.chess_pos)
		draw_texture(texture, pos)
			
func is_highlighted(tile):
	for t in highlighted_tiles:
		if t == tile:
			return(true)
	return(false)

func get_random_piece(color):
	var pieces_of_color = []
	for piece in piece_list:
		if(piece.color == color):
			pieces_of_color.append(piece)
	randomize()
	var random_index = randi() % pieces_of_color.size()
	return(pieces_of_color[random_index])

func ai_move():
	assert(color_to_move == BLACK)
	var random_piece = null
	var moves = []
	while !random_piece:
		random_piece = get_random_piece(color_to_move)
		moves = get_possible_moves(random_piece.chess_pos)
		if(moves.size() == 0):
			random_piece = null
	assert(random_piece)
	randomize()
	var random_index = randi() % moves.size()
	var random_move_to = moves[random_index]
	var random_piece_prev_pos = random_piece.chess_pos

	var ai_move = ChessMove.new(random_piece.chess_pos, random_move_to)
	move_piece(ai_move)
	post_move(random_piece, random_piece_prev_pos, random_move_to)

func post_move(moved_piece, moved_piece_prev_pos, move_to):
	if(moved_piece.type == PAWN && abs(moved_piece_prev_pos.y - move_to.y) == 2):
		pawn_that_doubled_last_move = moved_piece
	else:
		pawn_that_doubled_last_move = null

	if(moved_piece.type == PAWN):
		if(moved_piece.color == WHITE && moved_piece.chess_pos.y == 7):
			moved_piece.type = QUEEN
		if(moved_piece.color == BLACK && moved_piece.chess_pos.y == 0):
			moved_piece.type = QUEEN

	if(moved_piece.type == KING):
		castling_trackers[moved_piece.color].has_king_moved = true
	if(moved_piece.type == ROOK):
		if(moved_piece_prev_pos == Vector2(0, 0)):
			castling_trackers[WHITE].has_queen_rook_moved = true
		if(moved_piece_prev_pos == Vector2(7, 0)):
			castling_trackers[WHITE].has_king_rook_moved = true
		if(moved_piece_prev_pos == Vector2(0, 7)):
			castling_trackers[BLACK].has_queen_rook_moved = true
		if(moved_piece_prev_pos == Vector2(7, 7)):
			castling_trackers[BLACK].has_king_rook_moved = true

	color_to_move = opposite_color(color_to_move)

	# NOTE(hugo): Check stopping condition
	if(is_current_player_checkmate()):
		stop_game = true
		print("Checkmate!")
	elif(is_draw()):
		stop_game = true
		print("Draw!")

func _input(event):
	if event is InputEventMouseButton:
		if(!stop_game):
			var tile_clicked = get_tile_clicked(event.position)
			if(is_highlighted(tile_clicked)):
				var selected_piece_prev_pos = selected_piece.chess_pos
				var move = ChessMove.new(selected_piece.chess_pos, tile_clicked)
				move_piece(move)

				highlighted_tiles = []
				post_move(selected_piece, selected_piece_prev_pos, tile_clicked)

				if(stop_game):
					return

				# NOTE(hugo): AI Turn
				ai_move()

			else:
				selected_piece = get_piece_at_tile(tile_clicked)
				#print("Before")
				#print_state()
				display_possible_moves(tile_clicked)
				#print("After")
				#print_state()
		update()

func get_tile_clicked(mouse_pos):
	var rel_pos = mouse_pos - position
	return(Vector2(floor(rel_pos.x / TILE_SIZE), 7 - floor(rel_pos.y / TILE_SIZE)))

func create_piece(color, type, chess_pos):
	piece_list.append(Piece.new(color, type, chess_pos))

func move_piece(move):
	var piece_to_move = get_piece_at_tile(move.from)
	assert(piece_to_move)
	move.moved_piece = piece_to_move
	var taken_piece = get_piece_at_tile(move.to)
	if(taken_piece != null):
		move.deleted_pieces.append(taken_piece)
		piece_list.erase(taken_piece)
	else:
		# NOTE(hugo): check if the taken piece is en passant
		if(pawn_that_doubled_last_move && abs(pawn_that_doubled_last_move.chess_pos.x - move.from.x) == 1 && abs(pawn_that_doubled_last_move.chess_pos.y - move.from.y) == 0):
			move.deleted_pieces.append(pawn_that_doubled_last_move)
			piece_list.erase(pawn_that_doubled_last_move)
		else:
			# NOTE(hugo): check if that was a castling
			if(piece_to_move.type == KING && abs(move.from.x - move.to.x) == 2):
				var row = get_base_row(color_to_move)
				if(move.from.x > move.to.x):
					# NOTE(hugo): Castle queen side
					var queen_rook = get_piece_at_tile(Vector2(0, row))
					assert(queen_rook.type == ROOK)
					queen_rook.chess_pos = Vector2(3, row)
					move.is_castling_queen_side = true
				else:
					# NOTE(hugo): Castle king side
					var king_rook = get_piece_at_tile(Vector2(7, row))
					assert(king_rook.type == ROOK)
					king_rook.chess_pos = Vector2(5, row)
					move.is_castling_king_side = true

	piece_to_move.chess_pos = move.to

func display_possible_moves(tile_clicked):
	highlighted_tiles = []
	if(selected_piece && selected_piece.color == color_to_move):
		highlighted_tiles += get_possible_moves(selected_piece.chess_pos)
	return(highlighted_tiles)

func get_piece_at_tile(tile):
	for piece in piece_list:
		if piece.chess_pos == tile:
			return(piece)
	return(null)

func get_pure_list_move(piece):
	var result = []
	match piece.type:
		KING:
			result += get_king_moves(piece)
		QUEEN:
			result += get_queen_moves(piece)
		ROOK:
			result += get_rook_moves(piece)
		KNIGHT:
			result += get_knight_moves(piece)
		BISHOP:
			result += get_bishop_moves(piece)
		PAWN:
			result += get_pawn_moves(piece)
	return(result)

func get_possible_moves(move_from):
	var piece = get_piece_at_tile(move_from)
	var result = get_pure_list_move(piece)
	if(piece.type == KING):
		result += add_castling_moves(move_from, piece.color)

	result = delete_moves_that_makes_check(move_from, result, piece.color)
	return result

func is_king_in_check(player_color):
	for piece in piece_list:
		if(piece.color == opposite_color(player_color)):
			var piece_moves = get_pure_list_move(piece)
			for move in piece_moves:
				var piece_under_move = get_piece_at_tile(move)
				if(piece_under_move && piece_under_move.type == KING && piece_under_move.color == player_color):
					return(true)
	return(false)

func undo_castling_king_side(color):
	# NOTE(hugo): King is alreay undone
	# Only undo the rook
	var row = get_base_row(color)
	var rook_piece = get_piece_at_tile(Vector2(5, row))
	assert(rook_piece.type == ROOK)
	rook_piece.chess_pos = Vector2(7, row)

func undo_castling_queen_side(color):
	var row = get_base_row(color)
	var rook_piece = get_piece_at_tile(Vector2(3, row))
	assert(rook_piece.type == ROOK)
	rook_piece.chess_pos = Vector2(0, row)

func undo_move(move):
	assert(move.moved_piece)
	assert(move.moved_piece.chess_pos == move.to)
	move.moved_piece.chess_pos = move.from
	piece_list += move.deleted_pieces
	if(move.is_castling_king_side):
		undo_castling_king_side(move.moved_piece.color)
	if(move.is_castling_queen_side):
		undo_castling_queen_side(move.moved_piece.color)

func is_king_in_check_with_move(move_from, move_to, player_color):
	# TODO(hugo): I don't think this could take into account a
	# en-passant move that could put the king in check :(
	var move = ChessMove.new(move_from, move_to)
	move_piece(move)
	var result = is_king_in_check(player_color)
	# NOTE(hugo): Reset to previous state
	undo_move(move)
	return(result)

func delete_moves_that_makes_check(move_from, move_list, player_color):
	var result = []
	for move_to in move_list:
		if(!is_king_in_check_with_move(move_from, move_to, player_color)):
			result.append(move_to)

	return(result)

func get_pawn_moves(piece):
	var result = []

	if(piece.color == WHITE):
		var is_starting_col = (piece.chess_pos.y == 1)
		result += add_pos_if_no_piece(piece.chess_pos + Vector2(0, 1))
		if(is_tile_no_friendly(piece.chess_pos + Vector2(-1, 1), WHITE)):
			result.append(piece.chess_pos + Vector2(-1, 1))
		if(is_tile_no_friendly(piece.chess_pos + Vector2(1, 1), WHITE)):
			result.append(piece.chess_pos + Vector2(1, 1))
		if(is_starting_col && is_free_tile(piece.chess_pos + Vector2(0, 1))):
			result += add_pos_if_no_piece(piece.chess_pos + Vector2(0, 2))
		if(pawn_that_doubled_last_move && abs(pawn_that_doubled_last_move.chess_pos.x - piece.chess_pos.x) == 1 && pawn_that_doubled_last_move.chess_pos.y == piece.chess_pos.y):
			result += add_pos_if_no_piece(Vector2(pawn_that_doubled_last_move.chess_pos.x, piece.chess_pos.y + 1))

	if(piece.color == BLACK):
		var is_starting_col = (piece.chess_pos.y == 6)
		result += add_pos_if_no_piece(piece.chess_pos - Vector2(0, 1))
		if(is_tile_no_friendly(piece.chess_pos + Vector2(-1, -1), BLACK)):
			result.append(piece.chess_pos + Vector2(-1, -1))
		if(is_tile_no_friendly(piece.chess_pos + Vector2(1, -1), BLACK)):
			result.append(piece.chess_pos + Vector2(1, -1))
		if(is_starting_col && is_free_tile(piece.chess_pos - Vector2(0, 1))):
			result += add_pos_if_no_piece(piece.chess_pos - Vector2(0, 2))
		if(pawn_that_doubled_last_move && abs(pawn_that_doubled_last_move.chess_pos.x - piece.chess_pos.x) == 1 && pawn_that_doubled_last_move.chess_pos.y == piece.chess_pos.y):
			result += add_pos_if_no_piece(Vector2(pawn_that_doubled_last_move.chess_pos.x, piece.chess_pos.y - 1))

	return(result)

func get_king_moves(piece):
	var result = []
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(0, 1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(0, -1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(1, 0), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-1, 0), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(1, 1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(1, -1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-1, 1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-1, -1), piece.color)
	return(result)

func get_queen_moves(piece):
	var result = []
	result += add_all_pos_in_dir(piece, Vector2(0, 1))
	result += add_all_pos_in_dir(piece, Vector2(0, -1))
	result += add_all_pos_in_dir(piece, Vector2(1, 0))
	result += add_all_pos_in_dir(piece, Vector2(-1, 0))
	result += add_all_pos_in_dir(piece, Vector2(1, 1))
	result += add_all_pos_in_dir(piece, Vector2(1, -1))
	result += add_all_pos_in_dir(piece, Vector2(-1, 1))
	result += add_all_pos_in_dir(piece, Vector2(-1, -1))
	return(result)

func get_rook_moves(piece):
	var result = []
	result += add_all_pos_in_dir(piece, Vector2(0, 1))
	result += add_all_pos_in_dir(piece, Vector2(0, -1))
	result += add_all_pos_in_dir(piece, Vector2(1, 0))
	result += add_all_pos_in_dir(piece, Vector2(-1, 0))
	return(result)

func get_bishop_moves(piece):
	var result = []
	result += add_all_pos_in_dir(piece, Vector2(1, 1))
	result += add_all_pos_in_dir(piece, Vector2(1, -1))
	result += add_all_pos_in_dir(piece, Vector2(-1, 1))
	result += add_all_pos_in_dir(piece, Vector2(-1, -1))
	return(result)

func get_knight_moves(piece):
	var result = []
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(2, 1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(2, -1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-2, 1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-2, -1), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(1, 2), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(1, -2), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-1, 2), piece.color)
	result += add_pos_if_no_friendly_piece(piece.chess_pos + Vector2(-1, -2), piece.color)
	return(result)

func is_in_board(tile):
	return(tile.x >= 0 && tile.x < 8 && tile.y >= 0 && tile.y < 8)

func opposite_color(color):
	if(color == WHITE):
		return(BLACK)
	else:
		return(WHITE)

func is_free_tile(tile):
	if(is_in_board(tile)):
		var piece = get_piece_at_tile(tile)
		return(piece == null)
	return(false)

func is_tile_free_or_no_friendly(tile, test_piece_color):
	if(is_in_board(tile)):
		var piece = get_piece_at_tile(tile)
		return((piece == null) || (test_piece_color == opposite_color(piece.color)))
	return(false)

func is_tile_no_friendly(tile, test_piece_color):
	if(is_in_board(tile)):
		var piece = get_piece_at_tile(tile)
		return((piece != null) && (test_piece_color == opposite_color(piece.color)))
	return(false)

func add_pos_if_no_friendly_piece(tile, test_piece_color):
	if(is_tile_free_or_no_friendly(tile, test_piece_color)):
		return([tile])
	return([])

func add_pos_if_no_piece(tile):
	if(is_free_tile(tile)):
		return([tile])
	return([])

func add_all_pos_in_dir(piece, dir):
	var result = []
	for i in range(1, 8):
		var test_tile = piece.chess_pos + i * dir
		if(is_tile_free_or_no_friendly(test_tile, piece.color)):
			result.append(test_tile)
			if(is_tile_no_friendly(test_tile, piece.color)):
				break
		else:
			break

	return(result)

func get_base_row(color):
	if(color == WHITE):
		return(0)
	else:
		return(7)

func is_king_side_available(color):
	var row = get_base_row(color)
	var f_piece = get_piece_at_tile(Vector2(5, row))
	var g_piece = get_piece_at_tile(Vector2(6, row))
	return(!f_piece && !g_piece)

func is_queen_side_available(color):
	var row = get_base_row(color)
	var b_piece = get_piece_at_tile(Vector2(1, row))
	var c_piece = get_piece_at_tile(Vector2(2, row))
	var d_piece = get_piece_at_tile(Vector2(3, row))
	return(!b_piece && !c_piece && !d_piece)

func is_tile_attacked_piece(piece, tile):
	var piece_moves = get_pure_list_move(piece)
	for move in piece_moves:
		if(move == tile):
			return(true)
	return(false)

func is_tile_attacked_by_color(color, tile):
	for piece in piece_list:
		if(piece.color == color):
			if(is_tile_attacked_piece(piece, tile)):
				return(true)
	return(false)

func can_castle_king_side(color):
	if(castling_trackers[color].has_king_moved):
		return(false)
	if(castling_trackers[color].has_king_rook_moved):
		return(false)
	if(!is_king_side_available(color)):
		return(false)
	var row = get_base_row(color)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(4, row))):
		return(false)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(5, row))):
		return(false)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(6, row))):
		return(false)
	return(true)

func can_castle_queen_side(color):
	if(castling_trackers[color].has_king_moved):
		return(false)
	if(castling_trackers[color].has_queen_rook_moved):
		return(false)
	if(!is_queen_side_available(color)):
		return(false)
	var row = get_base_row(color)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(4, row))):
		return(false)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(3, row))):
		return(false)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(2, row))):
		return(false)
	if(is_tile_attacked_by_color(opposite_color(color), Vector2(1, row))):
		return(false)
	return(true)

func add_castling_moves(piece_pos, color):
	var result = []
	if(can_castle_king_side(color)):
		result.append(piece_pos + Vector2(2, 0))
	if(can_castle_queen_side(color)):
		result.append(piece_pos + Vector2(-2, 0))
	return(result)

func has_move_available(color_to_move):
	for piece in piece_list:
		if(piece.color == color_to_move):
			var moves = get_possible_moves(piece.chess_pos)
			if(moves.size() != 0):
				return(true)
	return(false)

func is_current_player_checkmate():
	if(is_king_in_check(color_to_move)):
		return(!has_move_available(color_to_move))
	else:
		return(false)

func is_piece_type_present(piece_type):
	for piece in piece_list:
		if(piece.type == piece_type):
			return(true)
	return(false)

func is_bishop_present():
	return(is_piece_type_present(BISHOP))

func is_knight_present():
	return(is_piece_type_present(KNIGHT))

func get_bishops():
	var result = []
	for piece in piece_list:
		if(piece.type == BISHOP):
			result.append(piece)
	return(result)

func is_white_tile(tile):
	return((floor(tile.x) + floor(tile.y)) % 2 != 0)

func are_there_bishops_of_same_color():
	var bishops = get_bishops()
	assert(bishops.size() <= 2)
	if(bishops.size() < 2):
		return(false)
	if(bishops[0].color == bishops[1].color):
		return(false)
	return(is_white_tile(bishops[0].chess_pos) == is_white_tile(bishops[1].chess_pos))

func is_draw_combination():
	if(piece_list.size() == 2):
		# NOTE(hugo): It MUST be only two kings left
		return(true)
	if(piece_list.size() == 3):
		# NOTE(hugo): There is only one piece that is not a king
		# If it is a bishop or a knight, then it's draw.
		# Therefore, it is sufficient to check only if such
		# a piece is present on the board
		return(is_bishop_present() || is_knight_present())
	if(piece_list.size() == 4):
		return(are_there_bishops_of_same_color())
	return(false)

func is_draw():
	# NOTE(hugo): I am not checking for the fifty-move rule
	# nor for the threefold repetion. Get on with it !
	# TODO(hugo): Mutual agreement ?
	if(!is_king_in_check(color_to_move)):
		return(!has_move_available(color_to_move))
	else:
		return(is_draw_combination())

#########################################################
# NOTE(hugo): Debug
func print_state():
	print("-----------------------------")
	print("Color to move : " + str(color_to_move))
	if(pawn_that_doubled_last_move):
		print("Double pawn pos : " + str(pawn_that_doubled_last_move.chess_pos))
	else:
		print("Double pawn pos : Null")
	print("Selected : " + selected_piece.str_piece())
	print("Piece List")
	for piece in piece_list:
		print(piece.str_piece())

func debug_chess_config():
	create_piece(WHITE, QUEEN, Vector2(0, 6))
	create_piece(WHITE, KING, Vector2(4, 5))
	create_piece(BLACK, KING, Vector2(4, 7))

