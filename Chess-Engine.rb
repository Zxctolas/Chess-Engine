class ChessEngine
  def initialize
    @board = create_initial_board
    @current_player = :white #але валер ты расист?
    @move_history = []
    @captured_pieces = { white: [], black: [] }
    @game_state = :in_progress
  end

  def make_move(move_notation)
    return { success: false, message: "Игра уже завершена" } unless @game_state == :in_progress
    
    begin
      move = parse_move(move_notation)
      return move unless move[:success]
      
      from_pos = move[:from]
      to_pos = move[:to]

      piece = @board[from_pos[0]][from_pos[1]]
      
      validation = validate_move(piece, from_pos, to_pos)
      return validation unless validation[:success]
      
      execute_move(piece, from_pos, to_pos, move[:promotion])
      check_game_state
      
      message = case @game_state
                when :check then "Шах!"
                when :white_wins then "Белые выиграли!"
                when :black_wins then "Черные выиграли!"
                else "Ход выполнен успешно"
                end
      
      { success: true, board: @board, game_state: @game_state, message: message }
    rescue => e
      { success: false, message: "Ошибка при выполнении хода: #{e.message}" }
    end
  end

  def print_board
    puts "\nТекущая доска:"
    @board.each_with_index do |row, i|
      row_number = 8 - i
      cells = row.map { |p| p ? "#{p[:type].to_s[0].upcase}#{p[:color] == :white ? 'w' : 'b'}" : '__' }
      puts "#{row_number} #{cells.join(' ')}"
    end
    puts "   a  b  c  d  e  f  g  h"
  end

  def print_move_history
    puts "\nИстория игры:"
    @move_history.each_with_index do |move, index|
      captured = move[:captured] ? move[:captured].to_s.capitalize : 'нет'
      puts "Ход #{index + 1}:"
      puts "  Игрок: #{move[:player] == :white ? 'Белые' : 'Черные'}"
      puts "  Фигура: #{move[:piece].to_s.capitalize}"
      puts "  #{move[:from]} → #{move[:to]}"
      puts "  взятие: #{move[:captured] ? move[:captured][:type].to_s.capitalize : 'нет'}"      
      puts "-" * 40
    end
    puts "Всего ходов: #{@move_history.size}".blue
  end

  def board_state
    @board
  end

  # Получить текущего игрока
  def current_player
    @current_player
  end

  # Получить историю ходов
  def move_history
    @move_history
  end
  
  private


  def create_initial_board
    # 8x8 board, [row][col], начало с a1 в левом нижнем углу
    board = Array.new(8) { Array.new(8) }
    
    8.times do |col|
      board[1][col] = { type: :pawn, color: :black }
      board[6][col] = { type: :pawn, color: :white }
    end
    
    board[0][0] = board[0][7] = { type: :rook, color: :black }
    board[7][0] = board[7][7] = { type: :rook, color: :white }
    
    board[0][1] = board[0][6] = { type: :Night, color: :black }
    board[7][1] = board[7][6] = { type: :Night, color: :white }
    
    board[0][2] = board[0][5] = { type: :bishop, color: :black }
    board[7][2] = board[7][5] = { type: :bishop, color: :white }
    
    board[0][3] = { type: :queen, color: :black }
    board[7][3] = { type: :queen, color: :white }
    
    board[0][4] = { type: :king, color: :black }
    board[7][4] = { type: :king, color: :white }
    
    board
  end

  
  def parse_move(move_notation)
  # Примеры нотации: e2-e4, e4, Ng1-f3, O-O (рокировка), e7-e8Q (превращение)
  move_notation = move_notation.gsub(/\s+/, '')
  
  # Рокировка
  if move_notation.downcase == 'o-o' || move_notation.downcase == '0-0'
    return { success: true, castling: :kingside }
  elsif move_notation.downcase == 'o-o-o' || move_notation.downcase == '0-0-0'
    return { success: true, castling: :queenside }
  end
  
  # Обычный ход
  if move_notation =~ /^([a-h][1-8])(?:-|x)?([a-h][1-8])(=?[QRNB])?$/i
    from = chess_to_coords($1)
    to = chess_to_coords($2)
    promotion = $3 ? $3.upcase[1].to_sym : nil
    
    { success: true, from: from, to: to, promotion: promotion }
  else
    { success: false, message: "Некорректная шахматная нотация" }
  end
end

def chess_to_coords(chess_pos)
  col = chess_pos[0].downcase.ord - 'a'.ord
  row = 8 - chess_pos[1].to_i
  [row, col]
end

def coords_to_chess(coords)
  row, col = coords
  "#{('a'.ord + col).chr}#{8 - row}"
end

  def validate_move(piece, from_pos, to_pos)
    return { success: false, message: "Нет фигуры на начальной позиции" } unless piece
    return { success: false, message: "Сейчас ход #{@current_player}" } unless piece[:color] == @current_player
    
    target_piece = @board[to_pos[0]][to_pos[1]]
    if target_piece && target_piece[:color] == @current_player
      return { success: false, message: "Нельзя бить свои фигуры" }
    end
    
    unless valid_piece_move?(piece, from_pos, to_pos)
      return { success: false, message: "Недопустимый ход для #{piece[:type]}" }
    end
    
    if move_puts_king_in_check?(piece, from_pos, to_pos)
      return { success: false, message: "Недопустимый ход: король под шахом" }
    end
    
    { success: true }
  end


  def valid_piece_move?(piece, from_pos, to_pos, board = @board)
    row_from, col_from = from_pos
    row_to, col_to = to_pos
    delta_row = (row_to - row_from).abs
    delta_col = (col_to - col_from).abs
    
    case piece[:type]
    when :pawn
      direction = piece[:color] == :white ? -1 : 1
      start_row = piece[:color] == :white ? 6 : 1
      target = board[row_to][col_to]
      
      if col_from == col_to
        return false unless target.nil?
        return true if row_to == row_from + direction
        
        if row_from == start_row && row_to == row_from + 2*direction
          return board[row_from + direction][col_to].nil? && target.nil?
        end
      else
        return false unless delta_col == 1 && delta_row == 1
        return !target.nil? || en_passant_possible?(from_pos, to_pos, board)
      end
      false
      
    when :rook
      (row_from == row_to || col_from == col_to) && path_clear?(from_pos, to_pos, board)
      
    when :Night
      (delta_row == 2 && delta_col == 1) || (delta_row == 1 && delta_col == 2)
      
    when :bishop
      delta_row == delta_col && path_clear?(from_pos, to_pos, board)
      
    when :queen
      (row_from == row_to || col_from == col_to || delta_row == delta_col) && 
        path_clear?(from_pos, to_pos, board)
      
    when :king
      delta_row <= 1 && delta_col <= 1
    else
      false
    end
  end

  def path_clear?(from_pos, to_pos, board = @board)
    row_from, col_from = from_pos
    row_to, col_to = to_pos
    
    if row_from == row_to
      range = col_from < col_to ? (col_from+1...col_to) : (col_to+1...col_from)
      range.each { |col| return false if board[row_from][col] }
    elsif col_from == col_to
      range = row_from < row_to ? (row_from+1...row_to) : (row_to+1...row_from)
      range.each { |row| return false if board[row][col_from] }
    else
      row_step = row_to > row_from ? 1 : -1
      col_step = col_to > col_from ? 1 : -1
      row, col = row_from + row_step, col_from + col_step
      
      while row != row_to && col != col_to
        return false if board[row][col]
        row += row_step
        col += col_step
      end
    end
    true
  end

  def move_puts_king_in_check?(piece, from_pos, to_pos)
    temp_board = Marshal.load(Marshal.dump(@board))
    temp_board[from_pos[0]][from_pos[1]] = nil
    temp_board[to_pos[0]][to_pos[1]] = piece.dup
    
    if piece[:type] == :pawn && (to_pos[0] == 0 || to_pos[0] == 7)
      temp_board[to_pos[0]][to_pos[1]][:type] = :queen
    end
    
    in_check?(piece[:color], temp_board)
  end

  def in_check?(player, board = @board)
    king_pos = find_king_position(player, board)
    return false unless king_pos

    opponent = player == :white ? :black : :white
    
    board.each_with_index.any? do |row, row_idx|
      row.each_with_index.any? do |p, col_idx|
        next unless p && p[:color] == opponent
        valid_piece_move?(p, [row_idx, col_idx], king_pos, board)
      end
    end
  end

  def find_king_position(player, board = @board)
    board.each_with_index do |row, row_idx|
      row.each_with_index do |piece, col_idx|
        return [row_idx, col_idx] if piece && piece[:type] == :king && piece[:color] == player
      end
    end
    nil
  end

  def execute_move(piece, from_pos, to_pos, promotion = nil)
    row_from, col_from = from_pos
    row_to, col_to = to_pos
    
    move_record = {
      player: @current_player,
      from: coords_to_chess(from_pos),
      to: coords_to_chess(to_pos),
      piece: piece[:type],
      captured: @board[row_to][col_to]
    }
    
    if @board[row_to][col_to]
      @captured_pieces[@current_player] << @board[row_to][col_to]
    end
    
    if piece[:type] == :pawn && (row_to == 0 || row_to == 7)
      piece = { type: promotion || :queen, color: piece[:color] }
    end
    
    @board[row_to][col_to] = piece
    @board[row_from][col_from] = nil
    
    @move_history << move_record
    
    @current_player = @current_player == :white ? :black : :white
  end

  def check_game_state
    white_king = find_king_position(:white)
    black_king = find_king_position(:black)
    
    if !white_king
      @game_state = :black_wins
    elsif !black_king
      @game_state = :white_wins
    else
      @game_state = in_check?(@current_player == :white ? :black : :white) ? :check : :in_progress
    end
  end
end

engine = ChessEngine.new



engine.print_board
result = engine.make_move("e2-e4")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"
engine.print_board

result = engine.make_move("e7-e5")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"
engine.print_board

result = engine.make_move("d1-h5")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"
engine.print_board
result = engine.make_move("a7-a5")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"
engine.print_board
result = engine.make_move("h5-e5")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"
engine.print_board
result = engine.make_move("d8-e7")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"

board = engine.board_state
engine.print_board



puts "ИСТОРИЯ !!!!!!"
puts "\n"
engine.print_move_history
