shared_examples "a running container" do |command, exit_status|
  it "should run #{command} with exit status #{exit_status}" do
    container = Docker::Container.create('Image' => @image.id, 'Cmd' => command)
    container.start
    container.wait
    exit_status = container.json['State']['ExitCode']
    expect(exit_status).to eq(exit_status)
    container.kill
    container.delete(force: true)
  end
end
