require "json"
require "open3"
require "rbconfig"

# XCTest selects the page; sim-use captures the active display at its native resolution.
class SimulatorScreenshotCapture
  def initialize(device:, directory:)
    @device = device
    @directory = File.expand_path(directory)
    @request = File.join(@directory, "capture-request.json")
    @stopped = false
  end

  def start
    @thread = Thread.new do
      last_name = nil
      until @stopped
        if File.file?(@request)
          name = JSON.parse(File.read(@request)).fetch("name")
          if name != last_name
            capture(name)
            last_name = name
          end
        end
        sleep 0.1
      end
    end
  end

  def stop
    @stopped = true
    @thread&.value
  end

  def capture(name)
    raise "Invalid screenshot name" unless name.match?(/\A0[1-5]-[a-z]+\z/)
    response = File.join(@directory, "#{name}.capture.json")
    begin
      output = File.join(@directory, "#{name}.png")
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, File.expand_path("with-timeout.rb", __dir__), "60",
        "sim-use", "screenshot", "--device", @device, "--output", output
      )
      raise "Native screenshot failed: #{stderr} #{stdout}" unless status.success? && File.file?(output)
      result = { success: true }
    rescue StandardError => error
      result = { success: false, error: error.message }
    end
    temporary = "#{response}.tmp"
    File.write(temporary, JSON.generate(result))
    File.rename(temporary, response)
  end
end
