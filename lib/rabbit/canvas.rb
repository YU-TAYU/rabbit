require "forwardable"
require "gtk2"
require "rd/rdfmt"

require "rabbit/rabbit"
require 'rabbit/element'
require "rabbit/rd2rabbit-lib"
require "rabbit/theme"
require "rabbit/index"

module Rabbit

  class Canvas
    
    include Enumerable
    extend Forwardable

    def_delegators(:@frame, :icon, :icon=, :set_icon)
    def_delegators(:@frame, :icon_list, :icon_list=, :set_icon_list)
    def_delegators(:@frame, :quit, :logger, :update_title)
    def_delegators(:@frame, :toggle_fullscreen, :fullscreen?)
    def_delegators(:@frame, :iconify)

    def_delegators(:@renderer, :width, :height)
    def_delegators(:@renderer, :font_families)
    def_delegators(:@renderer, :destroy, :attach_to)
    def_delegators(:@renderer, :cursor=, :print_out_filename=)
    def_delegators(:@renderer, :each_page_pixbuf, :redraw)
    def_delegators(:@renderer, :foreground, :background)
    def_delegators(:@renderer, :foreground=, :background=)
    def_delegators(:@renderer, :background_image, :background_image=)

    def_delegators(:@renderer, :make_color, :make_layout)
    def_delegators(:@renderer, :draw_line, :draw_rectangle, :draw_arc)
    def_delegators(:@renderer, :draw_circle, :draw_layout, :draw_pixbuf)
    def_delegators(:@renderer, :draw_page)

    
    attr_reader :renderer, :theme_name, :source

    attr_writer :saved_image_basename

    attr_accessor :saved_image_type


    def initialize(frame, renderer)
      @frame = frame
      @theme_name = nil
      @saved_image_basename = nil
      clear
      @renderer = renderer.new(self)
    end

    def title
      tp = title_page
      if tp
        tp.title
      else
        "Rabbit"
      end
    end

    def page_title
      return "" if pages.empty?
      page = current_page
      if page.is_a?(Element::TitlePage)
        page.title
      else
        "#{title}: #{page.title}"
      end
    end

    def pages
      if @index_mode
        @index_pages
      else
        @pages
      end
    end
    
    def page_size
      pages.size
    end

    def current_page
      page = pages[current_index]
      if page
        page
      else
        move_to_first
        pages.first
      end
    end

    def current_index
      if @index_mode
        @index_current_index
      else
        @current_index
      end
    end

    def next_page
      pages[current_index + 1]
    end

    def each(&block)
      pages.each(&block)
    end

    def <<(page)
      pages << page
    end

    def apply_theme(name=nil)
      @theme_name = name || @theme_name || default_theme || "default"
      if @theme_name and not @pages.empty?
        clear_theme
        clear_index_pages
        theme = Theme.new(self)
        theme.apply(@theme_name)
        @renderer.post_apply_theme
      end
    end

    def reload_theme
      apply_theme
    end

    def parse_rd(source=nil)
      @source = source || @source
      if @source.modified?
        begin
          keep_index do
            tree = RD::RDTree.new("=begin\n#{@source.read}\n=end\n")
            clear
            visitor = RD2RabbitVisitor.new(self)
            visitor.visit(tree)
            apply_theme
            update_title(title)
            @renderer.post_parse_rd
          end
        rescue Racc::ParseError
          logger.warn($!.message)
        end
      end
    end

    def reload_source
      if need_reload_source?
        parse_rd
      end
    end

    def need_reload_source?
      @source and @source.modified?
    end

    def full_path(path)
      @source and @source.full_path(path)
    end

    def tmp_dir_name
      @source and @source.tmp_dir_name
    end

    def save_as_image
      file_name_format =
          "#{saved_image_basename}%0#{number_of_places(page_size)}d.#{@saved_image_type}"
      @renderer.each_page_pixbuf do |pixbuf, page_number|
        file_name = file_name_format % page_number
        pixbuf.save(file_name, normalized_saved_image_type)
      end
    end

    def print
      @pages.each_with_index do |page, i|
        move_to(i)
        current_page.draw(self)
      end
      @renderer.print
    end
    
    def fullscreened
      @renderer.post_fullscreen
    end

    def unfullscreened
      @renderer.post_unfullscreen
    end

    def iconified
      @renderer.post_iconify
    end

    def saved_image_basename
      name = @saved_image_basename || GLib.filename_from_utf8(title)
      if @index_mode
        name + "_index"
      else
        name
      end
    end

    def move_to_if_can(index)
      if 0 <= index and index < page_size
        move_to(index)
      end
    end

    def move_to_next_if_can
      move_to_if_can(current_index + 1)
    end

    def move_to_previous_if_can
      move_to_if_can(current_index - 1)
    end

    def move_to_first
      move_to_if_can(0)
    end

    def move_to_last
      move_to(page_size - 1)
    end

    def index_mode?
      @index_mode
    end

    def toggle_index_mode
      if @index_mode
        @index_mode = false
        @renderer.index_mode_off
      else
        @index_mode = true
        if @index_pages.empty?
          @index_pages = Index.make_index_pages(self)
        end
        @renderer.index_mode_on
        move_to(0)
      end
      @renderer.post_toggle_index_mode
    end

    def index_mode?
      @index_mode
    end
    
    private
    def clear
      clear_pages
      clear_index_pages
    end
    
    def clear_pages
      @current_index = 0
      @pages = []
    end
    
    def clear_index_pages
      @index_mode = false
      @index_current_index = 0
      @index_pages = []
    end

    def clear_theme
      @pages.each do |page|
        page.clear_theme
      end
    end

    def keep_index
      index = @current_index
      index_index = @index_current_index
      yield
      @current_index = index
      @index_current_index = index_index
    end
    
    def title_page
      @pages.find{|x| x.is_a?(Element::TitlePage)}
    end

    def default_theme
      tp = title_page
      tp and tp.theme
    end

    def set_current_index(new_index)
      if @index_mode
        @index_current_index = new_index
      else
        @current_index = new_index
      end
    end

    def with_index_mode(new_value)
      current_index_mode = @index_mode
      @index_mode = new_value
      yield
      @index_mode = current_index_mode
    end
    
    def move_to(index)
      set_current_index(index)
      update_title(page_title)
      @renderer.post_move(current_index)
    end

    def normalized_saved_image_type
      case @saved_image_type
      when /jpg/i
        "jpeg"
      else
        @saved_image_type.downcase
      end
    end

    def number_of_places(num)
      n = 1
      target = num
      while target >= 10
        target /= 10
        n += 1
      end
      n
    end

  end

end
