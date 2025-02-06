# CONTRIBUTING (WIP)

## Issues and PRs welcome!!

_Issue #6: Add Code of Conduct stuff. In the meantime, be good to each other or
I will banhammer you. You will have one opportunity to apologize for bad
behavior, and then you are gone._

_Issue #7: Add [DCO]_

> [!TIP]
> Signing (`Verified` tag) and Signing off on (`Signed-Off-by`) your commits is
required. HOWEVER, unlike most projects which require this, @hdub-tech will
NEVER require your real name be in the `Signed-Off-by` line. We firmly believe
you should be able to contribute to open source AND maintain your privacy.

## Linting

This project contains a [Linting workflow] which will kick off when PRs are
opened. This workflow executes the [pre-commit.sh] script. It is HIGHLY
recommended that you link the `.github/pre-commit.sh` to
`.git/hooks/pre-commit.sh` so that this script will execute for you locally
before you even get to the PR stage.

```bash
mkdir .git/hooks  # If necessary
ln -s -r .github/pre-commit.sh .git/hooks/pre-commit
```

<!-- Links -->
[Linting workflow]: ./.github/workflows/lint.yml
[pre-commit.sh]:    ./.github/pre-commit.sh
[DCO]:              https://developercertificate.org/_

<!-- markdownlint-configure-file {
  MD026: false
}
-->