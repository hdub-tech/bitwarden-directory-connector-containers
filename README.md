# bitwarden-directory-connector-containers

This project is designed to remove the need for using the [Bitwarden Directory
Connector desktop app] and/or simplify automation for [`bwdc`] when the user has
more than one sync profile. It utilizes containers, condensed key=value
configuration files (in lieu of data.json files, however those are also
unintentionally supported) and a separate secrets manager (podman, or anything
that can inject secrets as environment vars) so that no secrets are on disk or
stored within the generated images. Users can execute a single script once, and
it will build an image per sync configuration file, then run `bwdc test` and/or
`bwdc sync` on all of them.

This project has two sets of container images:

* The `bwdc-base` image (also referred to as the "base image"), which basically
  just has bwdc installed and a helper script. This is published to ghcr.io via
  the [Github packages for this project] and is already available to use without
  cloning this project or running scripts. This is only meant to be used
  directly by power users. See [base-image.md] for details.
* The "typed images", which are built off of the [`bwdc-base`] image and are
  specific to a Directory Connector type (often abbreviated here as
  `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE`) and a configuration file. This is
  the primary use case for this project and represent the images for general
  users. See [typed-images.md] for details.

> [!NOTE]
> Project currently only supports the Gsuite directory connector type for the
simplified config file method (See [`directory-connector` issues]), but it
supports `data.json` files of all directory connector types (admittedly
awkwardly, as it was not the project's purpose. See [BYO data.json method]).

## Table of Contents

* [Background](#background)
* [Scripts](#scripts)
* [Requirements](#requirements)
* [Getting Started](#getting-started)
* [License(s)](#licenses)
* [Contributing](#contributing)
* [Support + Feedback](#support--feedback)
* [Vulnerability Reporting](#vulnerability-reporting)
* [Thank You](#thank-you)

## Background

I personally did not like dealing with the Bitwarden app, and a bunch of
`data.json` files or having secrets stored in them. So I came up with a way to
use simple `key=value` configuration files (which mimic the Bitwarden Directory
Connector app screens), and generate individual container images containing
helper scripts to manage login/logout/test/sync.

## Scripts

Below is a summary of the main scripts in this project, the tasks they are
related to, files they depend on and links to documentation that explain them.

| Task | Script | Dependencies | Documentation |
| --- | --- | --- | --- |
| Build the `bwdc-base` image, which is the root of the rest of the containers. Published by @hdub-tech to [GitHub packages for this project]. | [`build-base-image.sh`] | - [`Containerfile`]<BR>- [`defaults.conf`] / `custom.conf`<BR>- [`build-push-base.yml`] | [base-image.md] |
| The [`ENTRYPOINT`] of the `bwdc-base` image, and therefore all typed images built off of it. | [`entrypoint.sh`] | N/A | [base-image.md] |
| Build per-configuration file images, one type per run, optionally without using the podman cache and optionally testing login even if the image was already built. | [`build-typed-images.sh`] | - [`defaults.conf`] / `custom.conf`<BR>- `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/Containerfile` ([`gsuite` Containerfile], as an example)<BR>- `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/$CONFNAME.conf` ([`gsuite` argfile template], as an example) | - [config-files.md]<BR>- [managing-secrets.md]<BR>- [typed-images.md] |
| Install/verify dependencies (optional), build all images of all types (EXCEPT the bwdc-base) and/or push and/or run all the images. | [`ci.sh`] | - [`defaults.conf`] / `custom.conf`<BR>- `*/Containerfile` ([`gsuite` Containerfile], as an example)<BR>- `*/$CONFNAME.conf` ([`gsuite` argfile template], as an example) | - [config-files.md]<BR>- [typed-images.md] |
| Utility functions used by other scripts | [`functions.sh`] | N/A | N/A |

## Requirements

* [Podman]>=4.5.0 (`--build-arg-file` option) _(Issue #5 - add Docker support)_
* bash
* apt (_ONLY if using [`ci.sh`] WITHOUT `-s` option_)
* jq (_ONLY if using podman secrets, which is not recommended with this project
  at this time: Issue #16_)

## Getting Started

> [!TIP]
> Read through these steps once before checking out the detailed documentation links!
>
> It is recommended (but not required) that you use this repository as a
submodule within your own repository "in production" (particularly if you are
using [`ci.sh`]), where your repository contains your `custom.conf` and
type-specific configuration files (See [config-files.md] for details). If you
are just playing around and trying this out though, use the "no submodule"
version of the steps below.

1. OPTIONAL: Copy the [`defaults.conf`] file to `custom.conf` file, and update
   `BWDC_VERSION`, `SECRETS_MANAGER` and `IMAGE_NAMESPACE` as needed (Detailed
   comments in file; detailed documentation: [config-files.md]). Skip this step
   if the defaults are acceptable.
   ```bash
   # EXAMPLE WHEN USED AS SUBMODULE
   cp ./bitwarden-directory-connector-containers/defaults.conf ./custom.conf
   ```
   ```bash
   # EXAMPLE FROM THIS PROJECT'S DIRECTORY (no submodule)
   cp defaults.conf custom.conf
   ```

2. Copy the `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template` to
   `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/$DESCRIPTIVE_NAME.conf` and update
   the conf file for your sync needs. This template contains detailed comments
   on what and how to update. (Detailed documentation at [config-files.md]). Do
   this once per sync profile / data.json file.
   ```bash
   # GSUITE EXAMPLE WHEN USED AS SUBMODULE
   mkdir gsuite
   cp bitwarden-directory-connector-containers/gsuite/argfile.conf.template gsuite/admins.conf
   vi gsuite/admins.conf
   ```
   ```bash
   # GSUITE EXAMPLE FROM THIS PROJECT'S DIRECTORY (no submodule)
   cp gsuite/argfile.conf.template gsuite/admins.conf
   vi gsuite/admins.conf
   ```

3. Export your `BW_CLIENTID` and `BW_CLIENTSECRET`, as well as any type specific
   secrets specified in `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/env.vars`
   ([`gsuite` env sample]) (Detailed documentation: [managing-secrets.md]).
   ```bash
   # EXAMPLE (disabling history for commands with leading spaces, then issue exports with a leading space)
   # Common / needed for all Types
   export HISTCONTROL="ignorespace"  # or ignoreboth, if you do not want dupes in history either
    export BW_CLIENTID="organization.123456"
    export BW_CLIENTSECRET="keepbitwardensecretsecret"
   ```
   ```bash
   # GSUITE EXAMPLE
    export BW_GSUITEKEY="keepgsuitekeysecret
   ```

4. Run the desired scripts for building and running the images:

    a. **_IF YOU WANT TO INSTALL DEPENDENCIES, BUILD ALL IMAGES OF ALL TYPES
    (not bwdc-base), AND RUN ALL THE IMAGES IN CONFIG, SYNC or TEST MODE (One
    script to rule them all)_**: Run the [`ci.sh`] script (Detailed
    documentation: [typed-images.md]).
      ```bash
      # EXAMPLE WHEN USED AS SUBMODULE
      # Use -h for all options with full descriptions
      # USAGE: ci.sh [-b] [-p] [-r config|test|sync] [-d CONFS_DIR] [-s]
      ./bitwarden-directory-connector-containers/ci.sh -b -r test
      ```
      ```bash
      # EXAMPLE FROM THIS PROJECT'S DIRECTORY (no submodule):
      # Use -h for all options with full descriptions
      # USAGE: ci.sh [-b] [-p] [-r config|test|sync] [-d CONFS_DIR] [-s]
      ./ci.sh -d $PWD -b -r test
      ```
    b. **_IF YOU ONLY WANT TO BUILD THE IMAGES OF ONE TYPE AND TEST BWDC
    LOGIN/LOGOUT_**: Run the [`build-typed-images.sh`] script once per
    `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE`, to build one image per config
    file and run `bwdc login` and `bwdc logout`, which is necesary for the
    build image process. No secrets will be stored to disk or in the
    environment of the produced image (Detailed documentation:
    [typed-images.md]. NOTE: currently does not support submodule method,
    Issue #14).
      ```bash
      # GSUITE EXAMPLE: Use -h for all options
      ./build-typed-images.sh -t gsuite
      ```

5. Copy the desired workflows to use in your superproject (Detailed
   [sample workflows documentation]):
   ```bash
   # From $YOUR_PROJECT_REPO, where bitwarden-directory-connector-containers is a submodule
   mkdir --parents .github/workflows
   cp ./bitwarden-directory-connector-containers/.github/workflows/samples/*.yml ./.github/workflows/
   ```

## License(s)

* [This project's license] (GNU GPL Version 3)
* Dependent project licenses are in the [licenses] subdirectory

## Contributing

Issues and PRs welcome!! Please see the [CONTRIBUTING.md] guide for expectations.

## Support + Feedback

At this writing, this project only has a single (first-time)
maintainer/contributor, who has a full-time job and a super busy life. That
said, I really want to help you, and I will try to do so in a timely manner.

* I have tried to thoroughly document this project, between this README and the
  [docs] subdirectory. I humbly ask that you review these resources before
  continuing to the next options.
* Use [Issues] to request new features and report bugs. Please review open
  issues first!
* Use [Discussions] for usage and other questions.

## Vulnerability Reporting

Please see the [SECURITY.md] guide for details.

## Thank You

* Thank you to the folks at @bitwarden for creating the open source [Directory Connector].
* Thank you to the folks at @auth0 for sharing an excellent [README-sample.md],
  which helped me craft this one.
* And a super extra thank you to my boss (Nick Popovich @ [Rotas Security]), who
  let me take extra time on completing my assignment to design this project
  generically and share it with the world (and my future self, who will completely
  forget all of this as soon as I roll onto the next project).

<!-- Links -->
[base-image.md]:                    ./docs/base-image.md
[`build-base-image.sh`]:            ./build-base-image.sh
[`build-push-base.yml`]:            ./.github/workflows/build-push-base.yml
[`build-typed-images.sh`]:          ./build-typed-images.sh
[`bwdc-base`]:                      ./Containerfile
[BYO data.json method]:             ./docs/base-image.md#byo-datajson-method
[`ci.sh`]:                          ./ci.sh
[config-files.md]:                  ./docs/config-files.md
[`Containerfile`]:                  ./Containerfile
[CONTRIBUTING.md]:                  ./docs/CONTRIBUTING.md
[`defaults.conf`]:                  ./defaults.conf
[docs]:                             ./docs
[`entrypoint.sh`]:                  ./entrypoint.sh
[`functions.sh`]:                   ./functions.sh
[`gsuite` argfile template]:        ./gsuite/argfile.conf.template
[`gsuite` Containerfile]:           ./gsuite/Containerfile
[`gsuite` env sample]:              ./gsuite/env.vars
[licenses]:                         ./licenses/
[SECURITY.md]:                      ./docs/SECURITY.md
[managing-secrets.md]:              ./docs/managing-secrets.md
[sample workflows documentation]:   ./.github/workflows/samples/README.md
[This project's license]:           ./LICENSE
[typed-images.md]:                  ./docs/typed-images.md
[Bitwarden Directory Connector desktop app]: https://bitwarden.com/help/directory-sync-desktop
[`bwdc`]:                           https://bitwarden.com/help/directory-sync-cli
[Directory Connector]:              https://github.com/bitwarden/directory-connector
[`directory-connector` issues]:     https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22Component%3A%20directory-connector%22
[Discussions]:                      https://github.com/hdub-tech/bitwarden-directory-connector-containers/discussions
[`ENTRYPOINT`]:                     https://docs.podman.io/en/latest/markdown/podman-run.1.html#entrypoint-command-command-arg1
[GitHub packages for this project]: https://github.com/users/hdub-tech/packages?repo_name=bitwarden-directory-connector-containers
[Issues]:                           https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues
[Podman]:                           https://podman.io/docs/installation
[README-sample.md]:                 https://github.com/auth0/open-source-template/blob/master/README-sample.md
[Rotas Security]:                   https://rotassecurity.com/

<!-- markdownlint-configure-file {
  MD013: {
    code_blocks: false
  },
}
-->
