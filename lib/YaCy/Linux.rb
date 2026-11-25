# YaCy/Linux.rb
# YaCy::Linux

# 20261125
# 0.2.0

require 'FileUtils/which'
require 'YaCy/Adoptium'
require 'YaCy/Download'
require 'YaCy/Homebrew'
require 'YaCy/Java'
require 'YaCy/Process'
require 'Kernel/run'
require 'Linux/PackageManager'
require 'Tarball'

module YaCy
  module Linux
    include YaCy::Download
    include YaCy::Homebrew
    include YaCy::Java
    include YaCy::Adoptium
    include YaCy::Process
    extend self

    def java_sources
      %w{existing homebrew system adoptium}
    end

    def package_manager_installed?(source)
      case source
      when 'homebrew' then homebrew_usable?
      when 'system' then !!system_package_manager
      end
    end

    def java_on_path
      FileUtils.which('java')
    end

    # startYACY.sh finds Java with which, so a JRE from Adoptium is put on PATH before YaCy is started.
    def existing_java_installed?
      suitable_java?(java_on_path) || adoptium_java_installed?
    end

    def root?
      ::Process.uid.zero?
    end

    # Homebrew installs itself into /home/linuxbrew/.linuxbrew, or into ~/.linuxbrew where it can't write there.
    def homebrew_paths
      ['/home/linuxbrew/.linuxbrew/bin/brew', File.join(Dir.home, '.linuxbrew', 'bin', 'brew')]
    end

    # Homebrew won't run as root.
    def homebrew_usable?
      homebrew_installed? && !root?
    end

    def homebrew_package_manager
      ::Linux::PackageManager.new(command: 'brew')
    end

    def homebrew_java_installed?
      homebrew_usable? && homebrew_package_manager.installed?('openjdk')
    end

    def install_homebrew_java(allow_homebrew_install: false)
      abort("Homebrew won't run as root. Run yacy as another user, or choose another --java.") if root?
      unless homebrew_installed?
        confirm_homebrew_install(allow_homebrew_install: allow_homebrew_install)
        announce("installing Homebrew.")
        install_homebrew
      end
      put_homebrew_on_path unless homebrew_on_path?
      announce("installing Homebrew's openjdk.")
      homebrew_package_manager.install('openjdk')
    end

    # The distribution's own package manager, which is any but Homebrew.
    def system_package_manager
      @system_package_manager ||= (
        command = ::Linux::PackageManager.command(except: ['brew'])
        command && ::Linux::PackageManager.new(command: command)
      )
    end

    def system_java_installed?
      !!system_package_manager && system_package_manager.installed?(system_package_manager.java_package)
    end

    def install_system_java
      abort("No package manager was found to install Java with. Install Java #{MINIMUM_JAVA_VERSION} or later, or choose another --java.") unless system_package_manager
      announce("installing #{system_package_manager.java_package} with #{system_package_manager.command}.")
      system_package_manager.install(system_package_manager.java_package)
    end

    def musl?
      RUBY_PLATFORM.include?('musl')
    end

    def adoptium_os
      musl? ? 'alpine-linux' : 'linux'
    end

    def data_home
      ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share')
    end

    def adoptium_dir
      File.join(data_home, 'yacy-jre')
    end

    def adoptium_java_path
      %w{bin java}
    end

    def put_adoptium_java_on_path
      ENV['PATH'] = "#{File.dirname(adoptium_java)}:#{ENV['PATH']}"
    end

    def same_file?(a, b)
      !!a && !!b && File.realpath(a) == File.realpath(b)
    rescue SystemCallError
      false
    end

    def path_java_installed?(java)
      suitable_java?(java) && same_file?(java, java_on_path)
    end

    def install_path_java(java)
      abort("#{java} isn't Java #{MINIMUM_JAVA_VERSION} or later.") unless suitable_java?(java)
      announce("using #{java}.")
      ENV['PATH'] = "#{File.dirname(java)}:#{ENV['PATH']}"
    end

    def latest_yacy_filename
      @latest_yacy_filename ||= latest_filename_matching(/\.tar\.gz$/)
    end

    def url_for_latest_yacy_file
      url_for(latest_yacy_filename)
    end

    def tarball_filename
      downloaded_path(url_for_latest_yacy_file)
    end

    def download_yacy
      download(url_for_latest_yacy_file)
    end

    def yacy_dir
      File.join(data_home, 'yacy')
    end

    def yacy_installed?
      File.exist?(File.join(yacy_dir, 'startYACY.sh'))
    end

    def unpack_yacy
      Tarball.extract(tarball_filename, to: data_home)
    end

    def install_yacy
      download_yacy
      unpack_yacy
    end

    def yacy_data_dir
      File.join(yacy_dir, 'DATA')
    end

    def yacy_scripts_dir
      yacy_dir
    end

    # startYACY.sh run twice would start a second YaCy which can't have the port. Adoptium's JRE is put on PATH where there's no other suitable Java there, since startYACY.sh finds Java with which.
    def start_yacy
      return if yacy_running?
      put_adoptium_java_on_path if !suitable_java?(java_on_path) && adoptium_java_installed?
      run(File.join(yacy_dir, 'startYACY.sh'), show: true)
    end

    def display?
      !!(ENV['DISPLAY'] || ENV['WAYLAND_DISPLAY'])
    end

    # Where there's no display to open it on, as on a server, the address is given instead.
    def open_yacy_page
      if display? && FileUtils.which('xdg-open')
        run('xdg-open', yacy_url, show: true)
      else
        puts "YaCy is running at #{yacy_url}"
      end
    end
  end
end
