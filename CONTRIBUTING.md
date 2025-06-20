# CONTRIBUTING (_WIP_)

## Issues and PRs welcome!!

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Initial set-up](#initial-set-up)
  - [Sign and Sign Off on commits](sign-and-sign-off-on-commits)
  - [Linting](#linting)
- [Releases](#releases)

## Code of Conduct

_[Issue #7]: Add Code of Conduct stuff. In the meantime, be good to each other or
I will banhammer you. You will have one opportunity to apologize for bad
behavior or you are gone._

## Initial set-up

In addition to cloning this project and installing the [Requirements], it is
recommended you do the things in the next few sections.

### Sign and Sign Off on commits

_[Issue #6]: Add [DCO]_

[Signing] (`Verified` tag / `git commit -S`) and [Signing off] (`Signed-Off-by`
in agreement with DCO / `git commit --signoff|-s`) on your commits is required.
HOWEVER, unlike most projects which require this, [@hdub-tech] will NEVER
require your real name to be in the `Signed-Off-by` line. We firmly believe you
should be able to contribute to open source AND maintain your privacy.

### Linting

All commits must pass the linter. This project contains a [Linting workflow]
which will kick off when PRs are opened. This workflow executes the
[pre-commit.sh] script. It is HIGHLY recommended that you link the
`.github/pre-commit.sh` to `.git/hooks/pre-commit.sh` so that this script will
execute for you locally before you even get to the PR stage.

```bash
# From the bitwarden-directory-connector-containers directory
mkdir .git/hooks  # If necessary
ln -s -r .github/pre-commit.sh .git/hooks/pre-commit
```

## Releases

> [!NOTE]
> _There is a pending todo ([Issue #39]) to convert this section to a workflow._
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!IMPORTANT]
> _This assumes you have already built and tested the base container as
> described in [docs/base-image.md#How]._

1. Determine the next version number for `BDCC_VERSION` using [Semantic versioning].

   ```bash
   # Do not include a leading 'v'! Example:
   export NEW_BDCC_VERSION=1.2.3
   ```

2. Ensure you are at the root of the project on the main branch with all
   relevant code merged to main and pulled locally.

   ```bash
   cd /PATH/TO/bitwarden-directory-connector-containers
   git checkout main
   git pull
   ```

3. Run the [`update-bdcc-version-branch.sh`] script to create a release branch,
   update `BDCC_VERSION` in all the necessary places, git add and commit the
   changed files, and push the `release/$NEW_BDCC_VERSION` branch to remote.

   ```bash
   ./.github/workflows/update-bdcc-version-branch.sh -v $NEW_BDCC_VERSION
   ```

4. Open a [pull request] for the `release/$NEW_BDCC_VERSION` branch and merge
   it to main.

5. Run the [Build/Push] workflow on Branch `main` to publish the new
   `bwdc-base` image.

> [!NOTE]
> _The reason this step is not AFTER drafting release, and the reason it is run
against `main` as opposed to the tag created during the release step, is to
save coming back to Edit the Release to add in the `$PKG_ID` which is not
generated until after the Push. Yes, this ID changes every release._

<!-- markdownlint-disable-next-line MD029 -->
6. Draft a [new release] with the following settings:

   a. Choose a tag: Type in `v$NEW_BDCC_VERSION` (Example: `v1.2.3`), and
      choose "Create new tag on publish".

   b. Target: `main`

   c. Previous tag: `auto`

   d. Click the button for "Generate release notes" (The Release Title field
      should now match the Tag).

   e. In the "What's changed" section:

      1. Change the `in FULL_PR_LINK` to just `(#xyz)` in each bullet.

      2. Remove the `Release/$NEW_BDCC_VERSION` line as it is redundant.

   f. Add the following blurb (updating `$PKG_ID`, `$NEW_BDCC_VERSION` and
      `$BWDC_VERSION`):

      <!-- markdownlint-disable MD013 -->
      ```markdown
      ## Assets

      Latest [`bwdc-base` package](https://github.com/hdub-tech/bitwarden-directory-connector-containers/pkgs/container/bwdc-base/$PKG_ID?tag=$NEW_BDCC_VERSION) tagged with: `$NEW_BDCC_VERSION` and `$BWDC_VERSION`
      ```
      <!-- markdownlint-enable MD013 -->
   g. Check the box for "Set as the latest release".

   h. Click the "Publish release" button.

<!-- Links -->
[docs/base-image.md#How]:          ./docs/base-image.md#How
[Linting workflow]:                ./.github/workflows/lint.yml
[pre-commit.sh]:                   ./.github/pre-commit.sh
[`update-bdcc-version-branch.sh`]: ./.github/workflows/update-bdcc-version-branch.sh
[DCO]:                 https://developercertificate.org/
[@hdub-tech]:          https://github.com/hdub-tech
[Build/Push]:          https://github.com/hdub-tech/bitwarden-directory-connector-containers/actions/workflows/build-push-base.yml
[Issue #6]:            https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/6
[Issue #7]:            https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/7
[Issue #39]:           https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/39
[new release]:         https://github.com/hdub-tech/bitwarden-directory-connector-containers/releases/new
[pull request]:        https://github.com/hdub-tech/bitwarden-directory-connector-containers/pulls
[Requirements]:        https://github.com/hdub-tech/bitwarden-directory-connector-containers/blob/main/README.md#requirements
[Semantic versioning]: https://semver.org/
[Signing]:             https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits
[Signing off]:         https://git-scm.com/docs/git-commit#Documentation/git-commit.txt-code--signoffcode

<!-- markdownlint-configure-file {
  MD026: false
}
-->
