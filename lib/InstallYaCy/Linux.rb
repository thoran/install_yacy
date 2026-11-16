# InstallYaCy/Linux.rb
# InstallYaCy::Linux

# 20261116
# 0.0.0

require 'FileUtils/which'
require 'InstallYaCy/Download'
require 'InstallYaCy/Homebrew'
require 'Kernel/run'
require 'Linux/PackageManager'
require 'Tarball'

module InstallYaCy
  module Linux
    include InstallYaCy::Download
    include InstallYaCy::Homebrew
    extend self

    # Homebrew installs itself into /home/linuxbrew/.linuxbrew, or into ~/.linuxbrew where it can't write there.
    def homebrew_paths
      ['/home/linuxbrew/.linuxbrew/bin/brew', File.join(Dir.home, '.linuxbrew', 'bin', 'brew')]
    end

    def package_manager
      @package_manager ||= ::Linux::PackageManager.new
    end

    def java_installed?
      !!FileUtils.which('java')
    end

    def install_java
      abort("No package manager was found to install Java with. Install Java 17 or later, and run install_yacy again.") unless package_manager.command
      package_manager.install(package_manager.java_package)
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

    def data_home
      ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share')
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

    # Where DATA/yacy.running is, as YaCy's stopYACY.sh takes it.
    def yacy_running?
      File.exist?(File.join(yacy_dir, 'DATA', 'yacy.running'))
    end

    # startYACY.sh run twice would start a second YaCy which can't have the port.
    def start_yacy
      run(File.join(yacy_dir, 'startYACY.sh'), show: true) unless yacy_running?
    end
  end
end
