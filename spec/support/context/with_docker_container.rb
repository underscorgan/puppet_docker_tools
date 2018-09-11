shared_context 'with a docker container' do
  before(:all) do
    @container = %x(docker run --detach --rm -i #{@image}).chomp
  end

  after(:all) do
    %x(docker container kill #{@container})
  end
end
