require 'json'
shared_context 'with a docker image' do
  before(:all) do
    if ENV['PUPPET_TEST_DOCKER_IMAGE'] && !ENV['PUPPET_TEST_DOCKER_IMAGE'].empty?
      @image=ENV['PUPPET_TEST_DOCKER_IMAGE']
    else
      @image = "test/#{File.basename(CURRENT_DIRECTORY)}:#{Random.rand(1000)}"
      %x(docker image build --tag #{@image} #{CURRENT_DIRECTORY})
    end
    puts "Running tests on #{@image}..."
    @image_json = JSON.parse(%x(docker inspect #{@image}))
  end

  after(:all) do
    if !ENV['PUPPET_TEST_DOCKER_IMAGE'] || ENV['PUPPET_TEST_DOCKER_IMAGE'].empty?
      %x(docker image rm --force #{@image})
    end
  end
end
