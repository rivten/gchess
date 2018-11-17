extends Node2D

enum PieceColor {WHITE, BLACK}
enum PieceType {KING, QUEEN, ROOK, KNIGHT, BISHOP, PAWN}

const PieceColorName = ["White", "Black"]
const PieceTypeName = ["King", "Queen", "Rook", "Knight", "Bishop", "Pawn"]

#####################################################
# {
class Piece extends Node2D:
	var color;
	var type;
	var chess_pos;

	func chess_pos_to_absolute(chess_pos):
		var offset = Vector2(0.5 * TILE_SIZE, -0.5 * TILE_SIZE)
		return(Vector2(TILE_SIZE * chess_pos.x, TILE_SIZE * (8 - chess_pos.y)) + offset)

	func _init(piece_color, piece_type, piece_pos):
		color = piece_color;
		type = piece_type;
		chess_pos = piece_pos;
		position = chess_pos_to_absolute(chess_pos)
		var sprite = Sprite.new();
		sprite.texture = load("res://data/images/" + PieceColorName[piece_color] + PieceTypeName[piece_type] + ".png")
		add_child(sprite)

	func move_to(tile):
		chess_pos = tile
		position = chess_pos_to_absolute(chess_pos)
# }
#####################################################

const TILE_SIZE = 64.0
const color_white = Color(1.0, 1.0, 1.0, 1.0)
const color_green = Color(64.0 / 255.0, 146.0 / 255.0, 59.0 / 255.0)
const color_highlight = Color(0.0, 0.0, 1.0, 0.0)

var highlighted_tiles = []
var selected_piece = null
var color_to_move = WHITE
var pawn_that_doubled_last_move = null

func create_chessboard():
	for i in range(8):
		add_child(Piece.new(BLACK, PAWN, Vector2(i, 6)))
		add_child(Piece.new(WHITE, PAWN, Vector2(i, 1)))

	add_child(Piece.new(WHITE, ROOK, Vector2(0, 0)))
	add_child(Piece.new(WHITE, ROOK, Vector2(7, 0)))
	add_child(Piece.new(BLACK, ROOK, Vector2(0, 7)))
	add_child(Piece.new(BLACK, ROOK, Vector2(7, 7)))

	add_child(Piece.new(WHITE, KNIGHT, Vector2(1, 0)))
	add_child(Piece.new(WHITE, KNIGHT, Vector2(6, 0)))
	add_child(Piece.new(BLACK, KNIGHT, Vector2(1, 7)))
	add_child(Piece.new(BLACK, KNIGHT, Vector2(6, 7)))

	add_child(Piece.new(WHITE, BISHOP, Vector2(2, 0)))
	add_child(Piece.new(WHITE, BISHOP, Vector2(5, 0)))
	add_child(Piece.new(BLACK, BISHOP, Vector2(2, 7)))
	add_child(Piece.new(BLACK, BISHOP, Vector2(5, 7)))

	add_child(Piece.new(WHITE, QUEEN, Vector2(4, 0)))
	add_child(Piece.new(BLACK, QUEEN, Vector2(4, 7)))
	add_child(Piece.new(WHITE, KING, Vector2(3, 0)))
	add_child(Piece.new(BLACK, KING, Vector2(3, 7)))

func _ready():
	create_chessboard()

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

func is_highlighted(tile):
	for t in highlighted_tiles:
		if t == tile:
			return(true)
	return(false)

func move_piece(to_tile):
	var taken_piece = get_piece_at_tile(to_tile)
	if(taken_piece != null):
		remove_child(taken_piece)
	else:
		# NOTE(hugo): check if the taken piece is en passant
		if(pawn_that_doubled_last_move && abs(pawn_that_doubled_last_move.chess_pos.x - selected_piece.chess_pos.x) == 1 && abs(pawn_that_doubled_last_move.chess_pos.y - selected_piece.chess_pos.y) == 0):
			remove_child(pawn_that_doubled_last_move)

	if(selected_piece.type == PAWN && abs(selected_piece.chess_pos.y - to_tile.y) == 2):
		pawn_that_doubled_last_move = selected_piece
	else:
		pawn_that_doubled_last_move = null

	selected_piece.move_to(to_tile)
	color_to_move = opposite_color(color_to_move)
	highlighted_tiles = []

func display_possible_moves(tile_clicked):
	selected_piece = get_piece_at_tile(tile_clicked)
	highlighted_tiles = []
	if(selected_piece && selected_piece.color == color_to_move):
		highlighted_tiles += get_possible_moves(selected_piece)

func _input(event):
	if event is InputEventMouseButton:
		var tile_clicked = get_tile_clicked(event.position)
		if(is_highlighted(tile_clicked)):
			move_piece(tile_clicked)
		else:
			display_possible_moves(tile_clicked)
		update()

func get_tile_clicked(mouse_pos):
	var rel_pos = mouse_pos - position
	return(Vector2(floor(rel_pos.x / TILE_SIZE), 7 - floor(rel_pos.y / TILE_SIZE)))

func get_piece_at_tile(tile):
	for child in get_children():
		if child.chess_pos == tile:
			return(child)
	return(null)

func get_possible_moves(piece):
	#var result = [piece.chess_pos]
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
	return result

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
	# TODO(hugo): castling
	return(result)

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

func add_pos_if_no_piece(tile):
	if(is_free_tile(tile)):
		return([tile])
	return([])

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
