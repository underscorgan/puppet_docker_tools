require 'open3'

shared_context 'with a docker container' do
  def is_running?(container)
    is_running = false
    command = ['docker', 'inspect', '-f', "'{{.State.Health.Status}}'", "#{container}"]
    while ! is_running
      output, status = Open3.capture2e(*command)
      output.chomp!
      output.gsub!(/'/, '')

      # If finding State.Health.Status throws an error, we probably don't have
      # a healthcheck, so let's fall back to State.Running
      if status.exitstatus != 0
        command = ['docker', 'inspect', '-f', "'{{.State.Running}}'", "#{container}"]
      end

      case output
      when "healthy", "true"
        return true
      when "unhealthy"
        return false
      else
        _, status = Open3.capture2e('docker', 'inspect', "#{container}")
        return false if status.exitstatus != 0
      end

      puts "Container is not running yet, will try again in 5 seconds..."
      sleep(5)
    end
  end

  before(:all) do
    @container = %x(docker run --detach --rm -i #{@image}).chomp
    unless is_running?(@container)
      fail "something went wrong with container startup!"
    end
  end

  after(:all) do
    %x(docker container kill #{@container})
  end
end
