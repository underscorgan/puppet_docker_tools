# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

This changelog adheres to [Keep a CHANGELOG](http://keepachangelog.com/).

## [Unreleased]
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

[Unreleased]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.2...HEAD
[0.1.2]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/puppetlabs/puppet_docker_tools/compare/0.0.0...0.1.0
