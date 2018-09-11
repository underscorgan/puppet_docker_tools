require 'open3'

shared_examples "a running container" do |command, exit_code, expected_output|
  unless command.is_a? Array
    command = command.split(' ')
  end

  if expected_output && exit_code
    it "should run #{command} with output matching #{expected_output} and exit code #{exit_code}" do
      output, status = Open3.capture2e('docker', 'exec', @container, *command)
      expect(output).to match(/#{expected_output}/)
      expect(status).to eq(exit_code)
    end
  elsif expected_output
    it "should run #{command} with output matching #{expected_output}" do
      output, _ = Open3.capture2e('docker', 'exec', @container, *command)
      expect(output).to match(/#{expected_output}/)
    end
  elsif exit_code
    it "should run #{command} with exit code #{exit_code}" do
      _, status = Open3.capture2e('docker', 'exec', @container, *command)
      expect(status).to eq(exit_code)
    end
  end

 # it "should run #{command} with exit status #{exit_status}" do
 #   _, status = Open3.capture2e('docker', 'run', '--rm', '-i', @image, command)
 #   expect(status).to eq(exit_status)
 # end
end

shared_examples "a service in a container" do |service, user, arg, pid|
  if service && user
    it "should run #{service} as #{user}" do
      if pid
        output, status = Open3.capture2e('docker', 'exec', @container, 'ps', '-f', '--quick-pid', pid)
      else
        output, status = Open3.capture2e('docker', 'exec', @container, 'ps', '-f', '-u', user)
        output = output.split("\n").select { |proc| proc[/#{service}/] }.join('')
      end
      expect(status).to eq(0)
      expect(output).to match(/#{service}/)
      expect(output).to match(/#{user}/)
      if arg
        expect(output).to match(/#{arg}/)
      end
    end
  end
end
