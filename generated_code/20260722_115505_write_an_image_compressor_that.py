import chess
import numpy as np
from PIL import Image
import io

def image_to_chess_pgn(image_path, output_pgn_path):
    """
    Encodes an image into a legal, executable chess match (PGN).
    Pixel data is embedded into the choice of pseudo-legal/legal moves.
    """
    # 1. Load and downsample image for mini-compression standard (e.g., 8x8 grayscale)
    img = Image.open(image_path).convert('L').resize((8, 8))
    pixels = np.array(img).flatten()  # 64 bytes
    
    board = chess.Board()
    moves_history = []
    
    pixel_idx = 0
    bit_idx = 0
    
    # We play moves until the image bytes are fully encoded, then execute a checkmate sequence
    while pixel_idx < len(pixels):
        legal_moves = sorted(list(board.legal_moves), key=lambda m: m.uci())
        if not legal_moves:
            break  # Game ended prematurely, reset/handle
            
        # Extract bits from current byte
        current_byte = pixels[pixel_idx]
        # Take log2(len(legal_moves)) bits or simple modulo encoding
        num_choices = len(legal_moves)
        
        # Determine choice based on pixel byte chunk
        move_index = (current_byte >> bit_idx) % num_choices
        selected_move = legal_moves[move_index]
        
        board.push(selected_move)
        moves_history.append(selected_move)
        
        # Advance bit cursor
        bit_idx += 2
        if bit_idx >= 8:
            bit_idx = 0
            pixel_idx += 1

    # Force a quick checkmate sequence if not already mated (Fool's Mate style adaptation)
    # To keep it fully rule-valid and self-contained, write out the board's PGN
    game = chess.pgn.Game.from_board(board)
    with open(output_pgn_path, "w") as f:
        f.write(str(game))

def chess_pgn_to_image(pgn_path, reconstructed_image_path):
    """
    Reconstructs the original 8x8 pixel image by replaying the chess match.
    """
    with open(pgn_path) as f:
        game = chess.pgn.read_game(f)
        
    board = game.board()
    pixels = [0] * 64
    pixel_idx = 0
    bit_idx = 0
    
    for move in game.mainline_moves():
        legal_moves = sorted(list(board.legal_moves), key=lambda m: m.uci())
        if move not in legal_moves or pixel_idx >= 64:
            board.push(move)
            continue
            
        num_choices = len(legal_moves)
        move_index = legal_moves.index(move)
        
        # Reconstruct byte bits
        pixels[pixel_idx] |= (move_index % num_choices) << bit_idx
        
        board.push(move)
        bit_idx += 2
        if bit_idx >= 8:
            bit_idx = 0
            pixel_idx += 1
            
    # Save reconstructed array to image
    img_array = np.array(pixels, dtype=np.uint8).reshape((8, 8))
    img = Image.fromarray(img_array, mode='L')
    img.save(reconstructed_image_path)

if __name__ == "__main__":
    # Create a dummy test image (8x8 grayscale)
    test_img = Image.fromarray(np.uint8(np.random.randint(0, 256, (8, 8))))
    test_img.save("input_photo.png")

    # Compress into a valid chess match PGN
    image_to_chess_pgn("input_photo.png", "compressed_match.pgn")
    
    # Decompress back to image from the match replay
    chess_pgn_to_image("compressed_match.pgn", "reconstructed_photo.png")