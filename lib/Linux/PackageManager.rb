# Linux/PackageManager.rb
# Linux::PackageManager

# 20261111
# 0.0.0

require 'shellwords'

module Linux
  class PackageManager

    class << self
      attr_accessor :verbose

      # For each package manager known, in the order looked for: how to ask whether a package is installed, how to install one, and its package of a headless Java runtime, 17 or later. Homebrew is looked for first, since it's only there where someone chose it, and dnf before yum, which is dnf where both are. Homebrew runs as the user, never with sudo, and won't run as root, so isn't looked for as root.
      def commands
        {
          'brew' => {
            installed: 'brew list --versions %{package}',
            install: ['brew install %{package}'],
            java_package: 'openjdk',
            as_user: true,
          },
          'apt-get' => {
            installed: "dpkg-query -W -f='${db:Status-Status}' %{package} | grep -qx installed",
            install: ['apt-get update', 'apt-get install -y %{package}'],
            java_package: 'default-jre-headless',
          },
          'dnf' => {
            installed: 'rpm -q --whatprovides %{package}',
            install: ['dnf install -y %{package}'],
            java_package: 'java-headless',
          },
          'yum' => {
            installed: 'rpm -q --whatprovides %{package}',
            install: ['yum install -y %{package}'],
            java_package: 'java-17-openjdk-headless',
          },
          'pacman' => {
            installed: 'pacman -Q %{package}',
            install: ['pacman -S --noconfirm --needed %{package}'],
            java_package: 'jre-openjdk-headless',
          },
          'zypper' => {
            installed: 'rpm -q --whatprovides %{package}',
            install: ['zypper --non-interactive install %{package}'],
            java_package: 'java-21-openjdk-headless',
          },
          'apk' => {
            installed: 'apk info -e %{package}',
            install: ['apk update', 'apk add %{package}'],
            java_package: 'openjdk21-jre-headless',
          },
        }
      end

      # The first of the package managers known which is on PATH, and can be run as whoever this is, or nil where there is none.
      def command
        commands.keys.detect{|command| on_path?(command) && !(commands[command][:as_user] && root?)}
      end

      def installed?(package, command: self.command)
        check_command(command)
        check_package(package)
        system(commands[command][:installed] % {package: Shellwords.escape(package)}, out: File::NULL, err: File::NULL)
      end

      # Each command is run with sudo, unless running as root or the package manager runs as the user, and raises where it fails.
      def install(package, command: self.command)
        check_command(command)
        check_package(package)
        commands[command][:install].each do |install_command|
          command_line = "#{sudo(command)}#{install_command % {package: Shellwords.escape(package)}}"
          puts command_line if @verbose
          system(command_line) || raise("#{command_line} failed.")
        end
      end

      def java_package(command: self.command)
        check_command(command)
        commands[command][:java_package]
      end

      private

      def check_command(command)
        raise "No package manager was found." unless command
        raise "#{command} isn't a package manager known." unless commands[command]
      end

      def check_package(package)
        raise "No package was given." unless package
      end

      def root?
        Process.uid.zero?
      end

      def sudo(command)
        root? || commands[command][:as_user] ? '' : 'sudo '
      end

      def on_path?(command)
        ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any?{|directory| File.executable?(File.join(directory, command))}
      end
    end # class << self

    attr_accessor :command

    # Where no command is given, the first of the package managers known which is on PATH.
    def initialize(command: nil)
      @command = command || PackageManager.command
    end

    def installed?(package)
      PackageManager.installed?(package, command: @command)
    end

    def install(package)
      PackageManager.install(package, command: @command)
    end

    def java_package
      PackageManager.java_package(command: @command)
    end

  end
end
