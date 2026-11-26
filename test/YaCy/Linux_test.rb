# test/YaCy/Linux_test.rb

lib_dir = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'minitest/autorun'
require 'minitest/mock'
require 'rubygems/package'
require 'stringio'
require 'tmpdir'
require 'webmock/minitest'
require 'zlib'
require 'YaCy/Linux'

WebMock.disable_net_connect!(allow_localhost: true)

describe YaCy::Linux do
  let(:latest_page){File.read(File.expand_path(File.join('..', '..', 'fixtures', 'index.html'), __FILE__))}
  let(:home){Dir.mktmpdir}

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
    stub_request(:get, 'https://download.yacy.net/').to_return(status: 200, body: latest_page)
    @env = ENV.to_h.slice('HOME', 'XDG_DATA_HOME')
    ENV['HOME'] = home
    ENV.delete('XDG_DATA_HOME')
  end

  after do
    ENV.update(@env)
    ENV.delete('XDG_DATA_HOME') unless @env['XDG_DATA_HOME']
    FileUtils.rm_rf(home)
  end

  describe ".latest_yacy_filename" do
    it "is the filename of the latest YaCy tarball, not its signature" do
      expect(YaCy::Linux.latest_yacy_filename).must_equal 'yacy_v1.942_202608150808_f9c4b9700.tar.gz'
    end
  end

  describe ".url_for_latest_yacy_file" do
    it "is the URL of the latest YaCy tarball" do
      expect(YaCy::Linux.url_for_latest_yacy_file).must_equal 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz'
    end
  end

  describe ".homebrew_installed?" do
    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Linux" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/home/linuxbrew/.linuxbrew/bin/brew'}) do
          expect(YaCy::Linux.homebrew_installed?).must_equal true
        end
      end
    end

    it "is true where brew isn't on PATH, but is in ~/.linuxbrew" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == File.join(home, '.linuxbrew', 'bin', 'brew')}) do
          expect(YaCy::Linux.homebrew_installed?).must_equal true
        end
      end
    end

    it "is false where brew is only where Homebrew installs itself on macOS" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          expect(YaCy::Linux.homebrew_installed?).must_equal false
        end
      end
    end
  end

  describe ".yacy_dir" do
    it "is yacy in ~/.local/share" do
      expect(YaCy::Linux.yacy_dir).must_equal File.join(home, '.local', 'share', 'yacy')
    end

    it "is yacy in XDG_DATA_HOME where that is set" do
      ENV['XDG_DATA_HOME'] = '/srv/data'
      expect(YaCy::Linux.yacy_dir).must_equal '/srv/data/yacy'
    end
  end

  describe ".yacy_data_dir" do
    it "is DATA in YaCy's own directory" do
      expect(YaCy::Linux.yacy_data_dir).must_equal File.join(home, '.local', 'share', 'yacy', 'DATA')
    end
  end

  describe ".yacy_scripts_dir" do
    it "is YaCy's own directory" do
      expect(YaCy::Linux.yacy_scripts_dir).must_equal File.join(home, '.local', 'share', 'yacy')
    end
  end

  describe ".java_source" do
    before do
      YaCy::Linux.instance_variable_set(:@system_package_manager, nil)
    end

    it "is existing, for auto, where Java 17 or later is on PATH" do
      stub_steps({existing_java_installed?: true}) do
        expect(YaCy::Linux.java_source('auto')).must_equal 'existing'
      end
    end

    it "is homebrew, for auto, where there's no Java but Homebrew is there" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: true, root?: false, system_package_manager: Linux::PackageManager.new(command: 'apt-get')}) do
        expect(YaCy::Linux.java_source('auto')).must_equal 'homebrew'
      end
    end

    it "is system, for auto, where there's no Java and Homebrew is there but this is root" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: true, root?: true, system_package_manager: Linux::PackageManager.new(command: 'apt-get')}) do
        expect(YaCy::Linux.java_source('auto')).must_equal 'system'
      end
    end

    it "is system, for auto, where there's no Java and no Homebrew" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: false, system_package_manager: Linux::PackageManager.new(command: 'dnf')}) do
        expect(YaCy::Linux.java_source('auto')).must_equal 'system'
      end
    end

    it "is adoptium, for auto, where there's no Java and no package manager" do
      stub_steps({existing_java_installed?: false, homebrew_installed?: false, system_package_manager: nil}) do
        expect(YaCy::Linux.java_source('auto')).must_equal 'adoptium'
      end
    end

    it "is the source chosen, whatever is there" do
      %w{existing homebrew system adoptium}.each do |source|
        expect(YaCy::Linux.java_source(source)).must_equal source
      end
    end

    it "raises for a source unknown on Linux" do
      expect{YaCy::Linux.java_source('macports')}.must_raise ArgumentError
    end
  end

  describe ".existing_java_installed?" do
    it "is true where java on PATH is 17 or later" do
      stub_steps({java_on_path: '/usr/bin/java', adoptium_java_installed?: false}) do
        File.stub(:executable?, true) do
          YaCy::Linux.stub(:java_version, 21){expect(YaCy::Linux.existing_java_installed?).must_equal true}
        end
      end
    end

    it "is false where java on PATH is older than 17, and there's no JRE from Adoptium" do
      stub_steps({java_on_path: '/usr/bin/java', adoptium_java_installed?: false}) do
        File.stub(:executable?, true) do
          YaCy::Linux.stub(:java_version, 11){expect(YaCy::Linux.existing_java_installed?).must_equal false}
        end
      end
    end

    it "is true where there's no java on PATH, but there's a JRE from Adoptium" do
      stub_steps({java_on_path: nil, adoptium_java_installed?: true}) do
        expect(YaCy::Linux.existing_java_installed?).must_equal true
      end
    end
  end

  describe ".system_package_manager" do
    before do
      YaCy::Linux.instance_variable_set(:@system_package_manager, nil)
    end

    after do
      YaCy::Linux.instance_variable_set(:@system_package_manager, nil)
    end

    it "is the distribution's, not Homebrew, where both are there" do
      Linux::PackageManager.stub(:command, ->(except: []){(%w{brew apt-get} - except).first}) do
        expect(YaCy::Linux.system_package_manager.command).must_equal 'apt-get'
      end
    end

    it "is nil where only Homebrew is there" do
      Linux::PackageManager.stub(:command, ->(except: []){(%w{brew} - except).first}) do
        expect(YaCy::Linux.system_package_manager).must_be_nil
      end
    end
  end

  describe ".install_system_java" do
    it "installs the package manager's Java" do
      commands = []
      YaCy::Linux.stub(:system_package_manager, Linux::PackageManager.new(command: 'dnf')) do
        Linux::PackageManager.stub(:system, ->(*command, **options){commands << command; true}) do
          out, _ = Process.stub(:uid, 0){capture_io{YaCy::Linux.install_system_java}}
          expect(out).must_match /Java: installing java-headless with dnf\./
        end
      end
      expect(commands).must_equal [['dnf install -y java-headless']]
    end

    it "stops where no package manager is found" do
      YaCy::Linux.stub(:system_package_manager, nil) do
        _, err = capture_io{expect{YaCy::Linux.install_system_java}.must_raise SystemExit}
        expect(err).must_match /Java 17 or later/
      end
    end
  end

  describe ".install_homebrew_java" do
    it "stops as root, since Homebrew won't run as root" do
      YaCy::Linux.stub(:root?, true) do
        _, err = capture_io{expect{YaCy::Linux.install_homebrew_java}.must_raise SystemExit}
        expect(err).must_match /won't run as root/
      end
    end

    it "installs Homebrew's openjdk, without sudo" do
      commands = []
      stub_steps({root?: false, homebrew_installed?: true, homebrew_on_path?: true}) do
        Linux::PackageManager.stub(:system, ->(*command, **options){commands << command; true}) do
          Process.stub(:uid, 1000){capture_io{YaCy::Linux.install_homebrew_java}}
        end
      end
      expect(commands).must_equal [['brew install openjdk']]
    end

    it "stops, rather than installing Homebrew, where there's no terminal to ask at" do
      calls = []
      $stdin.stub(:tty?, false) do
        stub_steps({root?: false, homebrew_installed?: false, install_homebrew: nil}, calls) do
          _, err = capture_io{expect{YaCy::Linux.install_homebrew_java}.must_raise SystemExit}
          expect(err).must_match /--install-homebrew/
        end
      end
      expect(calls).wont_include :install_homebrew
    end
  end

  describe ".adoptium_os" do
    it "is alpine-linux where Ruby is built on musl" do
      YaCy::Linux.stub(:musl?, true){expect(YaCy::Linux.adoptium_os).must_equal 'alpine-linux'}
    end

    it "is linux otherwise" do
      YaCy::Linux.stub(:musl?, false){expect(YaCy::Linux.adoptium_os).must_equal 'linux'}
    end
  end

  describe ".install_adoptium_java" do
    let(:jre_tarball){tarball_holding('jdk-25.0.5.1+2-jre/bin/java')}
    let(:jre_link){'https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5.1%2B2/OpenJDK25U-jre_x64_linux_hotspot_25.0.5.1_2.tar.gz'}

    before do
      YaCy::Linux.instance_variable_set(:@latest_lts_java_version, nil)
      YaCy::Linux.instance_variable_set(:@adoptium_jre_package, nil)
      stub_request(:get, 'https://api.adoptium.net/v3/info/available_releases').to_return(status: 200, body: {most_recent_lts: 25}.to_json)
      stub_request(:get, %r{\Ahttps://api\.adoptium\.net/v3/assets/latest/25/hotspot\?.*os=(alpine-)?linux}).to_return(status: 200, body: [{binary: {package: {name: File.basename(jre_link), link: jre_link, size: 52_000_000, checksum: Digest::SHA256.hexdigest(jre_tarball)}}}].to_json)
      stub_request(:get, jre_link).to_return(status: 200, body: jre_tarball)
    end

    it "unpacks Adoptium's JRE into yacy-jre in ~/.local/share" do
      out, _ = capture_subprocess_io{YaCy::Linux.install_adoptium_java}
      expect(out).must_match /Java: installing Adoptium's Temurin 25 JRE into #{Regexp.escape(File.join(home, '.local', 'share', 'yacy-jre'))} \(52 MB\)\./
      expect(YaCy::Linux.adoptium_java).must_equal File.join(home, '.local', 'share', 'yacy-jre', 'jdk-25.0.5.1+2-jre', 'bin', 'java')
    end
  end

  describe ".install_path_java" do
    before do
      @path = ENV['PATH']
    end

    after do
      ENV['PATH'] = @path
    end

    it "puts the directory the java is in at the front of PATH" do
      File.stub(:executable?, true) do
        YaCy::Linux.stub(:java_version, 21){capture_io{YaCy::Linux.install_path_java('/opt/jdk-21/bin/java')}}
      end
      expect(ENV['PATH']).must_equal "/opt/jdk-21/bin:#{@path}"
    end

    it "stops for a java older than 17" do
      File.stub(:executable?, true) do
        YaCy::Linux.stub(:java_version, 11) do
          _, err = capture_io{expect{YaCy::Linux.install_path_java('/opt/jdk-11/bin/java')}.must_raise SystemExit}
          expect(err).must_match /isn't Java 17 or later/
        end
      end
    end
  end

  describe ".install_yacy" do
    before do
      stub_request(:get, 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz').to_return(status: 200, body: tarball)
    end

    it "downloads the tarball into ~/Downloads and unpacks it into ~/.local/share" do
      expect(YaCy::Linux.yacy_installed?).must_equal false
      capture_subprocess_io{YaCy::Linux.install_yacy}
      expect(File.exist?(File.join(home, 'Downloads', 'yacy_v1.942_202608150808_f9c4b9700.tar.gz'))).must_equal true
      expect(YaCy::Linux.yacy_installed?).must_equal true
    end

    it "doesn't download the tarball again" do
      capture_subprocess_io{YaCy::Linux.install_yacy}
      capture_subprocess_io{YaCy::Linux.install_yacy}
      assert_requested(:get, 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz', times: 1)
    end
  end

  describe ".start_yacy" do
    before do
      @path = ENV['PATH']
    end

    after do
      ENV['PATH'] = @path
    end

    it "runs startYACY.sh" do
      commands = []
      stub_steps({suitable_java?: true}) do
        YaCy::Linux.stub(:run, ->(*command, **options){commands << command; true}){YaCy::Linux.start_yacy}
      end
      expect(commands).must_equal [[File.join(home, '.local', 'share', 'yacy', 'startYACY.sh')]]
      expect(ENV['PATH']).must_equal @path
    end

    it "puts Adoptium's JRE on PATH first, where there's no other suitable Java there" do
      java = File.join(home, '.local', 'share', 'yacy-jre', 'jdk-25.0.5.1+2-jre', 'bin', 'java')
      stub_steps({suitable_java?: false, adoptium_java_installed?: true, adoptium_java: java}) do
        YaCy::Linux.stub(:run, ->(*command, **options){true}){YaCy::Linux.start_yacy}
      end
      expect(ENV['PATH']).must_equal "#{File.dirname(java)}:#{@path}"
    end

    it "doesn't run startYACY.sh where YaCy is running" do
      commands = []
      YaCy::Linux.stub(:yacy_running?, true) do
        YaCy::Linux.stub(:run, ->(*command, **options){commands << command; true}) do
          YaCy::Linux.start_yacy
        end
      end
      expect(commands).must_equal []
    end
  end

  describe ".open_yacy_page" do
    before do
      @display = ENV.to_h.slice('DISPLAY', 'WAYLAND_DISPLAY')
      ENV.delete('DISPLAY')
      ENV.delete('WAYLAND_DISPLAY')
    end

    after do
      ENV.update(@display)
    end

    it "opens the page YaCy opens as it starts with xdg-open where there's a display" do
      ENV['DISPLAY'] = ':0'
      commands = []
      FileUtils.stub(:which, '/usr/bin/xdg-open') do
        YaCy::Linux.stub(:run, ->(*command, **options){commands << command; true}){YaCy::Linux.open_yacy_page}
      end
      expect(commands).must_equal [['xdg-open', 'http://localhost:8090/index.html']]
    end

    it "gives YaCy's address where there's no display" do
      commands = []
      out, _ = capture_io do
        YaCy::Linux.stub(:run, ->(*command, **options){commands << command; true}){YaCy::Linux.open_yacy_page}
      end
      expect(commands).must_equal []
      expect(out).must_equal "YaCy is running at http://localhost:8090/\n"
    end
  end

  describe "uninstalling" do
    let(:yacy_dir){File.join(home, '.local', 'share', 'yacy')}
    let(:downloads){File.join(home, 'Downloads')}

    describe ".remove_yacy" do
      it "removes all of YaCy but its DATA" do
        FileUtils.mkdir_p(File.join(yacy_dir, 'DATA', 'SETTINGS'))
        FileUtils.mkdir_p(File.join(yacy_dir, 'lib'))
        FileUtils.touch(File.join(yacy_dir, 'startYACY.sh'))
        capture_io{YaCy::Linux.remove_yacy}
        expect(Dir.children(yacy_dir)).must_equal ['DATA']
        expect(YaCy::Linux.yacy_installed?).must_equal false
      end

      it "does nothing where YaCy isn't installed" do
        out, _ = capture_io{YaCy::Linux.remove_yacy}
        expect(out).must_equal ''
      end
    end

    describe ".remove_yacy_data" do
      it "removes YaCy's directory, DATA and all" do
        FileUtils.mkdir_p(File.join(yacy_dir, 'DATA', 'SETTINGS'))
        capture_io{YaCy::Linux.remove_yacy_data}
        expect(Dir.exist?(yacy_dir)).must_equal false
      end
    end

    describe "Adoptium's JRE" do
      let(:jre_dir){File.join(home, '.local', 'share', 'yacy-jre')}

      before do
        FileUtils.mkdir_p(File.join(jre_dir, 'jdk-25.0.5.1+2-jre', 'bin'))
        FileUtils.mkdir_p(downloads)
        %w{OpenJDK25U-jre_x64_linux_hotspot_25.0.5.1_2.tar.gz OpenJDK25U-jdk_x64_linux_hotspot_25.0.5.1_2.tar.gz}.each{|name| FileUtils.touch(File.join(downloads, name))}
      end

      it "is removed by default" do
        expect(YaCy::Linux.remove_adoptium_java_by_default?).must_equal true
      end

      it "is removed, with yacy-jre and its download, and nothing else in ~/Downloads" do
        capture_io{YaCy::Linux.remove_adoptium_java}
        expect(Dir.exist?(jre_dir)).must_equal false
        expect(Dir.children(downloads)).must_equal ['OpenJDK25U-jdk_x64_linux_hotspot_25.0.5.1_2.tar.gz']
      end

      it "says where it's left, and how to remove it" do
        out, _ = capture_io{YaCy::Linux.give_adoptium_java_kept}
        expect(out).must_equal "Java: Adoptium's JRE is left in #{File.join(jre_dir, 'jdk-25.0.5.1+2-jre')}. yacy uninstall --jre=remove removes it.\n"
      end
    end

    describe ".remove_yacy_downloads" do
      it "removes YaCy's tarballs from ~/Downloads, and nothing else there" do
        FileUtils.mkdir_p(downloads)
        %w{yacy_v1.940_202405270005_70454654f.tar.gz yacy_v1.942_202608150808_f9c4b9700.tar.gz other.tar.gz}.each{|name| FileUtils.touch(File.join(downloads, name))}
        capture_io{YaCy::Linux.remove_yacy_downloads}
        expect(Dir.children(downloads)).must_equal ['other.tar.gz']
      end
    end
  end

  # A tarball holding an executable at path, in the directories path is in.
  def tarball_holding(path)
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

  # Stubs each step on YaCy::Linux to answer as given, recording the order they're called in.
  def stub_steps(steps, calls = [], &block)
    steps.reduce(block) do |inner, (name, answer)|
      ->{YaCy::Linux.stub(name, ->(*, **){calls << name; answer}){inner.call}}
    end.call
  end
end
