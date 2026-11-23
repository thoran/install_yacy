# InstallYaCy/Java.rb
# InstallYaCy::Java

# 20261123
# 0.0.0

module InstallYaCy
  # Where Java comes from: chosen by name, or by a path to a java, or left to auto. Each module using this one gives its own java_sources, beginning with existing and ending with adoptium, with between them the package managers it knows, and for each source a <source>_java_installed? and an install_<source>_java, as well as package_manager_installed?, path_java_installed? and install_path_java.
  module Java
    MINIMUM_JAVA_VERSION = 17

    def java_choices
      ['auto'] + java_sources
    end

    # A path to a java is any choice with a slash in it.
    def java_path?(java)
      java.to_s.include?('/')
    end

    def check_java(java)
      return if java_choices.include?(java) || java_path?(java)
      raise ArgumentError, "#{java} isn't one of #{java_choices.join(', ')}, nor a path to a java."
    end

    def package_managers
      java_sources - ['existing', 'adoptium']
    end

    # What auto comes to: Java which is there already, else Java from a package manager which is there already, else Adoptium's. auto never installs a package manager.
    def java_source(java)
      check_java(java)
      return 'path' if java_path?(java)
      return java unless java == 'auto'
      return 'existing' if existing_java_installed?
      package_managers.detect{|source| package_manager_installed?(source)} || 'adoptium'
    end

    def java_installed?(java)
      source = java_source(java)
      source == 'path' ? path_java_installed?(java) : send("#{source}_java_installed?")
    end

    def install_java(java, allow_homebrew_install: false)
      case source = java_source(java)
      when 'path' then install_path_java(java)
      when 'homebrew' then install_homebrew_java(allow_homebrew_install: allow_homebrew_install)
      else send("install_#{source}_java")
      end
    end

    # The major version java reports, read as YaCy's startYACY.sh reads it, or 0 where it can't be run.
    def java_version(java)
      output = IO.popen([java, '-XshowSettings:properties', '-version'], err: [:child, :out], &:read)
      output[/java\.specification\.version = (\S+)/, 1].to_s.sub(/\A1\./, '').to_i
    rescue SystemCallError
      0
    end

    def suitable_java?(java)
      !!java && File.executable?(java) && java_version(java) >= MINIMUM_JAVA_VERSION
    end

    def install_existing_java
      abort("No Java #{MINIMUM_JAVA_VERSION} or later is installed. Install one, or choose another --java.")
    end

    def announce(message)
      puts "Java: #{message}"
    end

    # Asks before Homebrew is installed, unless allow_homebrew_install says it may be, and stops where the answer isn't yes, or where there's no terminal to ask at.
    def confirm_homebrew_install(allow_homebrew_install:)
      return if allow_homebrew_install
      abort("Homebrew isn't installed. Run install_yacy with --install-homebrew to have it installed, or choose another --java.") unless $stdin.tty?
      print "Homebrew isn't installed. Install it, to get Java from it? [y/N] "
      abort("Homebrew wasn't installed. Choose another --java, or run install_yacy again.") unless $stdin.gets.to_s.strip.match?(/\Ay(es)?\z/i)
    end
  end
end
