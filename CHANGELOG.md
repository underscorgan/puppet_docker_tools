# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]
## [0.1.5] - released 2018-07-05
### Added
- Add the ability to pass `--version` to the push subcommand

### Fixed
- Documentation cleanup

## [0.1.4] - released 2018-06-27
### Added
- (CPR-598) Add the ability to filter buildargs at runtime. Older versions of
  docker will fail a build if there are buildargs passed that aren't in the
  dockerfile, so only pass in buildargs that align with the ARGs in the
  dockerfile. A message is printed for ignored buildargs
- (CPR-590) Add `--no-latest` option to not build a `latest` tag along with the
  versioned tag. This is useful if you're building containers from multiple
  version streams
- Improve `get_value_from_env` to support retrieving values from variables set
  to other variables

## [0.1.3] - released 2018-06-21
### Added
- (CPR-584) Add support for passing version and arbitrary buildargs at container
  build time

### Fixed
- The `get_value_from_env` method was not properly interpolating environment
  variables if they were quoted in the label. We now support either
  `label=$variable` or `label="$variable"`

## [0.1.2] - released 2018-06-12
### Added
- Generate build-date and vcs-ref at build time and pass those on to the image
  build as buildargs
- Add 'a running container' shared example to the spec helper for use when
  timing issues crop up (primarily in external CI pipelines that have more
  latency)
- Add `puppet-docker local-lint` command. This allows for hadolint to be run
  with a locally installed binary on your $PATH rather than by spinning up the
  hadolint docker container

## [0.1.1] - released 2018-05-24
### Changed
- For the lint task, ignore version pinning for `apk install`
- Reorganize `spec_helper` for ease of loading in external projects. Spec tests
  can now `require 'puppet_docker_tools/spec_helper'`
- Update the `spec` task to use `Open3.popen2e` instead of `RSpec::Core::Runner.run`
  so the task can fail if anything fails while running the tests

## [0.1.0] - released 2018-05-18
### Added
- Initial port of the automation from [puppet-in-docker](https://github.com/puppetlabs/puppet-in-docker)

[Unreleased]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.5...HEAD
[0.1.5]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.4...0.1.5
[0.1.4]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.3...0.1.4
[0.1.3]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.2...0.1.3
[0.1.2]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.0.0...0.1.0
