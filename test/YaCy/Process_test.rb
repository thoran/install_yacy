# test/YaCy/Process_test.rb

lib_dir = File.expand_path(File.join('..', '..', '..', 'lib'), __FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'fileutils'
require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'webmock/minitest'
require 'YaCy/Process'

WebMock.disable_net_connect!(allow_localhost: true)

describe YaCy::Process do
  let(:dir){Dir.mktmpdir}

  # A platform as YaCy::Process is given one, with its DATA and its scripts in dir.
  let(:yacy) do
    data_dir = File.join(dir, 'DATA')
    scripts_dir = File.join(dir, 'scripts')
    Module.new do
      include YaCy::Process
      extend self
      define_method(:yacy_data_dir){data_dir}
      define_method(:yacy_scripts_dir){scripts_dir}
    end
  end

  def settings(text)
    FileUtils.mkdir_p(File.join(dir, 'DATA', 'SETTINGS'))
    File.write(File.join(dir, 'DATA', 'SETTINGS', 'yacy.conf'), text)
  end

  after do
    FileUtils.rm_rf(dir)
  end

  describe ".yacy_setting" do
    it "is the setting's value from YaCy's settings" do
      settings("portForwarding=false\nport=8091\n")
      expect(yacy.yacy_setting('port')).must_equal '8091'
    end

    it "is nil where YaCy's settings don't have it" do
      settings("port=8091\n")
      expect(yacy.yacy_setting('browserPopUpTrigger')).must_be_nil
    end

    it "is nil where there are no settings yet" do
      expect(yacy.yacy_setting('port')).must_be_nil
    end
  end

  describe ".yacy_url" do
    it "has the port from YaCy's settings" do
      settings("portForwarding=false\nport=8091\n")
      expect(yacy.yacy_url).must_equal 'http://localhost:8091/'
    end

    it "has YaCy's default port where there are no settings yet" do
      expect(yacy.yacy_url).must_equal 'http://localhost:8090/'
    end
  end

  describe ".yacy_page_url" do
    it "has the page browserPopUpPage gives in YaCy's settings" do
      settings("port=8091\nbrowserPopUpPage=ConfigBasic.html\n")
      expect(yacy.yacy_page_url).must_equal 'http://localhost:8091/ConfigBasic.html'
    end

    it "has YaCy's default page where YaCy's settings don't have browserPopUpPage" do
      settings("port=8091\n")
      expect(yacy.yacy_page_url).must_equal 'http://localhost:8091/index.html'
    end

    it "has YaCy's default page where there are no settings yet" do
      expect(yacy.yacy_page_url).must_equal 'http://localhost:8090/index.html'
    end
  end

  describe ".give_yacy_address" do
    it "says where YaCy is running" do
      settings("port=8091\n")
      out, _ = capture_io{yacy.give_yacy_address}
      expect(out).must_equal "YaCy is running at http://localhost:8091/\n"
    end
  end

  describe ".yacy_opens_its_own_page?" do
    it "is false where browserPopUpTrigger is false in YaCy's settings" do
      settings("browserPopUpTrigger=false\n")
      expect(yacy.yacy_opens_its_own_page?).must_equal false
    end

    it "is true where browserPopUpTrigger is true in YaCy's settings" do
      settings("browserPopUpTrigger=true\n")
      expect(yacy.yacy_opens_its_own_page?).must_equal true
    end

    it "is true where YaCy's settings don't have browserPopUpTrigger" do
      settings("port=8090\n")
      expect(yacy.yacy_opens_its_own_page?).must_equal true
    end

    it "is true where there are no settings yet" do
      expect(yacy.yacy_opens_its_own_page?).must_equal true
    end
  end

  describe ".yacy_running?" do
    it "is true where yacy.running in its DATA names a process which is running" do
      FileUtils.mkdir_p(File.join(dir, 'DATA'))
      File.write(File.join(dir, 'DATA', 'yacy.running'), Process.pid.to_s)
      expect(yacy.yacy_running?).must_equal true
    end

    it "is false where yacy.running was left behind by a process which isn't running" do
      FileUtils.mkdir_p(File.join(dir, 'DATA'))
      File.write(File.join(dir, 'DATA', 'yacy.running'), '99999999')
      expect(yacy.yacy_running?).must_equal false
    end

    it "is false where there's no yacy.running" do
      expect(yacy.yacy_running?).must_equal false
    end
  end

  describe ".give_yacy_data_kept" do
    it "says where YaCy's DATA is kept, and how to remove it" do
      FileUtils.mkdir_p(File.join(dir, 'DATA'))
      out, _ = capture_io{yacy.give_yacy_data_kept}
      expect(out).must_equal "YaCy's DATA, its index, settings and identity as a peer, is kept in #{File.join(dir, 'DATA')}. yacy uninstall --data removes it.\n"
    end

    it "says nothing where there's no DATA" do
      out, _ = capture_io{yacy.give_yacy_data_kept}
      expect(out).must_equal ''
    end
  end

  describe ".yacy_answering?" do
    it "is true where YaCy answers on its port" do
      stub_request(:head, 'http://localhost:8090/').to_return(status: 200)
      expect(yacy.yacy_answering?).must_equal true
    end

    it "is false where nothing is listening on its port" do
      stub_request(:head, 'http://localhost:8090/').to_raise(Errno::ECONNREFUSED)
      expect(yacy.yacy_answering?).must_equal false
    end

    it "is false where the port doesn't answer in time" do
      stub_request(:head, 'http://localhost:8090/').to_timeout
      expect(yacy.yacy_answering?).must_equal false
    end
  end

  describe ".wait_for_yacy_to_answer" do
    it "waits until YaCy answers" do
      answers = [false, false, true]
      yacy.stub(:yacy_answering?, ->{answers.shift}) do
        yacy.stub(:sleep, nil){yacy.wait_for_yacy_to_answer}
      end
      expect(answers).must_equal []
    end

    it "stops where YaCy hasn't answered in time" do
      yacy.stub(:yacy_answering?, false) do
        yacy.stub(:sleep, nil) do
          _, err = capture_io{expect{yacy.wait_for_yacy_to_answer}.must_raise SystemExit}
          expect(err).must_match /YaCy hasn't answered on port 8090 after 120 seconds/
        end
      end
    end
  end

  describe ".stop_yacy" do
    after do
      ENV.delete('YACY_DATA_PATH')
    end

    it "asks YaCy to shut down with its apicall.sh, on its DATA" do
      commands = []
      yacy.stub(:run, ->(*command, **options){commands << command; true}){yacy.stop_yacy}
      expect(commands).must_equal [["sh #{File.join(dir, 'scripts', 'bin', 'apicall.sh')} 'Steering.html?shutdown=true' > /dev/null"]]
      expect(ENV['YACY_DATA_PATH']).must_equal File.join(dir, 'DATA')
    end

    it "waits until YaCy has stopped" do
      answers = [true, true, false]
      yacy.stub(:run, true) do
        yacy.stub(:yacy_running?, ->{answers.shift}) do
          yacy.stub(:sleep, nil){yacy.stop_yacy}
        end
      end
      expect(answers).must_equal []
    end

    it "stops where YaCy hasn't stopped in time" do
      yacy.stub(:run, true) do
        yacy.stub(:yacy_running?, true) do
          yacy.stub(:sleep, nil) do
            _, err = capture_io{expect{yacy.stop_yacy}.must_raise SystemExit}
            expect(err).must_match /YaCy hasn't stopped after 120 seconds/
          end
        end
      end
    end
  end
end
