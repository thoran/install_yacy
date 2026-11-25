# test/YaCy/MacOS_test.rb

lib_dir = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'minitest/autorun'
require 'minitest/mock'
require 'rubygems/package'
require 'stringio'
require 'tmpdir'
require 'webmock/minitest'
require 'zlib'
require 'YaCy/MacOS'

WebMock.disable_net_connect!(allow_localhost: true)

describe YaCy::MacOS do
  let(:latest_page){File.read(File.expand_path(File.join('..', '..', 'fixtures', 'index.html'), __FILE__))}

  before do
    stub_request(:get, 'https://download.yacy.net/').to_return(status: 200, body: latest_page)
  end

  describe ".latest_yacy_filename" do
    it "is the filename of the latest YaCy disk image" do
      expect(YaCy::MacOS.latest_yacy_filename).must_equal 'yacy_v1.942_202608150808_f9c4b9700.dmg'
    end
  end

  describe ".url_for_latest_yacy_file" do
    it "is the URL of the latest YaCy disk image" do
      expect(YaCy::MacOS.url_for_latest_yacy_file).must_equal 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.dmg'
    end
  end

  describe ".yacy_app_on_volume" do
    it "is YaCy.app on the volume named YaCy" do
      expect(YaCy::MacOS.yacy_app_on_volume).must_equal '/Volumes/YaCy/YaCy.app'
    end
  end

  describe ".homebrew_installed?" do
    it "is true where brew is on PATH" do
      FileUtils.stub(:which, '/usr/local/bin/brew') do
        expect(YaCy::MacOS.homebrew_installed?).must_equal true
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Apple silicon" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          expect(YaCy::MacOS.homebrew_installed?).must_equal true
        end
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Intel" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/usr/local/bin/brew'}) do
          expect(YaCy::MacOS.homebrew_installed?).must_equal true
        end
      end
    end

    it "is false where brew is only where Homebrew installs itself on Linux" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/home/linuxbrew/.linuxbrew/bin/brew'}) do
          expect(YaCy::MacOS.homebrew_installed?).must_equal false
        end
      end
    end
  end

  describe ".put_homebrew_on_path" do
    before do
      @path = ENV['PATH']
    end

    after do
      ENV['PATH'] = @path
    end

    it "puts the directory brew is in at the front of PATH" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          YaCy::MacOS.put_homebrew_on_path
        end
      end
      expect(ENV['PATH']).must_equal "/opt/homebrew/bin:#{@path}"
    end
  end

  describe ".java_source" do
    it "is existing, for auto, where Java 17 or later is there already" do
      stub_steps({existing_java_installed?: true}, []) do
        expect(YaCy::MacOS.java_source('auto')).must_equal 'existing'
      end
    end

    it "is homebrew, for auto, where there's no Java but Homebrew is there" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: true, macports_installed?: true}, []) do
        expect(YaCy::MacOS.java_source('auto')).must_equal 'homebrew'
      end
    end

    it "is macports, for auto, where there's no Java and no Homebrew, but MacPorts is there" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: false, macports_installed?: true}, []) do
        expect(YaCy::MacOS.java_source('auto')).must_equal 'macports'
      end
    end

    it "is adoptium, for auto, where there's no Java, no Homebrew and no MacPorts" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: false, macports_installed?: false}, []) do
        expect(YaCy::MacOS.java_source('auto')).must_equal 'adoptium'
      end
    end

    it "is the source chosen, whatever is there" do
      %w{existing homebrew macports adoptium}.each do |source|
        expect(YaCy::MacOS.java_source(source)).must_equal source
      end
    end

    it "is path for a path to a java" do
      expect(YaCy::MacOS.java_source('/opt/jdk/Contents/Home/bin/java')).must_equal 'path'
    end

    it "raises for a source unknown on macOS" do
      expect{YaCy::MacOS.java_source('system')}.must_raise ArgumentError
    end
  end

  describe ".java_version" do
    it "is the major version, from java.specification.version" do
      IO.stub(:popen, popen_reading("Property settings:\n    java.specification.version = 25\n")){expect(YaCy::MacOS.java_version('/usr/bin/java')).must_equal 25}
    end

    it "is the major version, from an old 1.x version" do
      IO.stub(:popen, popen_reading("    java.specification.version = 1.8\n")){expect(YaCy::MacOS.java_version('/usr/bin/java')).must_equal 8}
    end

    it "is 0 where java can't be run" do
      expect(YaCy::MacOS.java_version('/nonexistent/java')).must_equal 0
    end
  end

  describe ".install_homebrew_java" do
    it "installs Homebrew and OpenJDK, and links OpenJDK, where none is done and Homebrew may be installed" do
      calls = []
      steps = {homebrew_installed?: false, install_homebrew: nil, homebrew_on_path?: true, openjdk_installed?: false, install_openjdk: nil, openjdk_linked?: false, link_openjdk: nil}
      capture_io{stub_steps(steps, calls){YaCy::MacOS.install_homebrew_java(allow_homebrew_install: true)}}
      expect(calls).must_equal [:homebrew_installed?, :install_homebrew, :homebrew_on_path?, :openjdk_installed?, :install_openjdk, :openjdk_linked?, :link_openjdk]
    end

    it "only links OpenJDK where Homebrew and OpenJDK are there" do
      calls = []
      steps = {homebrew_installed?: true, homebrew_on_path?: true, openjdk_installed?: true, openjdk_linked?: false, link_openjdk: nil}
      stub_steps(steps, calls){YaCy::MacOS.install_homebrew_java}
      expect(calls).must_equal [:homebrew_installed?, :homebrew_on_path?, :openjdk_installed?, :openjdk_linked?, :link_openjdk]
    end

    it "stops, rather than installing Homebrew, where there's no terminal to ask at" do
      calls = []
      $stdin.stub(:tty?, false) do
        _, err = capture_io{stub_steps({homebrew_installed?: false, install_homebrew: nil}, calls){expect{YaCy::MacOS.install_homebrew_java}.must_raise SystemExit}}
        expect(err).must_match /--install-homebrew/
      end
      expect(calls).must_equal [:homebrew_installed?]
    end

    it "stops, rather than installing Homebrew, where the answer isn't yes" do
      calls = []
      $stdin.stub(:tty?, true) do
        $stdin.stub(:gets, "\n") do
          capture_io{stub_steps({homebrew_installed?: false, install_homebrew: nil}, calls){expect{YaCy::MacOS.install_homebrew_java}.must_raise SystemExit}}
        end
      end
      expect(calls).must_equal [:homebrew_installed?]
    end

    it "installs Homebrew where the answer is yes" do
      calls = []
      steps = {homebrew_installed?: false, install_homebrew: nil, homebrew_on_path?: true, openjdk_installed?: true, openjdk_linked?: true}
      $stdin.stub(:tty?, true) do
        $stdin.stub(:gets, "y\n") do
          out, _ = capture_io{stub_steps(steps, calls){YaCy::MacOS.install_homebrew_java}}
          expect(out).must_match /Install it, to get Java from it\? \[y\/N\] Java: installing Homebrew\./
        end
      end
      expect(calls).must_include :install_homebrew
    end
  end

  describe "in a home of its own" do
    let(:home){Dir.mktmpdir}

    before do
      @home = ENV['HOME']
      ENV['HOME'] = home
    end

    after do
      ENV['HOME'] = @home
      FileUtils.rm_rf(home)
    end

    describe ".link_openjdk" do
      it "links Homebrew's OpenJDK into ~/Library/Java/JavaVirtualMachines, without sudo" do
        jdk = File.join(home, 'openjdk.jdk')
        FileUtils.mkdir_p(jdk)
        YaCy::MacOS.stub(:openjdk_jdk_path, jdk) do
          YaCy::MacOS.stub(:run, ->(*){flunk "Nothing should be run."}){YaCy::MacOS.link_openjdk}
        end
        expect(File.readlink(File.join(home, 'Library', 'Java', 'JavaVirtualMachines', 'openjdk.jdk'))).must_equal jdk
        expect(YaCy::MacOS.openjdk_linked?).must_equal true
      end
    end

    describe ".install_adoptium_java" do
      let(:jre_tarball){tarball('jdk-25.0.5.1+2-jre/Contents/Home/bin/java')}
      let(:jre_link){'https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5.1%2B2/OpenJDK25U-jre_aarch64_mac_hotspot_25.0.5.1_2.tar.gz'}

      def stub_adoptium(checksum)
        YaCy::MacOS.instance_variable_set(:@latest_lts_java_version, nil)
        YaCy::MacOS.instance_variable_set(:@adoptium_jre_package, nil)
        stub_request(:get, 'https://api.adoptium.net/v3/info/available_releases').to_return(status: 200, body: {most_recent_lts: 25}.to_json)
        stub_request(:get, %r{\Ahttps://api\.adoptium\.net/v3/assets/latest/25/hotspot\?.*os=mac}).to_return(status: 200, body: [{binary: {package: {name: File.basename(jre_link), link: jre_link, size: 56_303_568, checksum: checksum}}}].to_json)
        stub_request(:get, jre_link).to_return(status: 200, body: jre_tarball)
      end

      it "unpacks Adoptium's JRE into ~/Library/Java/JavaVirtualMachines" do
        stub_adoptium(Digest::SHA256.hexdigest(jre_tarball))
        out, _ = capture_subprocess_io{YaCy::MacOS.install_adoptium_java}
        expect(out).must_match /Java: installing Adoptium's Temurin 25 JRE into #{Regexp.escape(File.join(home, 'Library', 'Java', 'JavaVirtualMachines'))} \(56 MB\)\./
        expect(File.exist?(File.join(home, 'Library', 'Java', 'JavaVirtualMachines', 'jdk-25.0.5.1+2-jre', 'Contents', 'Home', 'bin', 'java'))).must_equal true
      end

      it "stops where the download doesn't match Adoptium's checksum" do
        stub_adoptium('0' * 64)
        _, err = capture_subprocess_io{expect{YaCy::MacOS.install_adoptium_java}.must_raise SystemExit}
        expect(err).must_match /doesn't match Adoptium's checksum/
        expect(Dir.exist?(File.join(home, 'Library', 'Java', 'JavaVirtualMachines', 'jdk-25.0.5.1+2-jre'))).must_equal false
      end
    end

    describe ".install_path_java" do
      it "links the bundle a java is in into ~/Library/Java/JavaVirtualMachines" do
        java = File.join(home, 'jdks', 'temurin-21.jdk', 'Contents', 'Home', 'bin', 'java')
        FileUtils.mkdir_p(File.dirname(java))
        FileUtils.touch(java)
        File.chmod(0755, java)
        YaCy::MacOS.stub(:java_version, 21) do
          capture_io{YaCy::MacOS.install_path_java(java)}
          expect(YaCy::MacOS.path_java_installed?(java)).must_equal true
        end
        expect(File.readlink(File.join(home, 'Library', 'Java', 'JavaVirtualMachines', 'temurin-21.jdk'))).must_equal File.join(home, 'jdks', 'temurin-21.jdk')
      end

      it "keeps the path as given where it's in a bundle, rather than where its links lead, as Homebrew's opt directory does across upgrades" do
        FileUtils.mkdir_p(File.join(home, 'Cellar', 'openjdk', '27.0.1.1', 'libexec', 'openjdk.jdk', 'Contents', 'Home', 'bin'))
        FileUtils.mkdir_p(File.join(home, 'opt'))
        File.symlink(File.join(home, 'Cellar', 'openjdk', '27.0.1.1'), File.join(home, 'opt', 'openjdk'))
        expect(YaCy::MacOS.java_bundle(File.join(home, 'opt', 'openjdk', 'libexec', 'openjdk.jdk', 'Contents', 'Home', 'bin', 'java'))).must_equal File.join(home, 'opt', 'openjdk', 'libexec', 'openjdk.jdk')
      end

      it "follows a java which isn't in a bundle to the bundle it leads to" do
        java = File.join(home, 'jdks', 'temurin-21.jdk', 'Contents', 'Home', 'bin', 'java')
        FileUtils.mkdir_p(File.dirname(java))
        FileUtils.touch(java)
        FileUtils.mkdir_p(File.join(home, 'bin'))
        File.symlink(java, File.join(home, 'bin', 'java'))
        expect(YaCy::MacOS.java_bundle(File.join(home, 'bin', 'java'))).must_equal File.realpath(File.join(home, 'jdks', 'temurin-21.jdk'))
      end

      it "stops for a java which isn't in a bundle" do
        java = File.join(home, 'bin', 'java')
        FileUtils.mkdir_p(File.dirname(java))
        FileUtils.touch(java)
        File.chmod(0755, java)
        YaCy::MacOS.stub(:java_version, 21) do
          _, err = capture_io{expect{YaCy::MacOS.install_path_java(java)}.must_raise SystemExit}
          expect(err).must_match /Contents\/Home\/bin\/java/
        end
      end

      it "stops for a java older than 17" do
        YaCy::MacOS.stub(:java_version, 11) do
          _, err = capture_io{expect{YaCy::MacOS.install_path_java('/usr/bin/java')}.must_raise SystemExit}
          expect(err).must_match /isn't Java 17 or later/
        end
      end
    end

    describe ".yacy_installed?" do
      it "is true where YaCy.app is in ~/Applications" do
        FileUtils.mkdir_p(File.join(home, 'Applications', 'YaCy.app'))
        expect(YaCy::MacOS.yacy_installed?).must_equal true
        expect(YaCy::MacOS.yacy_app).must_equal File.join(home, 'Applications', 'YaCy.app')
      end
    end

    describe ".yacy_data_dir" do
      it "is DATA in ~/Library/Application Support/net.yacy.YaCy, apart from YaCy.app" do
        expect(YaCy::MacOS.yacy_data_dir).must_equal File.join(home, 'Library', 'Application Support', 'net.yacy.YaCy', 'DATA')
      end
    end

    describe ".yacy_scripts_dir" do
      it "is Contents/MacOS in YaCy.app" do
        FileUtils.mkdir_p(File.join(home, 'Applications', 'YaCy.app'))
        expect(YaCy::MacOS.yacy_scripts_dir).must_equal File.join(home, 'Applications', 'YaCy.app', 'Contents', 'MacOS')
      end
    end

    describe "with or without SSH" do
      before do
        @ssh_connection = ENV['SSH_CONNECTION']
        ENV.delete('SSH_CONNECTION')
      end

      after do
        ENV['SSH_CONNECTION'] = @ssh_connection
      end

      describe ".display?" do
        it "is true where yacy isn't run over SSH" do
          expect(YaCy::MacOS.display?).must_equal true
        end

        it "is false where yacy is run over SSH" do
          ENV['SSH_CONNECTION'] = '192.0.2.1 50000 192.0.2.2 22'
          expect(YaCy::MacOS.display?).must_equal false
        end
      end

      describe ".open_yacy_page" do
        it "opens the page YaCy opens as it starts" do
          commands = []
          YaCy::MacOS.stub(:run, ->(*command, **options){commands << command; true}){YaCy::MacOS.open_yacy_page}
          expect(commands).must_equal [['open', 'http://localhost:8090/index.html']]
        end

        it "gives YaCy's address where yacy is run over SSH" do
          ENV['SSH_CONNECTION'] = '192.0.2.1 50000 192.0.2.2 22'
          commands = []
          out, _ = capture_io do
            YaCy::MacOS.stub(:run, ->(*command, **options){commands << command; true}){YaCy::MacOS.open_yacy_page}
          end
          expect(commands).must_equal []
          expect(out).must_equal "YaCy is running at http://localhost:8090/\n"
        end
      end
    end
  end

  describe ".install_macports_java" do
    it "installs MacPorts' openjdk25, with sudo" do
      commands = []
      YaCy::MacOS.stub(:macports_path, '/opt/local/bin/port') do
        YaCy::MacOS.stub(:run, ->(*command, **options){commands << command; true}) do
          capture_io{YaCy::MacOS.install_macports_java}
        end
      end
      expect(commands).must_equal [['sudo /opt/local/bin/port install openjdk25']]
    end

    it "stops, rather than installing MacPorts, where it isn't there" do
      YaCy::MacOS.stub(:macports_path, nil) do
        _, err = capture_io{expect{YaCy::MacOS.install_macports_java}.must_raise SystemExit}
        expect(err).must_match /macports\.org/
      end
    end
  end

  describe ".install_java" do
    it "stops for existing, where there's no Java 17 or later" do
      YaCy::MacOS.stub(:existing_java_installed?, false) do
        _, err = capture_io{expect{YaCy::MacOS.install_java('existing')}.must_raise SystemExit}
        expect(err).must_match /No Java 17 or later is installed/
      end
    end

    it "passes allow_homebrew_install on to install_homebrew_java" do
      given = nil
      YaCy::MacOS.stub(:install_homebrew_java, ->(allow_homebrew_install:){given = allow_homebrew_install}) do
        YaCy::MacOS.install_java('homebrew', allow_homebrew_install: true)
      end
      expect(given).must_equal true
    end
  end

  describe "MacOS::Dmg" do
    it "is the macos.rb gem's" do
      expect(MacOS::Dmg.method(:unmount).source_location.first).must_equal File.join(Gem.loaded_specs['macos.rb'].full_gem_path, 'lib', 'MacOS', 'Dmg.rb')
    end
  end

  # Stands in for IO.popen, giving its block the output as if from the command.
  def popen_reading(output)
    ->(*, **, &block){block.call(StringIO.new(output))}
  end

  # A tarball holding an executable at path, in the directories path is in.
  def tarball(path)
    io = StringIO.new
    Zlib::GzipWriter.wrap(io) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        directories = File.dirname(path).split('/')
        directories.each_index{|i| tar.mkdir(directories[0..i].join('/'), 0755)}
        tar.add_file_simple(path, 0755, 10){|file| file.write("#!/bin/sh\n")}
      end
    end
    io.string
  end

  # Stubs each step on YaCy::MacOS to answer as given, recording the order they're called in.
  def stub_steps(steps, calls, &block)
    steps.reduce(block) do |inner, (name, answer)|
      ->{YaCy::MacOS.stub(name, ->(*){calls << name; answer}){inner.call}}
    end.call
  end
end
