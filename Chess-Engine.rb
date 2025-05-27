class ChessEngine
  # Инициализация новой шахматной игры
  def initialize
    @board = create_initial_board
    @current_player = :white
    @move_history = []
    @captured_pieces = { white: [], black: [] }
    @game_state = :in_progress
  end

  # Основной метод для выполнения хода
  def make_move(move_notation)
    return { success: false, message: "Игра уже завершена" } unless @game_state == :in_progress
    
    begin
      move = parse_move(move_notation)
      return move unless move[:success] # Возвращаем ошибку, если парсинг не удался
      
      from_pos = move[:from]
      to_pos = move[:to]
      piece = @board[from_pos[0]][from_pos[1]]
      
      # Проверка валидности хода
      #*Здесь проверка*
      
      # Выполнение хода
      execute_move(piece, from_pos, to_pos, move[:promotion])
      
      # Проверка состояния игры после хода
      check_game_state
      
      { success: true, board: @board, game_state: @game_state }
    rescue => e
      { success: false, message: "Ошибка при выполнении хода: #{e.message}" }
    end
  end

  # Получить текущее состояние доски
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

  def print_board
    puts "\nТекущая доска:"
    @board.each_with_index do |row, i|
      row_number = 8 - i
      # Исправлено: добавлены скобки для тернарного оператора
      cells = row.map { |p| p ? "#{p[:type].to_s[0].upcase}#{p[:color] == :white ? 'w' : 'b'}" : '__' }
      puts "#{row_number} #{cells.join(' ')}"
    end
    puts "   a  b  c  d  e  f  g  h"
  end


  private

  # Создание начальной доски
  def create_initial_board
    # 8x8 board, [row][col], начало с a1 в левом нижнем углу
    board = Array.new(8) { Array.new(8) }
    
    # Расставляем пешки
    8.times do |col|
      board[1][col] = { type: :pawn, color: :black }
      board[6][col] = { type: :pawn, color: :white }
    end
    
    # Расставляем ладьи
    board[0][0] = board[0][7] = { type: :rook, color: :black }
    board[7][0] = board[7][7] = { type: :rook, color: :white }
    
    # Расставляем коней
    board[0][1] = board[0][6] = { type: :knight, color: :black }
    board[7][1] = board[7][6] = { type: :knight, color: :white }
    
    # Расставляем слонов
    board[0][2] = board[0][5] = { type: :bishop, color: :black }
    board[7][2] = board[7][5] = { type: :bishop, color: :white }
    
    # Расставляем ферзей
    board[0][3] = { type: :queen, color: :black }
    board[7][3] = { type: :queen, color: :white }
    
    # Расставляем королей
    board[0][4] = { type: :king, color: :black }
    board[7][4] = { type: :king, color: :white }
    
    board
  end

  # Парсинг шахматной нотации (упрощенный)
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

  # Конвертация шахматных координат в индексы массива
  def chess_to_coords(chess_pos)
    col = chess_pos[0].downcase.ord - 'a'.ord
    row = 8 - chess_pos[1].to_i
    [row, col]
  end

  # Конвертация индексов массива в шахматные координаты
  def coords_to_chess(coords)
    row, col = coords
    "#{('a'.ord + col).chr}#{8 - row}"
  end



  


  # Выполнение хода
  def execute_move(piece, from_pos, to_pos, promotion = nil)
    row_from, col_from = from_pos
    row_to, col_to = to_pos
    
    # Запись хода в историю
    move_record = {
      player: @current_player,
      from: coords_to_chess(from_pos),
      to: coords_to_chess(to_pos),
      piece: piece[:type],
      captured: @board[row_to][col_to]
    }
    
    # Взятие фигуры
    if @board[row_to][col_to]
      @captured_pieces[@current_player] << @board[row_to][col_to]
    end
    
    # Превращение пешки
    if piece[:type] == :pawn && (row_to == 0 || row_to == 7)
      piece = { type: promotion || :queen, color: piece[:color] }
    end
    
    # Обновление доски
    @board[row_to][col_to] = piece
    @board[row_from][col_from] = nil
    
    # Запись хода
    @move_history << move_record
    
    # Смена игрока
    @current_player = @current_player == :white ? :black : :white
  end

  # Проверка состояния игры
  def check_game_state

    kings = { white: false, black: false }
    
    @board.each do |row|
      row.each do |piece|
        next unless piece
        kings[:white] = true if piece[:type] == :king && piece[:color] == :white
        kings[:black] = true if piece[:type] == :king && piece[:color] == :black
      end
    end
    
    @game_state = :white_wins unless kings[:black]
    @game_state = :black_wins unless kings[:white]
  end



end

engine = ChessEngine.new

# Делаем ход белых
result = engine.make_move("e2-e4")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"

# Делаем ход черных
result = engine.make_move("e7-e5")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"

# Пытаемся сделать неверный ход
result = engine.make_move("e4-e5")
puts result[:success] ? "Ход выполнен" : "Ошибка: #{result[:message]}"

# Получаем текущее состояние доски
board = engine.board_state
engine.print_board