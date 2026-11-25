# YaCy/Process.rb
# YaCy::Process

# 20261125
# 0.1.0

require 'Kernel/run'
require 'net/http'
require 'shellwords'

module YaCy
  # Finding, asking after and stopping YaCy, given the yacy_data_dir() and yacy_scripts_dir() of the platform including it.
  module Process
    DEFAULT_PORT = 8090
    DEFAULT_PAGE = 'index.html'
    START_TIMEOUT = 120
    STOP_TIMEOUT = 120

    def yacy_settings_path
      File.join(yacy_data_dir, 'SETTINGS', 'yacy.conf')
    end

    # A setting from YaCy's yacy.conf, or nil where YaCy hasn't written its settings yet, or they don't have it.
    def yacy_setting(name)
      setting = File.exist?(yacy_settings_path) && File.foreach(yacy_settings_path).detect{|line| line.start_with?("#{name}=")}
      setting ? setting.split('=', 2).last.strip : nil
    end

    # The port YaCy's settings give, or YaCy's own default where it hasn't written them yet.
    def yacy_port
      (yacy_setting('port') || DEFAULT_PORT).to_i
    end

    # YaCy opens its own page as it starts unless browserPopUpTrigger is false, its default being true.
    def yacy_opens_its_own_page?
      yacy_setting('browserPopUpTrigger') != 'false'
    end

    def yacy_url
      "http://localhost:#{yacy_port}/"
    end

    # The page YaCy opens as it starts, so as the same page is opened whether YaCy opens it or yacy does.
    def yacy_page
      (yacy_setting('browserPopUpPage') || DEFAULT_PAGE).delete_prefix('/')
    end

    def yacy_page_url
      yacy_url + yacy_page
    end

    # Where a page opened here couldn't be seen.
    def give_yacy_address
      puts "YaCy is running at #{yacy_url}"
    end

    def yacy_answering?
      Net::HTTP.start('localhost', yacy_port, open_timeout: 1, read_timeout: 5){|http| http.head('/')}
      true
    rescue SystemCallError, IOError, Timeout::Error, Net::HTTPBadResponse
      false
    end

    # YaCy is running some while before it answers on its port, and its page can't be opened until it does.
    def wait_for_yacy_to_answer
      START_TIMEOUT.times do
        return if yacy_answering?
        sleep 1
      end
      abort("YaCy hasn't answered on port #{yacy_port} after #{START_TIMEOUT} seconds.")
    end

    def yacy_running_path
      File.join(yacy_data_dir, 'yacy.running')
    end

    def process_running?(pid)
      ::Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    # YaCy writes its process id into yacy.running in its DATA while it runs, and leaves it behind where it didn't shut down cleanly, so the process is asked after too.
    def yacy_running?
      pid = File.read(yacy_running_path).to_i
      pid > 0 && process_running?(pid)
    rescue SystemCallError
      false
    end

    # As YaCy's stopYACY.sh does, which can't be run as YaCy ships it, since neither it nor the apicall.sh it runs is executable. apicall.sh authenticates from YaCy's own settings, or asks for the password where they don't let localhost in.
    def stop_yacy
      ENV['YACY_DATA_PATH'] = yacy_data_dir
      apicall = File.join(yacy_scripts_dir, 'bin', 'apicall.sh')
      run("sh #{Shellwords.escape(apicall)} 'Steering.html?shutdown=true' > /dev/null", show: true)
      wait_for_yacy_to_stop
    end

    def wait_for_yacy_to_stop
      STOP_TIMEOUT.times do
        return unless yacy_running?
        sleep 1
      end
      abort("YaCy hasn't stopped after #{STOP_TIMEOUT} seconds.")
    end
  end
end
