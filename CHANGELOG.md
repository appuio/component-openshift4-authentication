# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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

[Unreleased]: https://github.com/appuio/component-openshift4-authentication/compare/ba4fee5..HEAD

[#9]: https://github.com/appuio/component-openshift4-authentication/pull/9
[#10]: https://github.com/appuio/component-openshift4-authentication/pull/10
[#11]: https://github.com/appuio/component-openshift4-authentication/pull/11
[#14]: https://github.com/appuio/component-openshift4-authentication/pull/14
[#15]: https://github.com/appuio/component-openshift4-authentication/pull/15
[#16]: https://github.com/appuio/component-openshift4-authentication/pull/16
