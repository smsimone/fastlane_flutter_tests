class LogHelper
  # @param log_file [String] the path to the logfile
  def initialize(log_file)
    @log_file = log_file
    _open_file
  end

  # Opens the file
  def _open_file
    if File.exist?(@log_file)
      File.delete(@log_file)
    end
    @file = File.open(@log_file, "w")
  end

  # @param line [String] Line to append to the log_file
  def write_line(line)
    @file.write(line)
  end

  # Deletes the file created (to use only if the test finished correctly)
  def delete_file
    File.delete(@log_file)
  end
end