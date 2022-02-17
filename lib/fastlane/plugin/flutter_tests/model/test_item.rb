# Class that represents a single test that has been run
class Test
  def initialize(id, name)
    @test_id = id
    @test_name = name
    @test_done = false
    @test_successful = ''
    @test_error = nil
    @test_stacktrace = nil
    @test_was_skipped = false
    @test_was_printed = false
  end

  def mark_as_done(success, skipped, error, stacktrace)
    @test_done = true
    @test_successful = success
    @test_was_skipped = skipped
    @test_error = error
    unless stacktrace.nil?
      stacktrace = stacktrace.gsub(/ {2,}/, "\n")
      @test_stacktrace = stacktrace
    end
  end

  def get_name
    @test_name
  end

  def get_id
    @test_id
  end

  def can_print
    !@test_was_printed
  end

  def get_status
    if @test_was_skipped
      'skipped'
    else
      @test_successful
    end
  end

  # Generates a loggable message for the given test
  #
  # @return message [String] the message to print
  def generate_message
    @test_was_printed = true
    tag = @test_was_skipped ? 'skipped' : @test_successful

    default_message = "[#{tag}] #{@test_name}"
    if @test_successful != 'success'
      default_message += "\n[ERROR] -> #{@test_error}\n[STACKTRACE]\n#{@test_stacktrace}"
    end

    if %w[success error].include?(@test_successful) || @test_was_skipped
      color = if @test_was_skipped
                34 # Skipped tests are displayed in blue
              else
                # Successful tests are in green and the failed in red
                @test_successful == 'success' ? 32 : 31
              end

      "\e[#{color}m#{default_message}\e[0m"
    else
      default_message
    end
  end

end