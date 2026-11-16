# InstallYaCy/MacOS.rb
# InstallYaCy::MacOS

# 20261116
# 0.0.0

require 'fileutils'
require 'InstallYaCy/Download'
require 'InstallYaCy/Homebrew'
require 'Kernel/require_gem'
require 'Kernel/run'

require_gem 'MacOS/Dmg', gem_name: 'macos.rb'

module InstallYaCy
  module MacOS
    include InstallYaCy::Download
    include InstallYaCy::Homebrew
    extend self

    # Homebrew installs itself into /opt/homebrew on Apple silicon and /usr/local on Intel.
    def homebrew_paths
      %w{/opt/homebrew/bin/brew /usr/local/bin/brew}
    end

    def install_homebrew
      run('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"', show: true)
    end

    def openjdk_installed?
      system('brew list --versions openjdk', out: File::NULL, err: File::NULL)
    end

    def install_openjdk
      run('brew install openjdk', show: true)
    end

    def openjdk_jdk_path
      File.join(`brew --prefix openjdk`.chomp, 'libexec', 'openjdk.jdk')
    end

    def java_virtual_machine_link
      '/Library/Java/JavaVirtualMachines/openjdk.jdk'
    end

    def openjdk_linked?
      File.exist?(java_virtual_machine_link)
    end

    def link_openjdk
      run("sudo ln -sfn #{openjdk_jdk_path} #{java_virtual_machine_link}", show: true)
    end

    def java_installed?
      homebrew_installed? && openjdk_installed? && openjdk_linked?
    end

    def install_java
      install_homebrew unless homebrew_installed?
      put_homebrew_on_path unless homebrew_on_path?
      install_openjdk unless openjdk_installed?
      link_openjdk unless openjdk_linked?
    end

    def latest_yacy_filename
      @latest_yacy_filename ||= latest_filename_matching(/\.dmg/)
    end

    def url_for_latest_yacy_file
      url_for(latest_yacy_filename)
    end

    def dmg_filename
      downloaded_path(url_for_latest_yacy_file)
    end

    def download_yacy
      download(url_for_latest_yacy_file)
    end

    def yacy_volume_name
      'YaCy'
    end

    def yacy_app_on_volume
      "/Volumes/#{yacy_volume_name}/YaCy.app"
    end

    def user_applications_dir
      File.join(Dir.home, 'Applications')
    end

    def applications_dir
      Dir.exist?(user_applications_dir) ? user_applications_dir : '/Applications'
    end

    def yacy_installed?
      File.exist?(File.join(user_applications_dir, 'YaCy.app')) || File.exist?('/Applications/YaCy.app')
    end

    def mount_yacy_image
      ::MacOS::Dmg.mount(dmg_filename)
    end

    def copy_yacy_to_applications_dir
      FileUtils.cp_r(yacy_app_on_volume, File.join(applications_dir, 'YaCy.app'))
    end

    def unmount_yacy_image
      ::MacOS::Dmg.unmount(yacy_volume_name)
    end

    def install_yacy
      download_yacy
      mount_yacy_image
      copy_yacy_to_applications_dir
      unmount_yacy_image
    end

    # open -a brings YaCy to the front where it's running already, rather than starting a second, and opens its search page.
    def start_yacy
      run("open -a 'YaCy'", show: true)
    end
  end
end
