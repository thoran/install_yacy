# test/Linux/PackageManager_test.rb

lib_dir = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'Linux/PackageManager'

describe Linux::PackageManager do
  # Runs the block with system stubbed, returning the commands it was given; each succeeds where succeed is true.
  def commands_run(succeed: true)
    commands = []
    Linux::PackageManager.stub(:system, ->(*command, **options){commands << command; succeed}){yield}
    commands
  end

  # Runs the block with PATH holding only executables of the names given.
  def with_path(*executables)
    path = ENV['PATH']
    Dir.mktmpdir do |dir|
      executables.each{|executable| FileUtils.touch(File.join(dir, executable)); File.chmod(0755, File.join(dir, executable))}
      ENV['PATH'] = dir
      yield
    end
  ensure
    ENV['PATH'] = path
  end

  describe ".command" do
    it "is the package manager on PATH" do
      %w{brew apt-get dnf yum pacman zypper apk}.each do |command|
        with_path(command){expect(Process.stub(:uid, 1000){Linux::PackageManager.command}).must_equal command}
      end
    end

    it "is brew where another is there too" do
      with_path('apt-get', 'brew'){expect(Process.stub(:uid, 1000){Linux::PackageManager.command}).must_equal 'brew'}
    end

    it "isn't brew where root" do
      with_path('apt-get', 'brew'){expect(Process.stub(:uid, 0){Linux::PackageManager.command}).must_equal 'apt-get'}
      with_path('brew'){expect(Process.stub(:uid, 0){Linux::PackageManager.command}).must_be_nil}
    end

    it "is dnf where yum is there too" do
      with_path('yum', 'dnf'){expect(Linux::PackageManager.command).must_equal 'dnf'}
    end

    it "is nil where there is none" do
      with_path('ls'){expect(Linux::PackageManager.command).must_be_nil}
    end
  end

  describe ".installed?" do
    it "asks the package database, escaping the package for the shell" do
      expect(commands_run{Linux::PackageManager.installed?('java headless', command: 'dnf')}).must_equal [['rpm -q --whatprovides java\\ headless']]
      expect(commands_run{Linux::PackageManager.installed?('default-jre-headless', command: 'apt-get')}).must_equal [["dpkg-query -W -f='${db:Status-Status}' default-jre-headless | grep -qx installed"]]
      expect(commands_run{Linux::PackageManager.installed?('jre-openjdk-headless', command: 'pacman')}).must_equal [['pacman -Q jre-openjdk-headless']]
      expect(commands_run{Linux::PackageManager.installed?('openjdk21-jre-headless', command: 'apk')}).must_equal [['apk info -e openjdk21-jre-headless']]
      expect(commands_run{Linux::PackageManager.installed?('openjdk', command: 'brew')}).must_equal [['brew list --versions openjdk']]
    end

    it "is whether the package database says so" do
      Linux::PackageManager.stub(:system, true){expect(Linux::PackageManager.installed?('x', command: 'dnf')).must_equal true}
      Linux::PackageManager.stub(:system, false){expect(Linux::PackageManager.installed?('x', command: 'dnf')).must_equal false}
    end
  end

  describe ".install" do
    it "uses sudo where not root" do
      commands = Process.stub(:uid, 1000){commands_run{Linux::PackageManager.install('default-jre-headless', command: 'apt-get')}}
      expect(commands).must_equal [['sudo apt-get update'], ['sudo apt-get install -y default-jre-headless']]
    end

    it "doesn't use sudo where root" do
      commands = Process.stub(:uid, 0){commands_run{Linux::PackageManager.install('java-headless', command: 'dnf')}}
      expect(commands).must_equal [['dnf install -y java-headless']]
    end

    it "doesn't use sudo with brew" do
      commands = Process.stub(:uid, 1000){commands_run{Linux::PackageManager.install('openjdk', command: 'brew')}}
      expect(commands).must_equal [['brew install openjdk']]
    end

    it "installs with each package manager" do
      commands = Process.stub(:uid, 0) do
        commands_run do
          %w{yum pacman zypper apk}.each{|command| Linux::PackageManager.install('x', command: command)}
        end
      end
      expect(commands).must_equal [['yum install -y x'], ['pacman -S --noconfirm --needed x'], ['zypper --non-interactive install x'], ['apk update'], ['apk add x']]
    end

    it "raises where a command fails, running no more" do
      commands = Process.stub(:uid, 0) do
        commands_run(succeed: false) do
          expect(expect{Linux::PackageManager.install('x', command: 'apt-get')}.must_raise(RuntimeError).message).must_equal 'apt-get update failed.'
        end
      end
      expect(commands).must_equal [['apt-get update']]
    end

    it "prints each command where verbose" do
      Linux::PackageManager.verbose = true
      out, _ = capture_io{Process.stub(:uid, 0){commands_run{Linux::PackageManager.install('x', command: 'dnf')}}}
      expect(out).must_equal "dnf install -y x\n"
    ensure
      Linux::PackageManager.verbose = nil
    end
  end

  describe ".java_package" do
    it "is a headless Java runtime, 17 or later, for each package manager" do
      expect(%w{brew apt-get dnf yum pacman zypper apk}.map{|command| Linux::PackageManager.java_package(command: command)}).must_equal %w{openjdk default-jre-headless java-headless java-17-openjdk-headless jre-openjdk-headless java-21-openjdk-headless openjdk21-jre-headless}
    end
  end

  describe "where there's no package manager, or one not known" do
    it "raises, running nothing" do
      commands = commands_run do
        expect(expect{Linux::PackageManager.install('x', command: nil)}.must_raise(RuntimeError).message).must_equal 'No package manager was found.'
        expect(expect{Linux::PackageManager.installed?('x', command: 'port')}.must_raise(RuntimeError).message).must_equal "port isn't a package manager known."
        expect(expect{Linux::PackageManager.install(nil, command: 'dnf')}.must_raise(RuntimeError).message).must_equal 'No package was given.'
      end
      expect(commands).must_equal []
    end
  end

  describe "an instance" do
    it "uses the package manager on PATH where none is given" do
      with_path('zypper'){expect(Linux::PackageManager.new.command).must_equal 'zypper'}
    end

    it "uses the package manager given" do
      package_manager = Linux::PackageManager.new(command: 'apk')
      commands = Process.stub(:uid, 0) do
        commands_run do
          package_manager.installed?(package_manager.java_package)
          package_manager.install(package_manager.java_package)
        end
      end
      expect(commands).must_equal [['apk info -e openjdk21-jre-headless'], ['apk update'], ['apk add openjdk21-jre-headless']]
    end
  end
end
