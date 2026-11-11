# test/install_yacy.rb

bin_dir = File.expand_path(File.join('..', '..', 'bin'), __FILE__)
$LOAD_PATH.unshift(bin_dir) unless $LOAD_PATH.include?(bin_dir)

require 'minitest/autorun'
require 'rubygems/package'
require 'stringio'
require 'tmpdir'
require 'zlib'
require 'minitest/mock'
require 'minitest-spec-context'
# require 'mocha/minitest'
require 'webmock/minitest'

load 'install_yacy'

WebMock.disable_net_connect!(allow_localhost: true)

describe "install_yacy" do
  let(:latest_page) do
    root_filename = File.expand_path(File.join('..', '..', 'test', 'fixtures', 'index.html'), __FILE__)
    File.read(root_filename)
  end

  before do
    stub_request(:get, 'https://download.yacy.net/').to_return(status: 200, body: latest_page)
  end

  describe "latest_macos_yacy_filename()" do
    it "returns the filename of the latest yacy for macOS" do
      expect(latest_macos_yacy_filename).must_equal 'yacy_v1.942_202608150808_f9c4b9700.dmg'
    end
  end

  describe "url_for_latest_macos_yacy_file()" do
    it "returns the URL of the latest yacy for macOS" do
      expect(url_for_latest_macos_yacy_file).must_equal 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.dmg'
    end
  end

  describe "yacy_app_on_volume()" do
    it "is YaCy.app on the volume named YaCy" do
      expect(yacy_app_on_volume).must_equal '/Volumes/YaCy/YaCy.app'
    end
  end

  describe "homebrew_installed?()" do
    it "is true where brew is on PATH" do
      FileUtils.stub(:which, '/usr/local/bin/brew') do
        expect(homebrew_installed?).must_equal true
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Apple silicon" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          expect(homebrew_installed?).must_equal true
        end
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Linux" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/home/linuxbrew/.linuxbrew/bin/brew'}) do
          expect(homebrew_installed?).must_equal true
        end
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Intel" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/usr/local/bin/brew'}) do
          expect(homebrew_installed?).must_equal true
        end
      end
    end

    it "is false where there is no brew" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, false) do
          expect(homebrew_installed?).must_equal false
        end
      end
    end
  end

  describe "put_homebrew_on_path()" do
    before do
      @path = ENV['PATH']
    end

    after do
      ENV['PATH'] = @path
    end

    it "puts the directory brew is in at the front of PATH" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          put_homebrew_on_path
        end
      end
      expect(ENV['PATH']).must_equal "/opt/homebrew/bin:#{@path}"
    end
  end

  describe "latest_linux_yacy_filename()" do
    it "returns the filename of the latest yacy tarball, not its signature" do
      expect(latest_linux_yacy_filename).must_equal 'yacy_v1.942_202608150808_f9c4b9700.tar.gz'
    end
  end

  describe "url_for_latest_linux_yacy_file()" do
    it "returns the URL of the latest yacy tarball" do
      expect(url_for_latest_linux_yacy_file).must_equal 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz'
    end
  end

  describe "on Linux" do
    let(:calls){[]}
    let(:home){Dir.mktmpdir}

    def record(steps)
      steps.each{|name, answer| define_singleton_method(name){|*args, **options| calls << (args.empty? ? name : args); answer}}
    end

    def tarball
      io = StringIO.new
      Zlib::GzipWriter.wrap(io) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          tar.mkdir('yacy', 0755)
          tar.add_file_simple('yacy/startYACY.sh', 0755, 10){|file| file.write("#!/bin/sh\n")}
        end
      end
      io.string
    end

    before do
      @env = ENV.to_h.slice('HOME', 'XDG_DATA_HOME')
      @pwd = Dir.pwd
      ENV['HOME'] = home
      ENV.delete('XDG_DATA_HOME')
    end

    after do
      Dir.chdir(@pwd)
      ENV.update(@env)
      ENV.delete('XDG_DATA_HOME') unless @env['XDG_DATA_HOME']
      FileUtils.rm_rf(home)
    end

    describe "linux_yacy_dir()" do
      it "is yacy in ~/.local/share" do
        expect(linux_yacy_dir).must_equal File.join(home, '.local', 'share', 'yacy')
      end

      it "is yacy in XDG_DATA_HOME where that is set" do
        ENV['XDG_DATA_HOME'] = '/srv/data'
        expect(linux_yacy_dir).must_equal '/srv/data/yacy'
      end
    end

    describe "java_installed?()" do
      it "is true where java is on PATH" do
        FileUtils.stub(:which, '/usr/bin/java') do
          expect(java_installed?).must_equal true
        end
      end

      it "is false where java isn't on PATH" do
        FileUtils.stub(:which, nil) do
          expect(java_installed?).must_equal false
        end
      end
    end

    describe "install_java()" do
      it "installs the package manager's Java" do
        commands = []
        record(package_manager: Linux::PackageManager.new(command: 'dnf'))
        Linux::PackageManager.stub(:system, ->(*command, **options){commands << command; true}) do
          Process.stub(:uid, 0){capture_io{install_java}}
        end
        expect(commands).must_equal [['dnf install -y java-headless']]
      end

      it "stops where no package manager is found" do
        Linux::PackageManager.stub(:command, nil) do
          record(package_manager: Linux::PackageManager.new)
          _, err = capture_io{expect{install_java}.must_raise SystemExit}
          expect(err).must_match /Java 17 or later/
        end
      end
    end

    describe "install_linux_yacy()" do
      # Minitest::Test#run hides Kernel#run within a test, so the script is called from an object of its own.
      def install_linux_yacy
        Object.new.send(:install_linux_yacy)
      end

      before do
        stub_request(:get, 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz').to_return(status: 200, body: tarball)
      end

      it "downloads the tarball into ~/Downloads and unpacks it into ~/.local/share" do
        expect(linux_yacy_installed?).must_equal false
        capture_subprocess_io{install_linux_yacy}
        expect(File.exist?(File.join(home, 'Downloads', 'yacy_v1.942_202608150808_f9c4b9700.tar.gz'))).must_equal true
        expect(linux_yacy_installed?).must_equal true
      end

      it "doesn't download the tarball again" do
        capture_subprocess_io{install_linux_yacy}
        capture_subprocess_io{install_linux_yacy}
        assert_requested(:get, 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz', times: 1)
      end
    end

    describe "linux_yacy_running?()" do
      it "is true where YaCy has left DATA/yacy.running" do
        FileUtils.mkdir_p(File.join(linux_yacy_dir, 'DATA'))
        FileUtils.touch(File.join(linux_yacy_dir, 'DATA', 'yacy.running'))
        expect(linux_yacy_running?).must_equal true
      end

      it "is false otherwise" do
        expect(linux_yacy_running?).must_equal false
      end
    end

    describe "start_linux_yacy()" do
      it "runs startYACY.sh" do
        record(run: true)
        start_linux_yacy
        expect(calls).must_equal [[File.join(home, '.local', 'share', 'yacy', 'startYACY.sh')]]
      end
    end

    describe "main()" do
      it "installs Java and YaCy and starts YaCy, where none is done" do
        record(macos?: false, linux?: true, homebrew_installed_but_not_on_path?: false, java_installed?: false, linux_yacy_installed?: false, linux_yacy_running?: false, install_java: nil, install_linux_yacy: nil, start_linux_yacy: nil)
        main
        expect(calls - [:macos?, :linux?, :homebrew_installed_but_not_on_path?, :java_installed?, :linux_yacy_installed?, :linux_yacy_running?]).must_equal [:install_java, :install_linux_yacy, :start_linux_yacy]
      end

      it "puts Homebrew on PATH first, where it's installed but not on PATH" do
        record(macos?: false, linux?: true, homebrew_installed_but_not_on_path?: true, put_homebrew_on_path: nil, java_installed?: true, linux_yacy_installed?: true, linux_yacy_running?: true)
        main
        expect(calls).must_equal [:macos?, :linux?, :homebrew_installed_but_not_on_path?, :put_homebrew_on_path, :java_installed?, :linux_yacy_installed?, :linux_yacy_running?]
      end

      it "does nothing where all is done and YaCy is running" do
        record(macos?: false, linux?: true, homebrew_installed_but_not_on_path?: false, java_installed?: true, linux_yacy_installed?: true, linux_yacy_running?: true, install_java: nil, install_linux_yacy: nil, start_linux_yacy: nil)
        main
        expect(calls).must_equal [:macos?, :linux?, :homebrew_installed_but_not_on_path?, :java_installed?, :linux_yacy_installed?, :linux_yacy_running?]
      end
    end
  end

  describe "main()" do
    let(:calls){[]}

    def record(steps)
      steps.each{|name, answer| define_singleton_method(name){|*| calls << name; answer}}
    end

    it "takes the macOS steps on macOS" do
      record(macos?: true, homebrew_installed?: true, homebrew_on_path?: true, openjdk_installed?: true, openjdk_linked?: true, yacy_installed?: true, start_yacy: nil, java_installed?: true)
      main
      expect(calls).must_equal [:macos?, :homebrew_installed?, :homebrew_on_path?, :openjdk_installed?, :openjdk_linked?, :yacy_installed?, :start_yacy]
    end

    it "stops on anything else" do
      record(macos?: false, linux?: false)
      _, err = capture_io{expect{main}.must_raise SystemExit}
      expect(err).must_match /macOS and Linux only/
    end
  end

  describe "MacOS::Dmg" do
    it "is the macos.rb gem's" do
      expect(MacOS::Dmg.method(:unmount).source_location.first).must_equal File.join(Gem.loaded_specs['macos.rb'].full_gem_path, 'lib', 'MacOS', 'Dmg.rb')
    end
  end
end
