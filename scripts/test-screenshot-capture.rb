#!/usr/bin/env ruby
require "tmpdir"
require_relative "screenshot-capture"

Dir.mktmpdir("screenshot-capture") do |directory|
  executable = File.join(directory, "sim-use")
  File.write(executable, <<~SCRIPT)
    #!/usr/bin/env ruby
    output = ARGV.fetch(ARGV.index("--output") + 1)
    File.binwrite(output, "test screenshot")
  SCRIPT
  File.chmod(0o755, executable)
  previous_path = ENV.fetch("PATH")
  ENV["PATH"] = "#{directory}:#{previous_path}"
  begin
    capture = SimulatorScreenshotCapture.new(device: "test-device", directory: directory)
    capture.start
    File.write(File.join(directory, "capture-request.json"), JSON.generate(name: "01-categories"))
    response = File.join(directory, "01-categories.capture.json")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    until File.file?(response)
      abort "Capture worker did not respond" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.1
    end
    capture.stop
    abort "Capture failed" unless JSON.parse(File.read(response)).fetch("success")
    abort "Image was not written" unless File.read(File.join(directory, "01-categories.png")) == "test screenshot"

    File.write(executable, "#!/usr/bin/env ruby\nwarn 'test failure'\nexit 7\n")
    capture.capture("02-repositories")
    result = JSON.parse(File.read(File.join(directory, "02-repositories.capture.json")))
    abort "Failed command was accepted" if result.fetch("success")
    abort "Failure details were lost" unless result.fetch("error").include?("test failure")

    begin
      capture.capture("../outside")
      abort "Invalid output name was accepted"
    rescue RuntimeError => error
      raise unless error.message == "Invalid screenshot name"
    end
  ensure
    capture&.stop
    ENV["PATH"] = previous_path
  end
end
puts "Screenshot capture checks passed."
