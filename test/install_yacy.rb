# test/install_yacy.rb

bin_dir = File.expand_path(File.join('..', '..', 'bin'), __FILE__)
$LOAD_PATH.unshift(bin_dir) unless $LOAD_PATH.include?(bin_dir)

require 'minitest/autorun'
require 'minitest-spec-context'
# require 'mocha/minitest'
require 'ostruct'
require 'webmock/minitest'

load 'install_yacy'

WebMock.disable_net_connect!(allow_localhost: true)

describe "install_yacy" do

  let(:latest_page) do
    root_filename = File.expand_path(File.join('..', '..', 'test', 'fixtures', 'index.html'), __FILE__)
    File.read(root_filename)
  end

  before do
    stub_request(:get, 'http://latest.yacy.net/').
      with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: latest_page)
  end

  describe "latest_macos_yacy_filename()" do
    it "returns the filename of the latest yacy for macOS" do
      expect(latest_macos_yacy_filename).must_equal 'yacy_v1.922_20191013_9964.dmg'
    end
  end

end
