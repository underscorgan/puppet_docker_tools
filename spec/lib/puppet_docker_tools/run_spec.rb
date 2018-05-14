require 'puppet_docker_tools/run'
require 'docker'

describe PuppetDockerTools::Run do

  describe '#build' do
    let(:image) { double(Docker::Image) }

    it 'builds a latest and version tag if version is found' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_env).with('version', namespace: 'org.label-schema', directory: '/tmp/test-image').and_return('1.2.3')
      expect(Docker::Image).to receive(:build_from_dir).with('/tmp/test-image', { 't' => 'test/test-image:1.2.3' }).and_return(image)
      expect(Docker::Image).to receive(:build_from_dir).with('/tmp/test-image', { 't' => 'test/test-image:latest' }).and_return(image)
      PuppetDockerTools::Run.build('/tmp/test-image', repository: 'test', namespace: 'org.label-schema')
    end

    it 'builds just a latest tag if no version is found' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_env).with('version', namespace: 'org.label-schema', directory: '/tmp/test-image').and_return(nil)
      expect(Docker::Image).to receive(:build_from_dir).with('/tmp/test-image', { 't' => 'test/test-image:latest' }).and_return(image)
      PuppetDockerTools::Run.build('/tmp/test-image', repository: 'test', namespace: 'org.label-schema')
    end

    it 'ignores the cache when that parameter is set' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_env).with('version', namespace: 'org.label-schema', directory: '/tmp/test-image').and_return(nil)
      expect(Docker::Image).to receive(:build_from_dir).with('/tmp/test-image', { 't' => 'test/test-image:latest', 'nocache' => true }).and_return(image)
      PuppetDockerTools::Run.build('/tmp/test-image', repository: 'test', namespace: 'org.label-schema', no_cache: true)
    end
  end

  describe '#lint' do
    let(:passing_exit) {
      {
        'State' => {
          'ExitCode' => 0
        }
      }
    }
    let(:failing_exit) {
      {
        'State' => {
          'ExitCode' => 1
        }
      }
    }

    let(:container) { double(Docker::Container).as_null_object }

    before do
      allow(PuppetDockerTools::Run).to receive(:pull).and_return(double(Docker::Image))
      allow(Docker::Container).to receive(:create).and_return(container)
      allow(container).to receive(:tap).and_return(container)
      allow(container).to receive(:attach)
      allow(container).to receive(:wait)
      allow(container).to receive(:logs).and_return('container logs')
    end

    it "shouldn't call exit if there isn't an error" do
      allow(container).to receive(:json).and_return(passing_exit)
      expect(Kernel).not_to receive(:exit)
      PuppetDockerTools::Run.lint('/tmp/test-dir')
    end

    it "should exit with exit status if something went wrong" do
      allow(container).to receive(:json).and_return(failing_exit)
      expect { PuppetDockerTools::Run.lint('/tmp/test-dir') }.to raise_error(RuntimeError, /container logs/)
    end
  end

  describe '#pull' do
    it 'will pull a single image if the image has a tag' do
      expect(PuppetDockerTools::Run).to receive(:pull_single_tag).with('test/test-dir:latest')
      PuppetDockerTools::Run.pull('test/test-dir:latest')
    end

    it 'will pull all the images if no tag is passed' do
      expect(PuppetDockerTools::Run).to receive(:pull_all_tags).with('test/test-dir')
      PuppetDockerTools::Run.pull('test/test-dir')
    end
  end

  describe '#pull_all_tags' do
    let(:image_info) {
      {
        'Created' => '2018-05-11T20:09:32Z',
        'RepoTags' => ['latest', '1.2.3'],
      }
    }

    let(:image) { double(Docker::Image) }
    let(:images) { [image] }

    it 'pulls the tags' do
      expect(Docker::Image).to receive(:create).with('fromImage' => 'test/test-dir')
      expect(Docker::Image).to receive(:all).and_return(images)
      expect(image).to receive(:info).and_return(image_info).twice
      PuppetDockerTools::Run.pull_all_tags('test/test-dir')
    end
  end

  describe '#pull_single_tag' do
    let(:image_info) {
      {
        'Created' => '2018-05-11T20:09:32Z',
        'RepoTags' => ['1.2.3'],
      }
    }
    let(:image) { double(Docker::Image) }

    it 'pulls the single tag' do
      expect(Docker::Image).to receive(:create).with('fromImage' => 'test/test-dir:1.2.3').and_return(image)
      expect(image).to receive(:info).and_return(image_info).twice
      PuppetDockerTools::Run.pull_single_tag('test/test-dir:1.2.3')
    end
  end

  describe '#push' do
    it 'should fail if no version is set' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_label).and_return(nil)
      expect { PuppetDockerTools::Run.push('/tmp/test-dir', repository: 'test', namespace: 'org.label-schema') }.to raise_error(RuntimeError, /no version/i)
    end

    it 'should raise an error if something bad happens pushing the versioned tag' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_label).with('test/test-dir', value: 'version', namespace: 'org.label-schema').and_return('1.2.3')
      expect(PuppetDockerTools::Utilities).to receive(:push_to_dockerhub).with('test/test-dir:1.2.3').and_return([1, nil])
      expect { PuppetDockerTools::Run.push('/tmp/test-dir', repository: 'test', namespace: 'org.label-schema') }.to raise_error(RuntimeError, /1.2.3 to dockerhub/i)
    end

    it 'should raise an error if something bad happens pushing the latest tag' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_label).with('test/test-dir', value: 'version', namespace: 'org.label-schema').and_return('1.2.3')
      expect(PuppetDockerTools::Utilities).to receive(:push_to_dockerhub).with('test/test-dir:1.2.3').and_return([0, nil])
      expect(PuppetDockerTools::Utilities).to receive(:push_to_dockerhub).with('test/test-dir:latest').and_return([1, nil])
      expect { PuppetDockerTools::Run.push('/tmp/test-dir', repository: 'test', namespace: 'org.label-schema') }.to raise_error(RuntimeError, /latest to dockerhub/i)
    end

    it 'should push the versioned and latest tags if nothing goes wrong' do
      expect(PuppetDockerTools::Utilities).to receive(:get_value_from_label).with('test/test-dir', value: 'version', namespace: 'org.label-schema').and_return('1.2.3')
      expect(PuppetDockerTools::Utilities).to receive(:push_to_dockerhub).with('test/test-dir:1.2.3').and_return([0, nil])
      expect(PuppetDockerTools::Utilities).to receive(:push_to_dockerhub).with('test/test-dir:latest').and_return([0, nil])
      PuppetDockerTools::Run.push('/tmp/test-dir', repository: 'test', namespace: 'org.label-schema')
    end
  end

  describe '#rev_labels' do
    let(:original_dockerfile) { <<-HERE
FROM ubuntu:16.04

ENV PUPPET_SERVER_VERSION="5.3.1" DUMB_INIT_VERSION="1.2.1" UBUNTU_CODENAME="xenial" PUPPETSERVER_JAVA_ARGS="-Xms256m -Xmx256m" PATH=/opt/puppetlabs/server/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/bin:$PATH PUPPET_HEALTHCHECK_ENVIRONMENT="production"

LABEL maintainer="Puppet Release Team <release@puppet.com>" \\
      org.label-schema.vcs-ref="b75674e1fbf52f7821f7900ab22a19f1a10cafdb" \\
      org.label-schema.build-date="2018-05-09T20:11:01Z"
HERE
    }

    let(:updated_dockerfile) { <<-HERE
FROM ubuntu:16.04

ENV PUPPET_SERVER_VERSION="5.3.1" DUMB_INIT_VERSION="1.2.1" UBUNTU_CODENAME="xenial" PUPPETSERVER_JAVA_ARGS="-Xms256m -Xmx256m" PATH=/opt/puppetlabs/server/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/bin:$PATH PUPPET_HEALTHCHECK_ENVIRONMENT="production"

LABEL maintainer="Puppet Release Team <release@puppet.com>" \\
      org.label-schema.vcs-ref="8d7b9277c02f5925f5901e5aeb4df9b8573ac70e" \\
      org.label-schema.build-date="2018-05-14T22:35:15Z"
HERE
    }

    it "should fail if the dockerfile doesn't exist" do
      expect(File).to receive(:exist?).with('/tmp/test-dir/Dockerfile').and_return(false)
      expect { PuppetDockerTools::Run.rev_labels('/tmp/test-dir', namespace: 'org.label-schema') }.to raise_error(RuntimeError, /doesn't exist/)
    end

    it "should update vcs-ref and build-date" do
      test_dir = Dir.mktmpdir('spec')
      File.open("#{test_dir}/Dockerfile", 'w') { |file|
        file.puts(original_dockerfile)
      }
      expect(PuppetDockerTools::Utilities).to receive(:current_git_sha).with(test_dir).and_return('8d7b9277c02f5925f5901e5aeb4df9b8573ac70e')
      expect(Time).to receive(:now).and_return(Time.at(1526337315))
      PuppetDockerTools::Run.rev_labels(test_dir, namespace: 'org.label-schema')
      expect(File.read("#{test_dir}/Dockerfile")).to eq(updated_dockerfile)

      # cleanup cleanup
      FileUtils.rm("#{test_dir}/Dockerfile")
      FileUtils.rmdir(test_dir)
    end
  end

  describe '#spec' do
    it "runs tests under the 'spec' directory" do
      tests=["/tmp/test-dir/spec/test1_spec.rb", "/tmp/test-dir/spec/test2_spec.rb"]
      expect(Dir).to receive(:glob).with("/tmp/test-dir/spec/*_spec.rb").and_return(tests)
      expect(RSpec::Core::Runner).to receive(:run).with(tests, $stderr, $stdout).and_return(nil)
      PuppetDockerTools::Run.spec('/tmp/test-dir')
    end
  end
end
