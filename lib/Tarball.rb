# Tarball.rb
# Tarball

# 20261111
# 0.0.0

require 'fileutils'

class Tarball

  class << self
    attr_accessor :verbose

    # Extracts into to, made where it isn't there, with tar working out the compression itself. Raises where tar fails.
    def extract(path_to_tarball, to:)
      check_path_to_tarball(path_to_tarball)
      check_to(to)
      FileUtils.mkdir_p(to)
      command = ['tar', '-xf', path_to_tarball, '-C', to]
      puts command.join(' ') if @verbose
      system(*command) || raise("#{command.join(' ')} failed.")
    end

    private

    def check_path_to_tarball(path_to_tarball)
      raise "No tarball was given." unless path_to_tarball
    end

    def check_to(to)
      raise "Nowhere to extract to was given." unless to
    end
  end # class << self

  attr_accessor :path_to_tarball
  attr_accessor :to

  def initialize(path_to_tarball:, to:)
    @path_to_tarball = path_to_tarball
    @to = to
  end

  def extract
    Tarball.extract(@path_to_tarball, to: @to)
  end

end
