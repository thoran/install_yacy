# YaCy/Homebrew.rb
# YaCy::Homebrew

# 20261125
# 0.2.0

require 'FileUtils/which'
require 'Kernel/run'

module YaCy
  # Where Homebrew installs itself differs by OS, so each module using this one gives its own homebrew_paths.
  module Homebrew
    def brew_path
      FileUtils.which('brew') || homebrew_paths.detect{|path| File.executable?(path)}
    end

    def homebrew_installed?
      !!brew_path
    end

    def homebrew_on_path?
      !!FileUtils.which('brew')
    end

    def homebrew_installed_but_not_on_path?
      homebrew_installed? && !homebrew_on_path?
    end

    def put_homebrew_on_path
      ENV['PATH'] = "#{File.dirname(brew_path)}:#{ENV['PATH']}"
    end

    # Homebrew's own installer, which is the same on macOS and Linux.
    def install_homebrew
      run('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"', show: true)
    end
  end
end
