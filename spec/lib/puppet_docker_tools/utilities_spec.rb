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
      org.label-schema.version="$PUPPET_SERVER_VERSION" \\
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
  let(:infinite_dockerfile_contents) { <<-HERE
FROM ubuntu:16.04

ENV PUPPET_SERVER_VERSION=$foo foo=$PUPPET_SERVER_VERSION

LABEL maintainer="Puppet Release Team <release@puppet.com>" \\
      org.label-schema.vendor="Puppet" \\
      org.label-schema.url="https://github.com/puppetlabs/puppet-in-docker" \\
      org.label-schema.name="Puppet Server (No PuppetDB)" \\
      org.label-schema.license="Apache-2.0" \\
      org.label-schema.version="$PUPPET_SERVER_VERSION" \\
      org.label-schema.vcs-url="https://github.com/puppetlabs/puppet-in-docker" \\
      org.label-schema.vcs-ref="b75674e1fbf52f7821f7900ab22a19f1a10cafdb" \\
      org.label-schema.build-date="2018-05-09T20:11:01Z" \\
      org.label-schema.schema-version="1.0" \\
      com.puppet.dockerfile="/Dockerfile"
HERE
  }
  let(:dockerfile_with_args) { <<-HERE
FROM puppet/puppetserver-standalone:5.3.1

ARG version
ARG foo
ARG bar
HERE
  }

  let(:build_args) {
    {
      'version' => '1.2.3',
      'foo' => 'test',
      'bar' => 'baz',
      'test' => 'test2',
    }
  }

  let(:filtered_build_args) {
    {
      'version' => '1.2.3',
      'foo' => 'test',
      'bar' => 'baz',
    }
  }

  let(:labels) {
    '{
      "org.label-schema.build-date":"2018-08-24T21:31:54Z",
      "org.label-schema.dockerfile":"/Dockerfile",
      "org.label-schema.license":"Apache-2.0",
      "org.label-schema.maintainer":"Puppet Release Team <release@puppet.com>",
      "org.label-schema.name":"Puppet Server",
      "org.label-schema.schema-version":"1.0",
      "org.label-schema.url":"https://github.com/puppetlabs/puppetserver",
      "org.label-schema.vcs-ref":"5296a6a86b141c9c1aeab63258205ae664d4108d",
      "org.label-schema.vcs-url":"https://github.com/puppetlabs/puppetserver",
      "org.label-schema.vendor":"Puppet",
      "org.label-schema.version":"5.3.5"
    }'
  }

  describe "#filter_build_args" do
    it "should fail if the dockerfile doesn't exist" do
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(false)
      expect { PuppetDockerTools::Utilities.filter_build_args(build_args: build_args, dockerfile: "/tmp/test-dir/#{dockerfile}") }.to raise_error(RuntimeError, /doesn't exist/)
    end

    it "should filter out any buildargs not in the dockerfile" do
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(dockerfile_with_args)
      expect(PuppetDockerTools::Utilities.filter_build_args(build_args: build_args, dockerfile: "/tmp/test-dir/#{dockerfile}")).to eq(filtered_build_args)
    end

  end

  describe "#get_value_from_label" do
    before do
      allow(Open3).to receive(:capture2).and_return(labels)
    end

    it "returns the value of a label" do
      expect(PuppetDockerTools::Utilities.get_value_from_label('puppet/puppetserver-test', value: 'vendor', namespace: 'org.label-schema')).to eq('Puppet')
    end

    it "replaces '_' with '-' in the label name" do
      expect(PuppetDockerTools::Utilities.get_value_from_label('puppet/puppetserver-test', value: 'vcs_ref', namespace: 'org.label-schema')).to eq('5296a6a86b141c9c1aeab63258205ae664d4108d')
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

    it "doesn't get stuck in an infinite loop if there's a bad variable definition" do
      allow(File).to receive(:exist?).with("/tmp/test-dir/#{dockerfile}").and_return(true)
      allow(File).to receive(:read).with("/tmp/test-dir/#{dockerfile}").and_return(infinite_dockerfile_contents)
      expect { PuppetDockerTools::Utilities.get_value_from_env('version', namespace: 'org.label-schema', directory: '/tmp/test-dir')}.to raise_error(RuntimeError, /infinite loop/)
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
      expect(Open3).to receive(:popen2e).with('docker', 'pull', 'test/test-dir:latest')
      PuppetDockerTools::Utilities.pull('test/test-dir:latest')
    end
  end

  describe '#get_hadolint_command' do
    it 'generates a commmand with a dockerfile' do
      expect(PuppetDockerTools::Utilities.get_hadolint_command('test/Dockerfile')).to eq(['hadolint', '--ignore', 'DL3008', '--ignore', 'DL3018', '--ignore', 'DL4000', '--ignore', 'DL4001', 'test/Dockerfile'])
    end

    it 'defaults to generating a command that reads from stdin' do
      expect(PuppetDockerTools::Utilities.get_hadolint_command).to eq(['hadolint', '--ignore', 'DL3008', '--ignore', 'DL3018', '--ignore', 'DL4000', '--ignore', 'DL4001', '-'])
    end
  end

  describe '#parse_build_args' do
    let(:build_args) {
      [
        'foo=bar',
        'test=a=string=with==equals'
      ]
    }
    let(:build_args_hash) {
      {
        'foo' => 'bar',
        'test' => 'a=string=with==equals'
      }
    }
    it 'converts the array to a hash' do
      expect(PuppetDockerTools::Utilities.parse_build_args(build_args)).to eq(build_args_hash)
    end
  end
end
