class Utilities

  def initialize
    @colors = {
      'blue' => 34,
      'green' => 32,
      'red' => 31,
    }
  end

  # Colorize a message. If the color specified doesn't exists, returns the default
  # message
  #
  # @param message [String] the message that has to be colorized before printing
  # @param color [String] the name of the color
  # @return [String] the message wrapped in a new color
  def colorize(message, color)
    if @colors.has_key? color
      color_code = @colors[color]
      "\e[#{color_code}m#{message}\e[0m"
    else
      message
    end
  end

end
