# test/install_yacy.rb

bin_dir = File.expand_path(File.join('..', '..', 'bin'), __FILE__)
$LOAD_PATH.unshift(bin_dir) unless $LOAD_PATH.include?(bin_dir)

require 'minitest/autorun'
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

  describe "MacOS::Dmg" do
    it "is the macos.rb gem's" do
      expect(MacOS::Dmg.method(:unmount).source_location.first).must_equal File.join(Gem.loaded_specs['macos.rb'].full_gem_path, 'lib', 'MacOS', 'Dmg.rb')
    end
  end
end
