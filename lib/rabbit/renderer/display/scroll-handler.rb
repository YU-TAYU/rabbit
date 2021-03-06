require 'rabbit/gtk'

module Rabbit
  module Renderer
    module Display
      module ScrollHandler
        def initialize(*args, &block)
          super
          init_scroll_handler
        end

        private
        def init_scroll_handler
        end

        def set_scroll_event(widget)
          widget.signal_connect("scroll_event") do |widget, event|
            handled = call_hook_procs(@scroll_hook_procs, event)
            unless handled
              handled = true
              case event.direction
              when Gdk::EventScroll::Direction::UP
                @canvas.activate("PreviousSlide")
              when Gdk::EventScroll::Direction::DOWN
                @canvas.activate("NextSlide")
              else
                handled = false
              end
            end
            handled
          end
        end
      end
    end
  end
end
