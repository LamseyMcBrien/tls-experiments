# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# VN-style Backlog by Lord Forte
# Author: Lord Forte
# Credits / Original: Soulpour777, Sui
# Includes components of Word Wrap script from KilloZapit
# Significant edits and reworking to the parts that move by Lord Forte
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Description: Creates a message log of all present messages. They are stored
# and can be viewed anytime. Messages from Events, Battles, and Choices are
# shown through the press of a button.
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Controls:
# Press Up and Down to Scroll Messages.
# Press Assigned Button to Open the Message Log
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# ----------------------------------------------------------------------------
# Script Calls:
#
# $game_system.change_choice_saving(false) - will not save choices.
# $game_system.change_choice_saving(true) - will save choices
# 
# $game_system.change_message_rows(value)
# Place the value on the argument for the new max rows: for example:
#
# $game_system.change_message_rows(50)
# This will give me maximum of 50 rows. Note that the excess logs will be
# deleted to store the new ones.
# ----------------------------------------------------------------------------
module SceneManager
  #--------------------------------------------------------------------------
  # * Execute
  #--------------------------------------------------------------------------
  class << self
    alias run_reset_base run
  end
  
  def self.run
    Soulpour777::Animated_Log::Animated_Log.clear
    self.run_reset_base
  end
end
#==============================================================================
# ** Soulpour777 [Animated Log]
#------------------------------------------------------------------------------
#  This module carries the name of the scripter as well as the three important
# things for the whole script's functions, the switch, the button and the 
# parallax background.
#==============================================================================
module Soulpour777
  module Animated_Log

    # Display MessageLog Button Key
    Message_Log_Button_Mode = Input::Z # Button D on your Keyboard

    
  end
end

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Window Message
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
class Window_Message < Window_Base
  #--------------------------------------------------------------------------
  # * Process All Text
  #--------------------------------------------------------------------------
  alias soul_process_all_text process_all_text
  def process_all_text
    if $game_message.face_name != ""
      log = convert_escape_characters($game_message.all_text)
      Soulpour777::Animated_Log.push([log, true, $game_message.face_name, $game_message.face_index]) 
    else
      log = convert_escape_characters($game_message.all_text)
      Soulpour777::Animated_Log.push([log, false, "", 0]) 
    end
    soul_process_all_text
  end
end

#==============================================================================
# ** Game_System
#------------------------------------------------------------------------------
#  This class handles system data. It saves the disable state of saving and 
# menus. Instances of this class are referenced by $game_system.
#==============================================================================

class Game_System
  # ----------------------------------------------------------------------
  # Initializes an attribute accessor so players can access max rows 
  # and choice saving anytime.
  # ----------------------------------------------------------------------
  attr_accessor :save_choices
  attr_accessor :max_rows_for_message
  # ----------------------------------------------------------------------
  
  # ----------------------------------------------------------------------
  # Alias Listings
  # ----------------------------------------------------------------------
  alias choice_initialize initialize
  # ----------------------------------------------------------------------
  
  # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  # Initialize (aliased)
  # This stores both choices and max rows that enables the developer to
  # change it everytime he / she wants to.
  # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  def initialize
    choice_initialize() # Call Original Method
    @save_choices = false
    @max_rows_for_message = 50
  end
  
  # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= 
  # Choice Saving
  # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= 
  def change_choice_saving(choice_save)
    @save_choices = choice_save
  end
  
  # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= 
  # Message Rows
  # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= 
  def change_message_rows(new_rows)
    @max_rows_for_message = new_rows
  end
  
  
end

#==============================================================================
# ** Window_ChoiceList
#------------------------------------------------------------------------------
#  This window is used for the event command [Show Choices].
#==============================================================================
class Window_ChoiceList < Window_Command
  #--------------------------------------------------------------------------
  # * Create Command List
  #--------------------------------------------------------------------------
  alias soul_mcl make_command_list
  def make_command_list
    soul_mcl
    return unless $game_system.save_choices
    log = ""
    $game_message.choices.each do |choice|
      next if choice.empty?
      log += "  " + choice + "\n"
    end
    return if log.empty?
    Soulpour777::Animated_Log.push([log, false, "", 0])
  end
end


module Soulpour777::Animated_Log
  Animated_Log = []
  #--------------------------------------------------------------------------
  # Push Text (Add)
  #--------------------------------------------------------------------------
  def self.push(array)
    Animated_Log.push(array)
    if $game_system.max_rows_for_message.nil?
      $game_system.max_rows_for_message = 50
    end
    Animated_Log.shift if Animated_Log.size > $game_system.max_rows_for_message
  end
end

#==============================================================================
# ** Window_MessageLog
#------------------------------------------------------------------------------
#  This message window is used to display the messages. [Window_Base]
#==============================================================================

class Window_MessageLog < Window_Base
  #--------------------------------------------------------------------------
  # Initialize
  #--------------------------------------------------------------------------
  def initialize
    super(0, 0, Graphics.width, Graphics.height)
    self.z = 250
    self.opacity = 255
    #self.active = false
     self.active = true
    self.openness = 0
    @index = 0
    #create_animated_bg
    open
    refresh
  end
  
  #def contents_height
    #height - standard_padding * 2
   # 50 * line_height * 4
 # end
  
  #--------------------------------------------------------------------------
  # Dispose
  #--------------------------------------------------------------------------
  def dispose
    super
#    @back.bitmap.dispose
 #   @back.dispose
  end

  #--------------------------------------------------------------------------
  # Update Parallax
  #--------------------------------------------------------------------------  
  def update_anime
    #@back.ox += 2
  end
  
  #--------------------------------------------------------------------------
  # Update
  #--------------------------------------------------------------------------
  def update
    super
    update_anime
    return if @opening || @closing
    dispose if close?
    if !self.disposed? && self.open?
      if Input::trigger?(:B)
        Sound.play_cancel
        close
      elsif Input::repeat?(:UP)
        self.index = @index - 1
      elsif Input::repeat?(:DOWN)
        self.index = @index + 1
      elsif Input::repeat?(:LEFT)
        self.index = @index - 5
      elsif Input::repeat?(:RIGHT)
        self.index = @index + 5
      elsif Input::repeat?(:L)
        self.index = @index - 15
      elsif Input::repeat?(:R)
        self.index = @index + 15
      end
    end
  end
  
  #--------------------------------------------------------------------------
  # Row Max
  #--------------------------------------------------------------------------
  def page_row_max
    contents_height / line_height
  end
  
  #--------------------------------------------------------------------------
  # Index
  #--------------------------------------------------------------------------
  def index=(row)
    @index = [[row, @row_max - page_row_max + 1].min, 0].max
    self.oy = @index * line_height
  end
  
  #--------------------------------------------------------------------------
  # Create Parallax
  #--------------------------------------------------------------------------
  def create_animated_bg
    @back = Plane.new
    @back.ox = 0
    @back.oy = 0
    @back.z = self.z - 1
    @back.bitmap = Cache.picture(Soulpour777::Animated_Log::Parallax_Name)
  end
  
  #--------------------------------------------------------------------------
  # Push Text
  #--------------------------------------------------------------------------
  def push(text)
    Soulpour777::Animated_Log::Animated_Log.push([text, false, "", 0])
    Soulpour777::Animated_Log::Animated_Log.shift if Soulpour777::Animated_Log::Animated_Log.size > $game_system.max_rows_for_message
  end
  
  #--------------------------------------------------------------------------
  # Create Log Contents
  #--------------------------------------------------------------------------
  def create_log_contents(size)
    self.contents.dispose
    self.contents = Bitmap.new(width - padding * 2, [height - padding * 2, size * line_height].max)
  end
  
  #--------------------------------------------------------------------------
  # ? Convert Special Characters
  #--------------------------------------------------------------------------
  def convert_special_characters(text)
    text.gsub!(/\e.\[.+\]/)        { "" }
    text.gsub!(/\e./)              { "" }
    text
  end
  
   #--------------------------------------------------------------------------
  # Word Size Method from KilloZapit
  #--------------------------------------------------------------------------

  
    def get_next_word_size(c, text)
    # Split text by the next space/line/page and grab the first split
    nextword = text.split(/[\s\n\f]/, 2)[0]
    if nextword
      icons = 0
      if nextword =~ /\e/i
        # Get rid of color codes and YEA Message system outline colors
        nextword = nextword.split(/\e[oOcC]+\[\d*\]/).join
        # Get rid of message timing control codes
        nextword = nextword.split(/\e[\.\|\^<>!]/).join
        # Split text by the first non-icon escape code
        # (the hH is for compatibility with the Icon Hues script)
        nextword = nextword.split(/\e[^iIhH]+/, 2)[0]
        # Erase and count icons in remaining text
        nextword.gsub!(/\e[iIhH]+\[[\d,]*\]/) do
          icons += 1
          ''
        end if nextword
      end
      wordsize = (nextword ? text_size(c + nextword).width : text_size( c ).width)
      wordsize += icons * 24
    else
      wordsize = text_size( c ).width
    end
    return wordsize
  end
  
  #--------------------------------------------------------------------------
  # Refresh
  #--------------------------------------------------------------------------

  def refresh
    y = 0
    adjust = 0
    texts_test = []
    size = 0
    @right_margin = 0
    #texts_faces = []
    for i in 0...Soulpour777::Animated_Log::Animated_Log.size
      if i > 0
        y += line_height
        size += line_height
      end
      old_y = y
      text = Soulpour777::Animated_Log::Animated_Log[i][0]
      if Soulpour777::Animated_Log::Animated_Log[i][1] == true
          #draw_face(Soulpour777::Animated_Log::Animated_Log[i][2], Soulpour777::Animated_Log::Animated_Log[i][3], 0, y)
      end
      reset_font_settings
      text = convert_escape_characters(text)
      if Soulpour777::Animated_Log::Animated_Log[i][1] == true
        pos = {:x => 104, :y => y, :new_x => 104, :height => calc_line_height(text)}
        @right_margin = 0
      #process_character(text.slice!(0, 1), text, pos) until text.empty?
      @lastc = "\n"
        until text.empty? do 
          c = text.slice!(0, 1)
          c = ' ' if c == "\n"
          if c =~ /[ \t]/
            c = '' if @lastc =~ /[\s\n\f]/
            if pos[:x] + get_next_word_size(c, text) > contents.width - @right_margin
              process_new_line(text, pos)
            else
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              #self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
            @lastc = c
          else
            @lastc = c
            #process_character(c, text, pos)
            case c
            when "\n"   # New line
              process_new_line(text, pos)
            when "\f"   # New page
              process_new_page(text, pos)
            when "\e"   # Control character
              process_escape_character(obtain_escape_code(text), text, pos)
            else        # Normal character
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              #self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
          end
        end
      else
        pos = {:x => 0, :y => y, :new_x => 0, :height => calc_line_height(text)}
        @right_margin = 0
      #  process_character(text.slice!(0, 1), text, pos) until text.empty?
        @lastc = "\n"
       until text.empty? do 
          c = text.slice!(0, 1)
          c = ' ' if c == "\n"
          if c =~ /[ \t]/
            c = '' if @lastc =~ /[\s\n\f]/
            if pos[:x] + get_next_word_size(c, text) > contents.width - @right_margin
              process_new_line(text, pos)
            else
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              #self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
            @lastc = c
          else
            @lastc = c
            #process_character(c, text, pos)
            case c
            when "\n"   # New line
              process_new_line(text, pos)
            when "\f"   # New page
              process_new_page(text, pos)
            when "\e"   # Control character
              process_escape_character(obtain_escape_code(text), text, pos)
            else        # Normal character
              #process_normal_character(c, pos)
              text_width = text_size(c).width
             # self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
          end
        end
      end
      #size = size + [y - old_y, 96].max
      #pos[:y]
      y = pos[:y]
      if Soulpour777::Animated_Log::Animated_Log[i][1] == true && (y - old_y <= 96)
        y = old_y + 96
        #size = old_y + 96 
      end
      y += line_height
      size = y
      #y += line_height
      #size += line_height
    end
    
    create_log_contents(size)
    y = 0
    adjust = 0
    texts_test = []
    size = 0
    @right_margin = 0
    #texts_faces = []
    for i in 0...Soulpour777::Animated_Log::Animated_Log.size
      if i > 0
        y += line_height
        size += line_height
      end
      old_y = y
      text = Soulpour777::Animated_Log::Animated_Log[i][0]
      if Soulpour777::Animated_Log::Animated_Log[i][1] == true
          draw_face(Soulpour777::Animated_Log::Animated_Log[i][2], Soulpour777::Animated_Log::Animated_Log[i][3], 0, y)
      end
      reset_font_settings
      text = convert_escape_characters(text)
      if Soulpour777::Animated_Log::Animated_Log[i][1] == true
        pos = {:x => 104, :y => y, :new_x => 104, :height => calc_line_height(text)}
        @right_margin = 0
      #process_character(text.slice!(0, 1), text, pos) until text.empty?
	  @lastc = "\n"
        until text.empty? do 
          c = text.slice!(0, 1)
          #c = ' ' if c == "\n"
          if c =~ /[ \t]/
            c = '' if @lastc =~ /[\s\n\f]/
            if pos[:x] + get_next_word_size(c, text) > contents.width - @right_margin
              process_new_line(text, pos)
            else
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
            @lastc = c
          else
            @lastc = c
            #process_character(c, text, pos)
            case c
            when "\n"   # New line
              process_new_line(text, pos)
            when "\f"   # New page
              process_new_page(text, pos)
            when "\e"   # Control character
              process_escape_character(obtain_escape_code(text), text, pos)
            else        # Normal character
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
          end
        end
      else
        pos = {:x => 0, :y => y, :new_x => 0, :height => calc_line_height(text)}
        @lastc = "\n"
        @right_margin = 0
      #  process_character(text.slice!(0, 1), text, pos) until text.empty?
       until text.empty? do 
          c = text.slice!(0, 1)
          c = ' ' if c == "\n"
          if c =~ /[ \t]/
            c = '' if @lastc =~ /[\s\n\f]/
            if pos[:x] + get_next_word_size(c, text) > contents.width - @right_margin
              process_new_line(text, pos)
            else
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
            @lastc = c
          else
            @lastc = c
            #process_character(c, text, pos)
            case c
            when "\n"   # New line
              process_new_line(text, pos)
            when "\f"   # New page
              process_new_page(text, pos)
            when "\e"   # Control character
              process_escape_character(obtain_escape_code(text), text, pos)
            else        # Normal character
              #process_normal_character(c, pos)
              text_width = text_size(c).width
              self.contents.draw_text(pos[:x], pos[:y], text_width * 2, pos[:height], c)
              pos[:x] += text_width
            end
          end
        end
      end
      #size = size + [y - old_y, 96].max
      #pos[:y]
      y = pos[:y]
      if Soulpour777::Animated_Log::Animated_Log[i][1] == true && (y - old_y <= 96)
        y = old_y + 96
        #size = old_y + 96 
      end
      y += line_height
      size = y
      #y += line_height
      #size += line_height
    end
   # contents.clear
   @row_max = (size / line_height).to_i
   self.oy = y
   self.index = (y / line_height).to_i
    size = (size / line_height)
    
    

    #self.height = size
    #create_log_contents(size)

    
    #@row_max = texts_test.size + adjust
    @row_max = size
    #self.index = texts_test.size + adjust
    #self.index = size
    #self.oy = size if size > contents.height
  end
  
end

#==============================================================================
# ** Scene_Map
#------------------------------------------------------------------------------
#  This class performs the map screen processing.
#==============================================================================
class Scene_Map < Scene_Base
  #--------------------------------------------------------------------------
  # Update
  #--------------------------------------------------------------------------
  alias animated_message_log_upd update
  def update
    if @window_log
      update_message_log
    elsif Input.trigger?(Soulpour777::Animated_Log::Message_Log_Button_Mode)
      @window_log = Window_MessageLog.new
      update_message_log
    else
      animated_message_log_upd
    end
  end
  #--------------------------------------------------------------------------
  # Update Message Log
  #--------------------------------------------------------------------------
  def update_message_log
    Graphics.update
    Input.update
    @window_log.update
    @window_log = nil if @window_log.disposed?
  end
end

#==============================================================================
# ** Scene_Battle
#------------------------------------------------------------------------------
#  This class performs battle screen processing.
#==============================================================================
class Scene_Battle < Scene_Base
  #--------------------------------------------------------------------------
  # Update
  #--------------------------------------------------------------------------
  alias animated_message_log_upd update
  def update
    if @window_log
      update_message_log
    elsif Input.trigger?(Soulpour777::Animated_Log::Message_Log_Button_Mode)
      @window_log = Window_MessageLog.new
      update_message_log
    else
      animated_message_log_upd
    end
  end
  #--------------------------------------------------------------------------
  # Update Message Log
  #--------------------------------------------------------------------------
  def update_message_log
    Graphics.update
    Input.update
    @window_log.update
    @window_log = nil if @window_log.disposed?
  end
end