# test/InstallYaCy/Linux_test.rb

lib_dir = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'minitest/autorun'
require 'minitest/mock'
require 'rubygems/package'
require 'stringio'
require 'tmpdir'
require 'webmock/minitest'
require 'zlib'
require 'InstallYaCy/Linux'

WebMock.disable_net_connect!(allow_localhost: true)

describe InstallYaCy::Linux do
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
      expect(InstallYaCy::Linux.latest_yacy_filename).must_equal 'yacy_v1.942_202608150808_f9c4b9700.tar.gz'
    end
  end

  describe ".url_for_latest_yacy_file" do
    it "is the URL of the latest YaCy tarball" do
      expect(InstallYaCy::Linux.url_for_latest_yacy_file).must_equal 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz'
    end
  end

  describe ".homebrew_installed?" do
    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Linux" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/home/linuxbrew/.linuxbrew/bin/brew'}) do
          expect(InstallYaCy::Linux.homebrew_installed?).must_equal true
        end
      end
    end

    it "is true where brew isn't on PATH, but is in ~/.linuxbrew" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == File.join(home, '.linuxbrew', 'bin', 'brew')}) do
          expect(InstallYaCy::Linux.homebrew_installed?).must_equal true
        end
      end
    end

    it "is false where brew is only where Homebrew installs itself on macOS" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          expect(InstallYaCy::Linux.homebrew_installed?).must_equal false
        end
      end
    end
  end

  describe ".yacy_dir" do
    it "is yacy in ~/.local/share" do
      expect(InstallYaCy::Linux.yacy_dir).must_equal File.join(home, '.local', 'share', 'yacy')
    end

    it "is yacy in XDG_DATA_HOME where that is set" do
      ENV['XDG_DATA_HOME'] = '/srv/data'
      expect(InstallYaCy::Linux.yacy_dir).must_equal '/srv/data/yacy'
    end
  end

  describe ".java_installed?" do
    it "is true where java is on PATH" do
      FileUtils.stub(:which, '/usr/bin/java') do
        expect(InstallYaCy::Linux.java_installed?).must_equal true
      end
    end

    it "is false where java isn't on PATH" do
      FileUtils.stub(:which, nil) do
        expect(InstallYaCy::Linux.java_installed?).must_equal false
      end
    end
  end

  describe ".install_java" do
    it "installs the package manager's Java" do
      commands = []
      InstallYaCy::Linux.stub(:package_manager, Linux::PackageManager.new(command: 'dnf')) do
        Linux::PackageManager.stub(:system, ->(*command, **options){commands << command; true}) do
          Process.stub(:uid, 0){capture_io{InstallYaCy::Linux.install_java}}
        end
      end
      expect(commands).must_equal [['dnf install -y java-headless']]
    end

    it "stops where no package manager is found" do
      Linux::PackageManager.stub(:command, nil) do
        InstallYaCy::Linux.stub(:package_manager, Linux::PackageManager.new) do
          _, err = capture_io{expect{InstallYaCy::Linux.install_java}.must_raise SystemExit}
          expect(err).must_match /Java 17 or later/
        end
      end
    end
  end

  describe ".install_yacy" do
    before do
      stub_request(:get, 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz').to_return(status: 200, body: tarball)
    end

    it "downloads the tarball into ~/Downloads and unpacks it into ~/.local/share" do
      expect(InstallYaCy::Linux.yacy_installed?).must_equal false
      capture_subprocess_io{InstallYaCy::Linux.install_yacy}
      expect(File.exist?(File.join(home, 'Downloads', 'yacy_v1.942_202608150808_f9c4b9700.tar.gz'))).must_equal true
      expect(InstallYaCy::Linux.yacy_installed?).must_equal true
    end

    it "doesn't download the tarball again" do
      capture_subprocess_io{InstallYaCy::Linux.install_yacy}
      capture_subprocess_io{InstallYaCy::Linux.install_yacy}
      assert_requested(:get, 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.tar.gz', times: 1)
    end
  end

  describe ".yacy_running?" do
    it "is true where YaCy has left DATA/yacy.running" do
      FileUtils.mkdir_p(File.join(InstallYaCy::Linux.yacy_dir, 'DATA'))
      FileUtils.touch(File.join(InstallYaCy::Linux.yacy_dir, 'DATA', 'yacy.running'))
      expect(InstallYaCy::Linux.yacy_running?).must_equal true
    end

    it "is false otherwise" do
      expect(InstallYaCy::Linux.yacy_running?).must_equal false
    end
  end

  describe ".start_yacy" do
    it "runs startYACY.sh" do
      commands = []
      InstallYaCy::Linux.stub(:run, ->(*command, **options){commands << command; true}) do
        InstallYaCy::Linux.start_yacy
      end
      expect(commands).must_equal [[File.join(home, '.local', 'share', 'yacy', 'startYACY.sh')]]
    end

    it "doesn't run startYACY.sh where YaCy is running" do
      commands = []
      InstallYaCy::Linux.stub(:yacy_running?, true) do
        InstallYaCy::Linux.stub(:run, ->(*command, **options){commands << command; true}) do
          InstallYaCy::Linux.start_yacy
        end
      end
      expect(commands).must_equal []
    end
  end
end
