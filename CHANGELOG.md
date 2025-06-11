# Changelog

## [1.1.0](https://github.com/lekman/auto-approve-action/compare/auto-approve-action@v1.0.0...auto-approve-action@v1.1.0) (2025-06-11)


### Features

* add author verification and auto-approval workflows for PRs ([f9af78f](https://github.com/lekman/auto-approve-action/commit/f9af78fa60232cd5c8f3d07ec165bf192230aaf4))
* add conditional check for PR author verification in action.yml ([5069af4](https://github.com/lekman/auto-approve-action/commit/5069af476eeae66cdaf99b91e4553205c888db17))
* add workflow step to update major version tag during release ([eb03814](https://github.com/lekman/auto-approve-action/commit/eb03814a0bb25455ced988786c5088465db6579c))
* allow dynamic inclusion of the PR author in allowed-authors for input validation ([af6cb78](https://github.com/lekman/auto-approve-action/commit/af6cb78b08d06de53f3d7c8b76284536ed6fd0c9))
* enhance author verification scripts for CI compatibility and improve output formatting ([37b07a1](https://github.com/lekman/auto-approve-action/commit/37b07a1b65889a7a7cfe888feb313d91a9710962))


### Bug Fixes

* ensure unset commands do not fail in test-verify-author.sh ([e723b13](https://github.com/lekman/auto-approve-action/commit/e723b13fcc429b3e9c1b0c19d6c5a3bbabc01016))

## 1.0.0 (2025-06-11)


### Features

* add CodeQL and Dependabot configuration for enhanced security and dependency management ([30e3c82](https://github.com/lekman/auto-approve-action/commit/30e3c82b8c3b2d7957ec36d70ea3ffefef763887))
* add label-match-mode option to input validation workflow ([2365a40](https://github.com/lekman/auto-approve-action/commit/2365a4081aece304e14e0cdfd1bb978fc5e01080))
* add release configuration and changelog workflow for automated releases ([2fc84cb](https://github.com/lekman/auto-approve-action/commit/2fc84cbe6f9067d617e96b2f9f8f33483ae5b860))
* enhance GitHub Action configuration with new input parameters ([cc9378d](https://github.com/lekman/auto-approve-action/commit/cc9378d638fa3da3eb00f15a0abde5b736b812bc))
* rename job in CodeQL workflow from Analyze Node.js to Analyze Actions ([4232fae](https://github.com/lekman/auto-approve-action/commit/4232fae440f248fed287616befb5629e1ea49aa5))
* update CodeQL workflow permissions for enhanced security ([663e7bc](https://github.com/lekman/auto-approve-action/commit/663e7bce8dd1fcc1155d9fae2c9d96adef2bb991))
* update permissions in test-input-validation workflow for improved access control ([faeb2bc](https://github.com/lekman/auto-approve-action/commit/faeb2bc2546a8606e3e3402a1b8c218828966a4a))
* update release configuration and README for auto-approve-action package ([5f5b0c5](https://github.com/lekman/auto-approve-action/commit/5f5b0c55f2af265f9a85821f54bcd63b53960362))
