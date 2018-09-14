shared_context 'with a transient docker container' do
  before(:each) do
    @container = %x(docker run --detach --rm -i #{@image}).chomp
  end

  after(:each) do
    %x(docker container kill #{@container})
  end
end
