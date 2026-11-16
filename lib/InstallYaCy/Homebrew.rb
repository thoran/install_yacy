# InstallYaCy/Homebrew.rb
# InstallYaCy::Homebrew

# 20261116
# 0.0.0

require 'FileUtils/which'

module InstallYaCy
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
  end
end
