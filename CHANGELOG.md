# Changelog

## [1.3.0](https://github.com/lekman/auto-approve-action/compare/auto-approve-action@v1.2.2...auto-approve-action@v1.3.0) (2025-07-26)


### Features

* add stale approval handling and re-approval logic for PRs ([2b40a27](https://github.com/lekman/auto-approve-action/commit/2b40a27e3d7b9c34e6a7aac0a3268bfbee787da9))

## [1.2.2](https://github.com/lekman/auto-approve-action/compare/auto-approve-action@v1.2.1...auto-approve-action@v1.2.2) (2025-06-12)


### Bug Fixes

* add GITHUB_REPOSITORY environment variable to scripts for improved PR access ([cd8eeaa](https://github.com/lekman/auto-approve-action/commit/cd8eeaa6c5a8e2c6c18962c6e1fc3c0e16ab4370))

## [1.2.1](https://github.com/lekman/auto-approve-action/compare/auto-approve-action@v1.2.0...auto-approve-action@v1.2.1) (2025-06-12)


### Bug Fixes

* update permissions docs for Auto Approve Release Please PR workflow ([50381ec](https://github.com/lekman/auto-approve-action/commit/50381eced27059671e674d3a706790541c6a6874))

## [1.2.0](https://github.com/lekman/auto-approve-action/compare/auto-approve-action@v1.1.0...auto-approve-action@v1.2.0) (2025-06-12)


### Features

* add PR size limits and validation for auto-approval action ([788af9e](https://github.com/lekman/auto-approve-action/commit/788af9e881054fc714ea538c8e7d35b9008ebd13))
* restrict auto-approval action to PRs from release-please branches ([a1a57e7](https://github.com/lekman/auto-approve-action/commit/a1a57e7ba5899b83bfd4bf5ecd66470a63fa8c16))


### Bug Fixes

* increase size limits in CI tests to accommodate PR size ([4bfbe22](https://github.com/lekman/auto-approve-action/commit/4bfbe22bb796305faf30e44cca2020782adab290))
* update auto-merge command to use --auto flag ([c65f58a](https://github.com/lekman/auto-approve-action/commit/c65f58a5ed8a8ba2788115d5c4daee0a11c909a2))
* update path filters and increase max lines removed in CI workflow ([e60eb80](https://github.com/lekman/auto-approve-action/commit/e60eb8003e7a9db715cd6c38d68593bfb2af6687))

## [1.1.0](https://github.com/lekman/auto-approve-action/compare/auto-approve-action@v1.0.0...auto-approve-action@v1.1.0) (2025-06-12)


### Features

* add approval execution tests and update workflows for improved validation and auto-approval functionality ([fcdc432](https://github.com/lekman/auto-approve-action/commit/fcdc4323cbcbd92371e28548e9ff90bccffe5460))
* add author verification and auto-approval workflows for PRs ([f9af78f](https://github.com/lekman/auto-approve-action/commit/f9af78fa60232cd5c8f3d07ec165bf192230aaf4))
* add conditional check for PR author verification in action.yml ([5069af4](https://github.com/lekman/auto-approve-action/commit/5069af476eeae66cdaf99b91e4553205c888db17))
* add dry-run mode for testing ([f543944](https://github.com/lekman/auto-approve-action/commit/f543944deb304a43096bf69fdbf1eaccc27a9c56))
* add GitHub App token generation and update changelog workflow for improved authentication ([b583019](https://github.com/lekman/auto-approve-action/commit/b583019cadbefa4abc65e4a838ad83ff66842514))
* add integration testing workflow and modify author verification to not wait for checks ([7edc0fd](https://github.com/lekman/auto-approve-action/commit/7edc0fdb288ddbbf50adf41b6ac66a3736b9535b))
* add label validation step to GitHub Actions and implement local test script for label validation ([812060f](https://github.com/lekman/auto-approve-action/commit/812060faf8face865e72251e70f8a62683e85013))
* add PR comment before auto-approval ([a5ac8e6](https://github.com/lekman/auto-approve-action/commit/a5ac8e631230b685e65294d542efff7d7f0fb619))
* add silent mode and remove PR comment noise ([498bc7f](https://github.com/lekman/auto-approve-action/commit/498bc7fc91d5415b68bc1abc7b6a2927b2748e2d))
* add support for additional pull request event types in CI workflow ([00dd5fd](https://github.com/lekman/auto-approve-action/commit/00dd5fdb54628a509d59352415d3d8551fe999d7))
* add tests for approval rejection scenarios and enhance auto-approval workflow ([b568c5d](https://github.com/lekman/auto-approve-action/commit/b568c5d11e3362b2a0c585dac1c8d7cee13528f0))
* add unit input validation tests for non-PR contexts in CI workflow ([462be45](https://github.com/lekman/auto-approve-action/commit/462be457424e545c9463413d8caa8096cbbfe1a1))
* add workflow step to update major version tag during release ([eb03814](https://github.com/lekman/auto-approve-action/commit/eb03814a0bb25455ced988786c5088465db6579c))
* allow dynamic inclusion of the PR author in allowed-authors for input validation ([af6cb78](https://github.com/lekman/auto-approve-action/commit/af6cb78b08d06de53f3d7c8b76284536ed6fd0c9))
* enable auto-merge with configurable merge method ([7b9e98e](https://github.com/lekman/auto-approve-action/commit/7b9e98e3ef8473eb3f6452b97b1b9fa13a14a14a))
* enhance approval workflows with basic approval tests and improved token handling ([530e456](https://github.com/lekman/auto-approve-action/commit/530e456dff8f2d64734421e74be17a6bc07a2999))
* enhance author verification scripts for CI compatibility and improve output formatting ([37b07a1](https://github.com/lekman/auto-approve-action/commit/37b07a1b65889a7a7cfe888feb313d91a9710962))
* enhance auto-approval workflow and logging functionality ([1c6238e](https://github.com/lekman/auto-approve-action/commit/1c6238ec96f2f72a4fbabc9a3677ea226d45ddf9))
* enhance CI workflow to use fallback GitHub token and improve token handling ([c0e672d](https://github.com/lekman/auto-approve-action/commit/c0e672d956de5908cf5f2ea00f8c6189f9645677))
* enhance CI workflow with detailed PR test failure summary ([13f8ca8](https://github.com/lekman/auto-approve-action/commit/13f8ca800a35640fafde6db0ce886b5467623fcc))
* enhance label validation workflow and update VSCode settings for improved development experience ([39d7543](https://github.com/lekman/auto-approve-action/commit/39d7543085b7621adc1f0cfd80511e98c103fe7c))
* enhance logging with timestamps and audit trail ([2a57c86](https://github.com/lekman/auto-approve-action/commit/2a57c86d24d16b74ead0d19e708802639047d68b))
* implement file path-based approval rules ([c13a5b0](https://github.com/lekman/auto-approve-action/commit/c13a5b03e16715e667ec8dd9b215e2e179092256))
* implement new logging mechanism for improved error tracking and monitoring ([8d0c317](https://github.com/lekman/auto-approve-action/commit/8d0c317b387fe177947f33351f9bec89c30b543f))
* remove conditional check for GitHub App token generation ([0b02f7e](https://github.com/lekman/auto-approve-action/commit/0b02f7e5f56045b747ab25947d6bc5f2f5468a0a))
* rename changelog workflow to continuous deployment and remove obsolete integration testing workflows ([ad8b55c](https://github.com/lekman/auto-approve-action/commit/ad8b55c8374a9c2b700a0edf9f96e47daa55b764))
* simplify CI workflow by removing unnecessary pull request event types ([026a98e](https://github.com/lekman/auto-approve-action/commit/026a98e6d2f3014bee74aa22e2bbde05f2352fbb))
* simplify GitHub App token generation condition in CI workflow ([f508904](https://github.com/lekman/auto-approve-action/commit/f508904e9994e03faa601d942242ad58f13a9559))
* streamline GitHub App token handling in CI workflow ([29aaa3c](https://github.com/lekman/auto-approve-action/commit/29aaa3caca5cf5419d572281e4f3895b01746379))
* update CI workflow to streamline GitHub App token handling and improve output management ([357fa5a](https://github.com/lekman/auto-approve-action/commit/357fa5a7f24074e14e8129c1ba7d2d76b72e4c41))
* update CODEOWNERS and workflows for improved auto-approval and testing functionality ([ef9fe08](https://github.com/lekman/auto-approve-action/commit/ef9fe08793329b33535b1bf7cbcc6dbae1ec8fbf))
* update GitHub App token action to use official action and add owner parameter ([fdae34a](https://github.com/lekman/auto-approve-action/commit/fdae34ab9bf8d41365f6bcfd58d76a44511e0f3f))
* update label validation logic to allow required labels with 'none' match mode and adjust test cases accordingly ([ba41075](https://github.com/lekman/auto-approve-action/commit/ba4107583efeb8a5de2c79defb8e11972d0d6c19))
* update permissions in test-approval-execution workflow to allow writing checks ([aad967b](https://github.com/lekman/auto-approve-action/commit/aad967b1aebcafacc3a68b9aa0263f651ac0d839))
* update workflows to require write permissions for pull requests and implement GitHub App token generation ([7f8b4bf](https://github.com/lekman/auto-approve-action/commit/7f8b4bf72a85b713b2e634c59794035b9ce69319))


### Bug Fixes

* clarify CI test reporting and remove stale references ([815f84c](https://github.com/lekman/auto-approve-action/commit/815f84c82f327950b0ba8c458237279d0b840fbf))
* correct glob pattern matching for file paths ([0e057cf](https://github.com/lekman/auto-approve-action/commit/0e057cf479c899f3a530c2342f8a9ec438dbf18c))
* disable wait-for-checks during testing to avoid waiting for other test jobs ([af51637](https://github.com/lekman/auto-approve-action/commit/af51637d42fea306eaae1766dabc220ad335ded4))
* ensure all CI tests use dry-run mode ([e27f3e3](https://github.com/lekman/auto-approve-action/commit/e27f3e38d4354a75b8f2778de656f567ead0e2ab))
* ensure GitHub App token is properly passed to dependent jobs ([77c930c](https://github.com/lekman/auto-approve-action/commit/77c930c5292e919a2b3c1bef9051f0172779d714))
* ensure unset commands do not fail in test-verify-author.sh ([e723b13](https://github.com/lekman/auto-approve-action/commit/e723b13fcc429b3e9c1b0c19d6c5a3bbabc01016))
* handle GitHub App token permissions correctly ([ad57c16](https://github.com/lekman/auto-approve-action/commit/ad57c1636452c69bb76132a557871cbb37532928))
* handle unset variables in test-validate-inputs.sh to prevent early exit ([f850aa4](https://github.com/lekman/auto-approve-action/commit/f850aa48650f3c7f7410716f8ccdd07c0e800e4a))
* improve error handling in CI workflow for token generation ([23a2cfe](https://github.com/lekman/auto-approve-action/commit/23a2cfe4272d106361911a8af07a087f7fc32b64))
* remove redundant message from job summary ([f16b4e9](https://github.com/lekman/auto-approve-action/commit/f16b4e98063b49aae92c36d556d22f004add6c6f))
* remove unnecessary blank line in CI workflow configuration ([b403a83](https://github.com/lekman/auto-approve-action/commit/b403a83444cf9be156569666ac6ed2a8c7b562f9))
* remove unnecessary dependency on setup job in integration tests ([5a0c5fb](https://github.com/lekman/auto-approve-action/commit/5a0c5fb89b84907d484bf643dfce3b93d9fb0c31))
* remove unnecessary push trigger from CI workflow ([b911394](https://github.com/lekman/auto-approve-action/commit/b9113943de6534f2cbe31db7d95316e7a8558502))
* resolve CI matrix and test execution issues ([8ab9458](https://github.com/lekman/auto-approve-action/commit/8ab94580335c9d21101b8542cbebc17f7c7f4ab5))
* resolve CI workflow failures ([f789200](https://github.com/lekman/auto-approve-action/commit/f78920099ff9865539161c61dcdf1cc12e827feb))
* resolve CI workflow token permission issues ([ae5cf0c](https://github.com/lekman/auto-approve-action/commit/ae5cf0c85bb31fa6da68f7cfacc66f254ea6aba3))
* resolve remaining CI test failures ([3811ec4](https://github.com/lekman/auto-approve-action/commit/3811ec42d477ed1d55267477dbf363b21200d01a))
* resolve test environment issues with gh command mocking ([a43d3e9](https://github.com/lekman/auto-approve-action/commit/a43d3e95611ce2f2012e12f744436f44bdab049f))
* resolve token passing issues in CI workflow ([346d46b](https://github.com/lekman/auto-approve-action/commit/346d46bbecb058e1f95429c6da4177861b8b1ffd))
* skip CI checks for release-please branches ([d3479a4](https://github.com/lekman/auto-approve-action/commit/d3479a4adbc26fe358c2fce4e06cb00872b0d4d2))
* specify repository name for GitHub App token generation ([78b35f4](https://github.com/lekman/auto-approve-action/commit/78b35f4279d71357a50d7c28878eb10ec307ba91))
* update changelog workflow to use GITHUB_TOKEN instead of NPM_TOKEN for token authentication ([3553a17](https://github.com/lekman/auto-approve-action/commit/3553a1735940f167900fbdaafd289a4b6938bc6b))
* update CI workflow to output token from app-token step ([d767f89](https://github.com/lekman/auto-approve-action/commit/d767f89c9097307061f80b3aa26de3d5f210fac1))
* update CI workflow to remove dependency on setup job and adjust VSCode settings to exclude files ([97ed026](https://github.com/lekman/auto-approve-action/commit/97ed0266fe91ff572503522d188af763cb0e19fb))
* update CI workflow to use token from setup job for GitHub actions ([5ac26b9](https://github.com/lekman/auto-approve-action/commit/5ac26b954658c51692440a1c5e65fc13e5c6c96d))
* update files.exclude settings in VSCode to hide sensitive files ([694b1f8](https://github.com/lekman/auto-approve-action/commit/694b1f8842fb5a5f71b49550bc750f1d633f6b43))
* use secrets.APP_ID instead of vars.APP_ID ([0fb6d73](https://github.com/lekman/auto-approve-action/commit/0fb6d734b5f2aef69a8047e824619cadee9ed6a9))

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
