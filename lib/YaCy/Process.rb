# YaCy/Process.rb
# YaCy::Process

# 20261125
# 0.0.0

require 'Kernel/run'
require 'shellwords'

module YaCy
  # Finding, asking after and stopping YaCy, given the yacy_data_dir() and yacy_scripts_dir() of the platform including it.
  module Process
    DEFAULT_PORT = 8090
    STOP_TIMEOUT = 120

    def yacy_settings_path
      File.join(yacy_data_dir, 'SETTINGS', 'yacy.conf')
    end

    # The port YaCy's settings give, or YaCy's own default where it hasn't written them yet.
    def yacy_port
      setting = File.exist?(yacy_settings_path) && File.foreach(yacy_settings_path).detect{|line| line.start_with?('port=')}
      setting ? setting.split('=', 2).last.strip.to_i : DEFAULT_PORT
    end

    def yacy_url
      "http://localhost:#{yacy_port}/"
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
