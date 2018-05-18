require 'puppet_docker_tools'
require 'puppet_docker_tools/utilities'

describe PuppetDockerTools::Utilities do
  let(:dockerfile) { 'Dockerfile' }
  let(:base_dockerfile_contents) { <<-HERE
FROM ubuntu:16.04

ENV PUPPET_SERVER_VERSION="5.3.1" DUMB_INIT_VERSION="1.2.1" UBUNTU_CODENAME="xenial" PUPPETSERVER_JAVA_ARGS="-Xms256m -Xmx256m" PATH=/opt/puppetlabs/server/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/bin:$PATH PUPPET_HEALTHCHECK_ENVIRONMENT="production"

LABEL maintainer="Puppet Release Team <release@puppet.com>" \\
      org.label-schema.vendor="Puppet" \\
      org.label-schema.url="https://github.com/puppetlabs/puppet-in-docker" \\
      org.label-schema.name="Puppet Server (No PuppetDB)" \\
      org.label-schema.license="Apache-2.0" \\
      org.label-schema.version=$PUPPET_SERVER_VERSION \\
      org.label-schema.vcs-url="https://github.com/puppetlabs/puppet-in-docker" \\
      org.label-schema.vcs-ref="b75674e1fbf52f7821f7900ab22a19f1a10cafdb" \\
      org.label-schema.build-date="2018-05-09T20:11:01Z" \\
      org.label-schema.schema-version="1.0" \\
      com.puppet.dockerfile="/Dockerfile"
HERE
  }
  let(:dockerfile_contents) { <<-HERE
FROM puppet/puppetserver-standalone:5.3.1

LABEL maintainer="Puppet Release Team <release@puppet.com>" \\
      org.label-schema.vendor="Puppet" \\
      org.label-schema.url="https://github.com/puppetlabs/puppet-in-docker" \\
      org.label-schema.name="Puppet Server" \\
      org.label-schema.license="Apache-2.0" \\
      org.label-schema.version=$PUPPET_SERVER_VERSION \\
      org.label-schema.vcs-url="https://github.com/puppetlabs/puppet-in-docker" \\
      org.label-schema.vcs-ref="b75674e1fbf52f7821f7900ab22a19f1a10cafdb" \\
      org.label-schema.build-date="2018-05-09T20:11:01Z" \\
      org.label-schema.schema-version="1.0" \\
      com.puppet.dockerfile="/Dockerfile"
HERE
  }

  let(:config_labels) { {
    'Config' => {
      'Labels' => {
        'org.label-schema.vendor' => 'Puppet',
        'org.label-schema.version' => '1.2.3',
        'org.label-schema.vcs-ref' => 'b75674e1fbf52f7821f7900ab22a19f1a10cafdb'
      }
    }
  }
  }

  describe "#get_value_from_label" do
    let(:image) { double(Docker::Image).as_null_object }

    before do
      allow(Docker::Image).to receive(:get).and_return(image)
      allow(image).to receive(:json).and_return(config_labels)
    end

    it "returns the value of a label" do
      expect(PuppetDockerTools::Utilities.get_value_from_label('puppet/puppetserver-test', value: 'vendor', namespace: 'org.label-schema')).to eq('Puppet')
    end

    it "replaces '_' with '-' in the label name" do
      expect(PuppetDockerTools::Utilities.get_value_from_label('puppet/puppetserver-test', value: 'vcs_ref', namespace: 'org.label-schema')).to eq('b75674e1fbf52f7821f7900ab22a19f1a10cafdb')
    end

    it "returns nil if you ask for a value that isn't there" do
      expect(PuppetDockerTools::Utilities.get_value_from_label('puppet/puppetserver-test', value: 'totes-not-a-value', namespace: 'org.label-schema')).to eq(nil)
    end
  end

  describe "#get_value_from_env" do
    it "should fail if the dockerfile doesn't exist" do
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(base_dockerfile_contents)
      expect { PuppetDockerTools::Utilities.get_value_from_env('from', directory: '/tmp/test-dir')}.to raise_error(RuntimeError, /doesn't exist/)
    end

    it "calls get_value_from_variable if it looks like we have a variable" do
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(base_dockerfile_contents)
      expect(PuppetDockerTools::Utilities.get_value_from_env('version', namespace: 'org.label-schema', directory: '/tmp/test-dir')).to eq('5.3.1')
    end

    it "calls get value_from_base_image if we didn't find the variable in our dockerfile" do
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(dockerfile_contents)
      allow(File).to receive(:exist?).with("/tmp/test-dir/../puppetserver-standalone/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/../puppetserver-standalone/#{dockerfile}").and_return(base_dockerfile_contents)
      expect(PuppetDockerTools::Utilities.get_value_from_env('version', namespace: 'org.label-schema', directory: '/tmp/test-dir')).to eq('5.3.1')
    end
  end

  describe "#format_timestamp" do
    it "ISO 8601 formats the timestamp if it's time since epoch" do
      expect(PuppetDockerTools::Utilities.format_timestamp('1526069372')).to eq('2018-05-11T20:09:32Z')
    end

    it "Returns the passed timestamp if it doesn't look like it's time since epoch" do
      expect(PuppetDockerTools::Utilities.format_timestamp('2018-05-11T20:09:32Z')).to eq('2018-05-11T20:09:32Z')
    end
  end

  describe "get_value_from_dockerfile" do
    it "reads the key from a passed string if dockerfile is passed" do
      expect(PuppetDockerTools::Utilities.get_value_from_dockerfile('from', dockerfile_contents: base_dockerfile_contents)).to eq('ubuntu:16.04')
    end

    it "reads the key from a dockerfile if directory is passed" do
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(base_dockerfile_contents)
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      expect(PuppetDockerTools::Utilities.get_value_from_dockerfile('from', directory: '/tmp/test-dir')).to eq('ubuntu:16.04')
    end

    it "fails if the dockerfile doesn't exist" do
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(base_dockerfile_contents)
      expect { PuppetDockerTools::Utilities.get_value_from_dockerfile('from', directory: '/tmp/test-dir')}.to raise_error(RuntimeError, /doesn't exist/)
    end
  end

  describe "#get_value_from_base_image" do
    before do
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(dockerfile_contents)
      allow(File).to receive(:exist?).with("/tmp/test-dir/../puppetserver-standalone/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/../puppetserver-standalone/#{dockerfile}").and_return(base_dockerfile_contents)
    end

    it "Reads the value from the base image" do
      expect(PuppetDockerTools::Utilities.get_value_from_base_image('version', namespace: 'org.label-schema', directory: '/tmp/test-dir')).to eq('5.3.1')
    end
  end

  describe "#get_value_from_variable" do
    it "reads the value from a passed string if dockerfile is passed" do
      expect(PuppetDockerTools::Utilities.get_value_from_variable('$PUPPET_SERVER_VERSION', dockerfile_contents: base_dockerfile_contents)).to eq('"5.3.1"')
    end

    it "reads the value from a dockerfile if directory is passed" do
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(base_dockerfile_contents)
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      expect(PuppetDockerTools::Utilities.get_value_from_variable('$PUPPET_SERVER_VERSION', dockerfile_contents: base_dockerfile_contents)).to eq('"5.3.1"')
    end

    it "fails if the dockerfile doesn't exist" do
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(base_dockerfile_contents)
      expect { PuppetDockerTools::Utilities.get_value_from_variable('$PUPPET_SERVER_VERSION', directory: '/tmp/test-dir')}.to raise_error(RuntimeError, /doesn't exist/)
    end
  end

  describe '#pull' do
    it 'will pull a single image if the image has a tag' do
      expect(PuppetDockerTools::Utilities).to receive(:pull_single_tag).with('test/test-dir:latest')
      PuppetDockerTools::Utilities.pull('test/test-dir:latest')
    end

    it 'will pull all the images if no tag is passed' do
      expect(PuppetDockerTools::Utilities).to receive(:pull_all_tags).with('test/test-dir')
      PuppetDockerTools::Utilities.pull('test/test-dir')
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
      PuppetDockerTools::Utilities.pull_all_tags('test/test-dir')
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
      PuppetDockerTools::Utilities.pull_single_tag('test/test-dir:1.2.3')
    end
  end

end
