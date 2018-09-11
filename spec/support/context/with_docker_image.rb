require 'json'
shared_context 'with a docker image' do
  before(:all) do
    @image = "test/#{File.basename(CURRENT_DIRECTORY)}:#{Random.rand(1000)}"
    %x(docker image build --tag #{@image} #{CURRENT_DIRECTORY})
    @image_json = JSON.parse(%x(docker inspect #{@image}))
  end

  after(:all) do
    %x(docker image rm --force #{@image})
  end
end
