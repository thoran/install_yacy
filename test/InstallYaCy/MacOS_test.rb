# test/InstallYaCy/MacOS_test.rb

lib_dir = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'minitest/autorun'
require 'minitest/mock'
require 'webmock/minitest'
require 'InstallYaCy/MacOS'

WebMock.disable_net_connect!(allow_localhost: true)

describe InstallYaCy::MacOS do
  let(:latest_page){File.read(File.expand_path(File.join('..', '..', 'fixtures', 'index.html'), __FILE__))}

  before do
    stub_request(:get, 'https://download.yacy.net/').to_return(status: 200, body: latest_page)
  end

  describe ".latest_yacy_filename" do
    it "is the filename of the latest YaCy disk image" do
      expect(InstallYaCy::MacOS.latest_yacy_filename).must_equal 'yacy_v1.942_202608150808_f9c4b9700.dmg'
    end
  end

  describe ".url_for_latest_yacy_file" do
    it "is the URL of the latest YaCy disk image" do
      expect(InstallYaCy::MacOS.url_for_latest_yacy_file).must_equal 'https://download.yacy.net/yacy_v1.942_202608150808_f9c4b9700.dmg'
    end
  end

  describe ".yacy_app_on_volume" do
    it "is YaCy.app on the volume named YaCy" do
      expect(InstallYaCy::MacOS.yacy_app_on_volume).must_equal '/Volumes/YaCy/YaCy.app'
    end
  end

  describe ".homebrew_installed?" do
    it "is true where brew is on PATH" do
      FileUtils.stub(:which, '/usr/local/bin/brew') do
        expect(InstallYaCy::MacOS.homebrew_installed?).must_equal true
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Apple silicon" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/opt/homebrew/bin/brew'}) do
          expect(InstallYaCy::MacOS.homebrew_installed?).must_equal true
        end
      end
    end

    it "is true where brew isn't on PATH, but is where Homebrew installs itself on Intel" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/usr/local/bin/brew'}) do
          expect(InstallYaCy::MacOS.homebrew_installed?).must_equal true
        end
      end
    end

    it "is false where brew is only where Homebrew installs itself on Linux" do
      FileUtils.stub(:which, nil) do
        File.stub(:executable?, ->(path){path == '/home/linuxbrew/.linuxbrew/bin/brew'}) do
          expect(InstallYaCy::MacOS.homebrew_installed?).must_equal false
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
          InstallYaCy::MacOS.put_homebrew_on_path
        end
      end
      expect(ENV['PATH']).must_equal "/opt/homebrew/bin:#{@path}"
    end
  end

  describe ".install_java" do
    it "installs Homebrew and OpenJDK, and links OpenJDK, where none is done" do
      calls = []
      steps = {homebrew_installed?: false, install_homebrew: nil, homebrew_on_path?: true, openjdk_installed?: false, install_openjdk: nil, openjdk_linked?: false, link_openjdk: nil}
      stub_steps(steps, calls){InstallYaCy::MacOS.install_java}
      expect(calls).must_equal [:homebrew_installed?, :install_homebrew, :homebrew_on_path?, :openjdk_installed?, :install_openjdk, :openjdk_linked?, :link_openjdk]
    end
  end

  describe "MacOS::Dmg" do
    it "is the macos.rb gem's" do
      expect(MacOS::Dmg.method(:unmount).source_location.first).must_equal File.join(Gem.loaded_specs['macos.rb'].full_gem_path, 'lib', 'MacOS', 'Dmg.rb')
    end
  end

  # Stubs each step on InstallYaCy::MacOS to answer as given, recording the order they're called in.
  def stub_steps(steps, calls, &block)
    steps.reduce(block) do |inner, (name, answer)|
      ->{InstallYaCy::MacOS.stub(name, ->(*){calls << name; answer}){inner.call}}
    end.call
  end
end
