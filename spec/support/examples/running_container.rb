shared_examples "a running container" do |command, exit_status|
  it "should run #{command} with exit status #{exit_status}" do
    @container.start
    exit_status = @container.exec(command.split(' ')).last
    expect(exit_status).to eq(0)
  end
end
