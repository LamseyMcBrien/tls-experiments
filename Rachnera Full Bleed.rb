# Inspired by https://forums.rpgmakerweb.com/index.php?threads/simple-message-busts.45897/
module Busty
  CONFIG = {
    "Balia" => {
      face_offset_x: 53,
      face_offset_y: 38,
    },
    "Carina" => {
      face_offset_x: 69,
      face_offset_y: 47,
    },
    "Ginasta" => {
      face_offset_x: 61,
      face_offset_y: 42,
    },
    "Hilstara" => {
      bust_offset_x: -70,
      face_offset_x: 64,
      face_offset_y: 40,
    },
    "Nalili" => {
      bust_scale: 0.72,
      bust_offset_y: 50,
      face_offset_x: 54,
      face_offset_y: 27,
    },
    "Orilise" => {
      bust_scale: 0.71,
      face_offset_x: 58,
      face_offset_y: 34,
    },
    "Robin blond" => {
      face_offset_x: 63,
      face_offset_y: 53,
    },
    "Varia" => {
      face_offset_x: 62,
      face_offset_y: 48,
    },
  }
end
class Window_Message < Window_Base
  alias hmb_window_message_create_back_bitmap create_back_bitmap
  def create_back_bitmap
    @bust = Sprite.new if @bust.nil?
    @bust.visible = true
    @bust.z = z + 1

    @bust_face = Sprite.new if @bust_face.nil?
    @bust_face.visible = true
    @bust_face.z = @bust.z + 1

    hmb_window_message_create_back_bitmap
  end

  alias hmb_window_message_dispose dispose
  def dispose
    hmb_window_message_dispose
    dispose_bust
  end

  def dispose_bust
    @bust.dispose if !@bust.nil?
    @bust.bitmap.dispose if !@bust.bitmap.nil?

    @bust_face.dispose unless @bust_face.nil?
    @bust_face.bitmap.dispose unless @bust_face.bitmap.nil?
  end

  alias hmb_window_message_update_back_sprite update_back_sprite
  def update_back_sprite
    hmb_window_message_update_back_sprite
    update_bust if openness > 0
  end

  def update_bust
    if has_bust?
      @bust.bitmap = bust_bitmap
      @bust.x = bust_offset_x
      @bust.y = Graphics.height - @bust.height + bust_offset_y

      bitmap = Cache.face($game_message.face_name)
      rect = Rect.new($game_message.face_index % 4 * 96, $game_message.face_index / 4 * 96, 96, 96)
      face_bitmap = Bitmap.new(96, 96)
      face_bitmap.blt(0, 0, bitmap, rect)
      @bust_face.bitmap = face_bitmap
      @bust_face.x = @bust.x + face_offset_x
      @bust_face.y = @bust.y + face_offset_y
    else
      @bust.bitmap = nil
      @bust_face.bitmap = nil
    end
    @bust.update
    @bust_face.update
  end

  alias original_591_new_line_x new_line_x
  def new_line_x
    return text_indent_if_bust if has_bust?

    original_591_new_line_x
  end

  def has_bust?
    return false if $game_message.face_name.empty?

    # Don't display bust if the message box isn't at the bottom of the screen
    return false if self.y + self.height != Graphics.height

    !!bust_bitmap
  end

  def bust_bitmap
    #TODO Very basic pseudo cache, can likely be improved (or at least cleaned up)
    @busts = {} if @busts.nil?
    return @busts[character_name] if @busts.has_key?(character_name)

    begin
      @busts[character_name] = Cache.picture(character_name + ' bust')
    rescue
      begin
        @busts[character_name] = rescale_bitmap(Cache.picture(character_name), bust_scale)
      rescue
        @busts[character_name] = nil
      end
    end

    @busts[character_name]
  end

  def character_name
    # TODO Deal with non standard names
    $game_message.face_name.gsub(/\s+emo.*/, '')
  end

  def rescale_bitmap(bitmap, scale)
    width = bitmap.width * scale
    height = bitmap.height * scale
    new_bitmap = Bitmap.new(width, height)
    src_rect = Rect.new(0, 0, bitmap.width, bitmap.height)
    dest_rect = Rect.new(0, 0, width, height)
    # Ref: https://www.rubydoc.info/gems/openrgss/Bitmap#stretch_blt-instance_method
    new_bitmap.stretch_blt(dest_rect, bitmap, src_rect)
    bitmap.dispose
    new_bitmap
  end

  alias original_591_draw_face draw_face
  def draw_face(face_name, face_index, x, y, enabled = true)
    return if has_bust?
    original_591_draw_face(face_name, face_index, x, y, enabled)
  end

  def text_indent_if_bust
    125
  end

  def bust_scale
    bust_config[:bust_scale] || 0.75
  end

  def bust_offset_x
    # 51 = 1/4 of 75% of 272
    bust_config[:bust_offset_x] || -51
  end

  def bust_offset_y
    bust_config[:bust_offset_y] || 0
  end

  def face_offset_x
    bust_config[:face_offset_x] || 60
  end

  def face_offset_y
    bust_config[:face_offset_y] || 40
  end

  def bust_config
    Busty::CONFIG[character_name] || {}
  end
end
