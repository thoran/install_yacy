# YaCy/MacOS.rb
# YaCy::MacOS

# 20261125
# 0.3.0

require 'fileutils'
require 'FileUtils/which'
require 'YaCy/Adoptium'
require 'YaCy/Download'
require 'YaCy/Homebrew'
require 'YaCy/Java'
require 'YaCy/Process'
require 'Kernel/require_gem'
require 'Kernel/run'

require_gem 'MacOS/Dmg', gem_name: 'macos.rb'

module YaCy
  module MacOS
    include YaCy::Download
    include YaCy::Homebrew
    include YaCy::Java
    include YaCy::Adoptium
    include YaCy::Process
    extend self

    def java_sources
      %w{existing homebrew macports adoptium}
    end

    def package_manager_installed?(source)
      case source
      when 'homebrew' then homebrew_installed?
      when 'macports' then macports_installed?
      end
    end

    # YaCy.app is started by open, and so finds Java with java_home, by way of /usr/bin/java, whatever is on PATH.
    def existing_java_installed?
      system('/usr/libexec/java_home', '-v', "#{MINIMUM_JAVA_VERSION}+", out: File::NULL, err: File::NULL)
    end

    # java_home looks here as well as in /Library/Java/JavaVirtualMachines, and a user can write here without sudo.
    def user_java_virtual_machines_dir
      File.join(Dir.home, 'Library', 'Java', 'JavaVirtualMachines')
    end

    # Homebrew installs itself into /opt/homebrew on Apple silicon and /usr/local on Intel.
    def homebrew_paths
      %w{/opt/homebrew/bin/brew /usr/local/bin/brew}
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
      File.join(user_java_virtual_machines_dir, 'openjdk.jdk')
    end

    # Where install_yacy linked it before 0.7.0, with sudo.
    def system_java_virtual_machine_link
      '/Library/Java/JavaVirtualMachines/openjdk.jdk'
    end

    def openjdk_linked?
      File.exist?(java_virtual_machine_link) || File.exist?(system_java_virtual_machine_link)
    end

    def link_openjdk
      FileUtils.mkdir_p(user_java_virtual_machines_dir)
      FileUtils.rm_f(java_virtual_machine_link)
      File.symlink(openjdk_jdk_path, java_virtual_machine_link)
    end

    def homebrew_java_installed?
      homebrew_installed? && openjdk_installed? && openjdk_linked?
    end

    def install_homebrew_java(allow_homebrew_install: false)
      unless homebrew_installed?
        confirm_homebrew_install(allow_homebrew_install: allow_homebrew_install)
        announce("installing Homebrew.")
        install_homebrew
      end
      put_homebrew_on_path unless homebrew_on_path?
      unless openjdk_installed?
        announce("installing Homebrew's openjdk.")
        install_openjdk
      end
      link_openjdk unless openjdk_linked?
    end

    def macports_path
      FileUtils.which('port') || ('/opt/local/bin/port' if File.executable?('/opt/local/bin/port'))
    end

    def macports_installed?
      !!macports_path
    end

    def macports_java_port
      'openjdk25'
    end

    def macports_java_installed?
      macports_installed? && !IO.popen([macports_path, '-q', 'installed', macports_java_port], err: File::NULL, &:read).strip.empty?
    end

    def install_macports_java
      abort("MacPorts isn't installed. Install it from https://www.macports.org/install.php, or choose another --java.") unless macports_installed?
      announce("installing MacPorts' #{macports_java_port}, with sudo.")
      run("sudo #{macports_path} install #{macports_java_port}", show: true)
    end

    def adoptium_os
      'mac'
    end

    def adoptium_dir
      user_java_virtual_machines_dir
    end

    def adoptium_java_path
      %w{Contents Home bin java}
    end

    # The bundle a java is in, where it's in one, as java_home needs it to be. The path as given is kept where it's in a bundle itself, so as a link through Homebrew's opt directory outlasts an upgrade, and is otherwise followed to where it leads.
    def java_bundle(java)
      bundle = %r{\A(.+)/Contents/Home/bin/java\z}
      File.expand_path(java)[bundle, 1] || File.realpath(java)[bundle, 1]
    rescue SystemCallError
      nil
    end

    def java_bundle_link(java)
      File.join(user_java_virtual_machines_dir, File.basename(java_bundle(java)))
    end

    def path_java_installed?(java)
      suitable_java?(java) && !!java_bundle(java) && (File.basename(File.dirname(java_bundle(java))) == 'JavaVirtualMachines' || File.exist?(java_bundle_link(java)))
    end

    def install_path_java(java)
      abort("#{java} isn't Java #{MINIMUM_JAVA_VERSION} or later.") unless suitable_java?(java)
      abort("#{java} isn't in a Java bundle, ending in Contents/Home/bin/java, which java_home needs for YaCy.app to find it.") unless java_bundle(java)
      announce("linking #{java_bundle(java)} into #{user_java_virtual_machines_dir}.")
      FileUtils.mkdir_p(user_java_virtual_machines_dir)
      File.symlink(java_bundle(java), java_bundle_link(java))
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

    def yacy_app
      [File.join(user_applications_dir, 'YaCy.app'), '/Applications/YaCy.app'].detect{|path| File.exist?(path)}
    end

    def yacy_installed?
      !!yacy_app
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

    # open -a runs YaCy.app, whose startYACYMacOS.sh starts YaCy with its DATA in yacy_data_dir, and YaCy opens its own page as it starts.
    def start_yacy
      run("open -a 'YaCy'", show: true)
    end

    # YaCy.app keeps its DATA here, as its startYACYMacOS.sh says, rather than within the app.
    def yacy_data_dir
      File.join(Dir.home, 'Library', 'Application Support', 'net.yacy.YaCy', 'DATA')
    end

    def yacy_scripts_dir
      File.join(yacy_app, 'Contents', 'MacOS')
    end

    # Over SSH, a page opened here would open on the Mac's own screen, rather than before whoever ran yacy.
    def display?
      !ENV['SSH_CONNECTION']
    end

    # Where the page couldn't be seen, YaCy's address is given instead.
    def open_yacy_page
      if display?
        run('open', yacy_page_url, show: true)
      else
        give_yacy_address
      end
    end
  end
end
