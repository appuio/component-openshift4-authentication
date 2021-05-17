# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Configure LDAP group sync cronjob to run on master nodes ([#22])

## [v2.0.0]

### Changed

- Change parameter `identityProviders` to be a dictionary ([#20])

## [v1.0.0]
### Changed

- Rename to `openshift4-authentication` ([#9])
- Randomize the default schedule for LDAP sync ([#15])
- Allow non LDAP providers ([#16])

### Added

- Initial implementation allowing to manage identity providers.
- Faciltiy to manage LDAP group sync.
- Sudo process for cluster-admin ([#11])
- LDAP group pruning ([#14])

### Fixed

- ClusterRoleBinding for the LDAP sync job ([#10])
- Set `.spec.startingDeadlineSeconds` for group sync cronjob ([#19])

[Unreleased]: https://github.com/appuio/component-openshift4-authentication/compare/v2.0.0..HEAD
[v1.0.0]: https://github.com/appuio/component-openshift4-authentication/releases/tag/v1.0.0
[v2.0.0]: https://github.com/appuio/component-openshift4-authentication/releases/tag/v1.0.0

[#9]: https://github.com/appuio/component-openshift4-authentication/pull/9
[#10]: https://github.com/appuio/component-openshift4-authentication/pull/10
[#11]: https://github.com/appuio/component-openshift4-authentication/pull/11
[#14]: https://github.com/appuio/component-openshift4-authentication/pull/14
[#15]: https://github.com/appuio/component-openshift4-authentication/pull/15
[#16]: https://github.com/appuio/component-openshift4-authentication/pull/16
[#19]: https://github.com/appuio/component-openshift4-authentication/pull/19
[#20]: https://github.com/appuio/component-openshift4-authentication/pull/20
[#22]: https://github.com/appuio/component-openshift4-authentication/pull/22
