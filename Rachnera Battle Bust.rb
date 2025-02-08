module Busty
  BATTLE_CONFIG = {} # Placeholder, actual values in "Battle Bust Config"

  class << self
    def duplicate_battle_config(equivalence)
      equivalence.each do |eq|
        base = eq[:base_character]
        evolved = eq[:evolved_character]
        search_and_replace = eq[:search_and_replace]

        next unless BATTLE_CONFIG[base]

        # Deep copy
        # The proc option is treated on its own later on
        BATTLE_CONFIG[evolved] = Marshal.load(Marshal.dump(
          BATTLE_CONFIG[base].select {|k, v| k != :proc}
        ))

        BATTLE_CONFIG[base].each do |move, config|
          if config.is_a?(String)
            BATTLE_CONFIG[evolved][move] = rec_gsub(config, search_and_replace)
          end

          if config.is_a?(Hash)
            BATTLE_CONFIG[evolved][move][:picture] = rec_gsub(config[:picture], search_and_replace)
          end

          if config.is_a?(Array)
            config.each_with_index do |cf, i|
              BATTLE_CONFIG[evolved][move][i][:picture] = rec_gsub(cf[:picture], search_and_replace)
            end
          end
        end

        if BATTLE_CONFIG[base][:proc]
          BATTLE_CONFIG[evolved][:proc] = ->(move) {
            cf = BATTLE_CONFIG[base][:proc].call(move)
            return nil unless cf

            return rec_gsub(cf, search_and_replace) if cf.is_a?(String)

            cf[:picture] = rec_gsub(cf[:picture], search_and_replace)
            cf
          }
        end
      end
    end

    def rec_gsub(original, search_and_replace)
      return original unless search_and_replace

      replaced = original.dup
      search_and_replace.each do |search, replace|
        replaced.gsub!(search, replace)
      end
      replaced
    end

    def show_enemy_face_window(bitmap, offset_x = 0, offset_y = 0)
      unless defined?(@@enemy_face_window) && @@enemy_face_window
        @@enemy_face_window = Enemy_Face_Window.new
      end
      @@enemy_face_window.set_bitmap(bitmap, offset_x, offset_y)
      @@enemy_face_window.show
    end

    def hide_enemy_face_window
      return unless defined?(@@enemy_face_window) && @@enemy_face_window

      @@enemy_face_window.clear_bitmap
      @@enemy_face_window.hide
    end

    def dispose_enemy_face_window
      return unless defined?(@@enemy_face_window) && @@enemy_face_window

      @@enemy_face_window.dispose
      @@enemy_face_window = nil
    end
  end

  class Enemy_Face_Window < Window_Base
    def initialize
      super(0, Graphics.height - window_height, window_width, window_height)

      @enemy_pic = Sprite.new
      @enemy_pic.z = z + 1
      @enemy_pic.visible = true
    end

    def set_bitmap(bitmap, offset_x = 0, offset_y = 0)
      @enemy_pic.x = x + 12 + 4 + offset_x # +4 because not a perfect square, cf window_width
      @enemy_pic.y = y + 12 + offset_y
      @enemy_pic.bitmap = bitmap
    end

    def clear_bitmap
      @enemy_pic.bitmap.dispose if @enemy_pic.bitmap
    end

    def dispose
      # Might be overkill; but better safe than sorry
      clear_bitmap
      @enemy_pic.dispose
      @enemy_pic = nil

      super
    end

    def window_height
      96 + 12*2
    end

    def window_width
      window_height + 4*2
    end
  end
end

module SkillHelper
  class << self
    # A move can be either an instance of https://www.rubydoc.info/gems/rpg-maker-rgss3/RPG/Skill or of https://www.rubydoc.info/gems/rpg-maker-rgss3/RPG/Item
    # In all cases, it has access to all properties of their common parent: https://www.rubydoc.info/gems/rpg-maker-rgss3/RPG/UsableItem

    def is_item(move)
      move.is_a?(RPG::Item)
    end

    def is_skill(move)
      move.is_a?(RPG::Skill)
    end
  end
end

class Scene_Battle < Scene_Base
  # See Yanfly Engine Ace - Ace Battle Engine
  # Note: TLS does not apparently use any of YEA-CastAnimations, YEA-LunaticObjects, YEA-TargetManager. Left their code in nonetheless for simpler diff  with original.
  alias original_478_use_item use_item
  def use_item
    return original_478_use_item if bust_feature_disabled?

    # New: Ensure status_window position is right even if we skip turn_start
    # (case of actions happening outside of turns)
    offset_right_status_window

    # Original, no change
    item = @subject.current_action.item
    @log_window.display_use_item(@subject, item)
    @subject.use_item(item)
    status_redraw_target(@subject)
    if $imported["YEA-LunaticObjects"]
      lunatic_object_effect(:before, item, @subject, @subject)
    end
    process_casting_animation if $imported["YEA-CastAnimations"]
    targets = @subject.current_action.make_targets.compact rescue []

    # New
    if show_bust?
      display_bust
      send_bust_to_background if move_config[:instant_gray]
      if can_safely_hide_status_window?(item)
        hide_status_window
      else
        @status_window.show
      end
      instant_skill_custom_offset if item.instant
    else
      @status_window.show
      display_enemy_bust if @subject.is_a?(Game_Enemy)
      if @subject.is_a?(Game_Actor)
        if @actor_command_window.openness == 0 # Don't show anything if we are in the skill menu (i.e. this is an instant skill)
          display_npc_face
        end
      end
    end

    # Original, no change
    show_animation(targets, item.animation_id) if show_all_animation?(item)
    targets.each {|target|
    if $imported["YEA-TargetManager"]
      target = alive_random_target(target, item) if item.for_random?
    end
    item.repeats.times { invoke_item(target, item) } }
    if $imported["YEA-LunaticObjects"]
      lunatic_object_effect(:after, item, @subject, @subject)
    end

    # New
    # Is a noop if everything was already cleaned in show_animation
    cleanup_bust
    instant_skill_custom_reset
  end

  alias original_478_show_animation show_animation
  def show_animation(targets, animation_id)
    original_478_show_animation(targets, animation_id)

    return if bust_feature_disabled?

    if show_bust? && !keep_bust_around?
      # Make the image less obstrusive but don't remove it entirely for smoother transition
      send_bust_to_background
    end

    if move_effects_require_showing_status_window?(@subject.current_action.item)
      @status_window.show
    end
  end

  def display_bust
    @bust_picture = Sprite.new if !@bust_picture

    @bust_picture.bitmap = Cache.picture('battle/' + move_config[:picture])
    @bust_picture.visible = true
    @bust_picture.tone.red = 0
    @bust_picture.tone.green = 0
    @bust_picture.tone.blue = 0
    @bust_picture.tone.gray = 0

    @bust_picture.z = 999
    @bust_picture.x = bust_offset_x
    @bust_picture.y = Graphics.height - @bust_picture.height + bust_offset_y
  end

  def display_enemy_bust
    rescaled_enemy_bitmap = enemy_bitmap_96_x_96

    if rescaled_enemy_bitmap.height < 96 # No crop, but recenter
      Busty::show_enemy_face_window(
        rescaled_enemy_bitmap,
        (96 - rescaled_enemy_bitmap.width) / 2,
        (96 - rescaled_enemy_bitmap.height) / 2
      )
    else # Crop
      rescaled_and_cropped_enemy_bitmap = Bitmap.new(rescaled_enemy_bitmap.width, 96 + 6) # Allow to touch the bottom border
      rescaled_and_cropped_enemy_bitmap.blt(0, 0, rescaled_enemy_bitmap, Rect.new(0, 0, rescaled_enemy_bitmap.width, 96 + 6))
      rescaled_enemy_bitmap.dispose

      Busty::show_enemy_face_window(
        rescaled_and_cropped_enemy_bitmap,
        (96 - rescaled_and_cropped_enemy_bitmap.width) / 2,
        0
      )
    end
  end

  def enemy_bitmap_96_x_96
    enemy_bitmap = Cache.battler(@subject.battler_name, @subject.battler_hue)

    return enemy_bitmap.clone if enemy_bitmap.width <= 96

    rescaled_enemy_bitmap = Bitmap.new(96, (96.0 / enemy_bitmap.width) * enemy_bitmap.height)
    src_rect = Rect.new(0, 0, enemy_bitmap.width, enemy_bitmap.height)
    dest_rect = Rect.new(0, 0, rescaled_enemy_bitmap.width, rescaled_enemy_bitmap.height)
    rescaled_enemy_bitmap.stretch_blt(dest_rect, enemy_bitmap, src_rect)

    rescaled_enemy_bitmap
  end

  def display_npc_face
    # Effectively works like an enemy, but with the NPC face instead of a resized battler
    bitmap = Cache.face(@subject.face_name)
    rect = Rect.new(
      @subject.face_index % 4 * 96,
      @subject.face_index / 4 * 96,
      96,
      96
    )
    face_bitmap = Bitmap.new(96, 96)
    face_bitmap.blt(0, 0, bitmap, rect)

    Busty::show_enemy_face_window(face_bitmap)
  end

  def cleanup_bust
    Busty::hide_enemy_face_window

    if @bust_picture
      @bust_picture.bitmap = nil unless show_bust? && keep_bust_around?
    end
  end

  alias original_478_turn_start turn_start
  def turn_start
    return original_478_turn_start if bust_feature_disabled?

    offset_right_status_window

    original_478_turn_start
  end

  alias original_478_turn_end turn_end
  def turn_end
    return original_478_turn_end if bust_feature_disabled?

    reset_status_window

    original_478_turn_end
  end

  alias original_478_terminate terminate
  def terminate
    Busty::dispose_enemy_face_window

    if @bust_picture
      @bust_picture.dispose
      @bust_picture.bitmap.dispose if @bust_picture.bitmap
    end

    original_478_terminate
  end

  def bust_feature_disabled?
    $game_switches[YEA::SYSTEM::CUSTOM_SWITCHES[:hide_battle_bust][0]]
  end

  def show_bust?
    # Only for party members, not enemies
    return false unless @subject.is_a?(Game_Actor)

    return false unless current_move_name

    # Commit to the bit by showing Simon as a NPC at first (25 is the "Window Break" switch)
    return false if character_name == "Simon1" and not $game_switches[25]

    !!move_config
  end

  def move_config
    return nil if character_name.nil? or current_move_name.nil? or Busty::BATTLE_CONFIG[character_name].nil?

    raw_config = raw_move_config

    return nil unless raw_config

    return { picture: raw_config } if raw_config.is_a?(String)

    return nil unless raw_config[:picture] # Invalid config

    raw_config
  end

  def raw_move_config
    character_config = Busty::BATTLE_CONFIG[character_name]

    return character_config[current_move_name] if character_config.has_key?(current_move_name)

    if SkillHelper.is_item(@subject.current_action.item) && character_config["Item"]
      return character_config["Item"]
    end

    proc_config = (character_config[:proc] || ->(move) { nil }).call(@subject.current_action.item)
    return proc_config if proc_config

    nil
  end

  def current_move_name
    return nil unless @subject.current_action && @subject.current_action.item

    # Trimming because some moves have invisible spaces in them (ex: "Shield of Purity ")
    @subject.current_action.item.name.strip
  end

  def character_name
    character_name = Busty::character_from_face(@subject.face_name, @subject.face_index)
  end

  def bust_offset_x
    move_config[:bust_offset_x] || bust_config[:bust_offset_x] || 0
  end

  def bust_offset_y
    move_config[:bust_offset_y] || bust_config[:bust_offset_y] || 0
  end

  def bust_config
    Busty::BATTLE_CONFIG[character_name] || {}
  end

  def offset_right_status_window
    @status_window.x = 128+16*4
  end

  def reset_status_window
    @status_window.show
    @status_window.x = 128
  end

  def instant_skill_custom_offset
    @original_info_viewport_ox = @info_viewport.ox
    @info_viewport.ox = 64
    @actor_command_window.hide
  end

  def instant_skill_custom_reset
    return unless @original_info_viewport_ox

    @info_viewport.ox = @original_info_viewport_ox
    @original_info_viewport_ox = nil
    @actor_command_window.show
  end

  alias original_478_update_info_viewport update_info_viewport
  def update_info_viewport
    # Ensure we reset even if we skip turn_end
    # (case of actions happening outside of turns)
    reset_status_window if @actor_command_window.active

    original_478_update_info_viewport
  end

  def hide_status_window
    @status_window.hide

    # Clean popus lying around where the window was
    @spriteset.actor_sprites.each do |battler_sprite|
      (battler_sprite.popups || []).each do |popup|
        popup.force_fade
      end
    end
  end

  def can_safely_hide_status_window?(move)
    return false unless $game_system.animations?

    # Healing/buff have animations centered on characters
    return false unless move.for_opponent?

    true
  end

  def move_effects_require_showing_status_window?(move)
    return true unless move.damage.type == 1 # Standard HP damage

    false
  end

  def send_bust_to_background
    @bust_picture.z = 2
    @bust_picture.tone.red = -64
    @bust_picture.tone.green = -64
    @bust_picture.tone.blue = -64
    @bust_picture.tone.gray = 128
  end

  # Used for skills that are made of several skills chained together
  def keep_bust_around?
    move_config[:chained]
  end
end

class Game_Actor < Game_Battler
  # Make screen_x relative to status_window.x instead of a hardcoded 128
  def screen_x
    return 0 unless SceneManager.scene_is?(Scene_Battle)
    status_window = SceneManager.scene.status_window
    return 0 if status_window.nil?
    item_rect_width = (status_window.width-24) / $game_party.max_battle_members
    ext = SceneManager.scene.info_viewport.ox
    rect = SceneManager.scene.status_window.item_rect(self.index)
    return SceneManager.scene.status_window.x + 12 + rect.x + item_rect_width / 2 - ext
  end
end

class Window_BattleLog < Window_Selectable
  # Keep background in sync with window position
  alias original_478_update update
  def update
    original_478_update

    @back_sprite.x = x
    @back_sprite.y = y
  end
end

class Sprite_Popup < Sprite_Base
  def force_fade
    @full = 0
  end
end

# Pseudo "flex space-evenly" when team is small
class Window_BattleStatus < Window_Selectable
  alias yanfly_478_item_rect item_rect
  def item_rect(index)
    rect = yanfly_478_item_rect(index)

    if $game_party.members.size < $game_party.max_battle_members
      spacing = (contents.width - $game_party.members.size * rect.width) / ($game_party.members.size + 1)
      rect.x = spacing + index * (rect.width + spacing)
    end

    rect
  end
end

module RPG
  class UsableItem < BaseItem
    # Circumvent space related issue
    def c_name
      name.strip
    end
  end
end

#  Custom skill description
class Window_SkillList < Window_Selectable
  alias original_828_update_help update_help
  def update_help
    return original_828_update_help unless SceneManager.scene.is_a?(Scene_Battle)

    @help_window.set_line_number(2) # Restore default

    original_828_update_help

    if SkillHelper::is_skill(item) && [
      YEA::REGEXP::SKILL::COOLDOWN,
      YEA::REGEXP::SKILL::LIMITED_USES,
      YEA::REGEXP::SKILL::WARMUP,
    ].any? {|regexp| regexp.match(item.note) }
      @help_window.set_dynamic_text_for_restricted_skills(item, @actor)
    end
  end
end

class Window_BattleHelp < Window_Help
  def set_dynamic_text_for_restricted_skills(item, actor)
    special = []

    info_prefix = "\\C[8]‣ "
    warning_prefix = "\\C[20]◦ "
    danger_prefix = "\\C[10]⁃ "

    if YEA::REGEXP::SKILL::WARMUP.match(item.note)
      remaining_time = actor.warmup?(item) - $game_troop.turn_count

      if remaining_time > 0
        txt =
          if remaining_time > 1
            "Warming up, ready in #{remaining_time} turns"
          else
            "Warming up, ready next turn"
          end

        special.push(warning_prefix + txt)
      end
    end

    if YEA::REGEXP::SKILL::COOLDOWN.match(item.note)
      total_cooldown = $1.to_i
      current_cooldown = actor.cooldown?(item)

      txt =
        if current_cooldown > 0
          warning_prefix + "Cooling down, ready again #{current_cooldown > 1 ? "in #{current_cooldown} turns" : "next turn"}"
        else
          info_prefix + "After use: #{total_cooldown} turn#{total_cooldown > 1 ? "s": ""} cooldown"
        end

      special.push(txt)
    end

    if YEA::REGEXP::SKILL::LIMITED_USES.match(item.note)
      total_uses = $1.to_i
      remaining_uses = total_uses - actor.times_used?(item)

      if remaining_uses > 0
        txt =
          if total_uses == 1
            "Limited to one use per battle"
          else
            "Limited to #{total_uses} uses per battle (#{remaining_uses} remaining)"
          end
        special.push(info_prefix + txt)
      else
        # Special: If the skill is fully exhausted, overwrite all now useless data about cooldown/warmup
        special = [
          danger_prefix + "Cannot be used any more this battle"
        ]
      end
    end

    # Remove existing (Limited X), (Cooldown Y)... from description, as well as eventual now unnecessary line breaks at the end
    description = item.description.gsub(/\s+(\(Cooldown [0-9]+\))|(\(Warmup [0-9]+\))|(\(Limited [0-9]+\))/, '').strip

    # RPGMaker doesn't do automated line breaks for skills, so this is somewhat reliable
    guessed_description_lines_count = 1 + description.scan(/\n/).count

    set_line_number([guessed_description_lines_count + special.count, 2].max)
    set_text(description + "\n" + "\\}" + special.join("\n"))
  end

  def set_line_number(line_number)
    new_height = fitting_height(line_number)

    return if new_height == self.height

    self.height = new_height
    create_contents # Force height update of the text container; without it, still constrained by the previous value
  end
end

# See Yanfly core engine - Adjust Animation Speed for equivalence in FPS
class Sprite_Battler < Sprite_Base
  alias yanfly_478_set_animation_rate set_animation_rate
  def set_animation_rate
    if !SceneManager.scene.is_a?(Scene_Battle) || SceneManager.scene.bust_feature_disabled?
      return yanfly_478_set_animation_rate
    end

    # Max animation speed for enemies
    # FIXME Remove before release?
    if SceneManager.scene.subject.is_a?(Game_Enemy)
      @ani_rate = 1
      return
    end

    @ani_rate = 4
  end
end

# Larger skill window so numbers don't get atop words
class Scene_Battle < Scene_Base
  alias original_522_create_skill_window create_skill_window
  def create_skill_window
    original_522_create_skill_window
    @skill_window.width = Graphics.width
  end

  alias original_522_create_battle_status_aid_window create_battle_status_aid_window
  def create_battle_status_aid_window
    original_522_create_battle_status_aid_window
    @status_aid_window.x = 9999 # Just move offscreen, will you?
  end

  alias original_522_create_actor_window create_actor_window
  def create_actor_window
    original_522_create_actor_window
    @actor_window.x = (Graphics.width - @actor_window.width)/2
  end
end

YEA::SYSTEM::CUSTOM_SWITCHES.merge!({
  hide_battle_bust: [
    14, # Switch Number; make sure it's not used for something else
    "Busts in battles",
    "Hide",
    "Show",
    "Show party members in big when they act in battle.",
    true
  ]
})
YEA::SYSTEM::COMMANDS.insert(YEA::SYSTEM::COMMANDS.find_index(:animations)+1, :hide_battle_bust)
class Scene_System < Scene_MenuBase
  alias_method :original_297_command_reset_opts, :command_reset_opts
  def command_reset_opts
    $game_switches[YEA::SYSTEM::CUSTOM_SWITCHES[:hide_battle_bust][0]] = false

    original_297_command_reset_opts
  end
end
