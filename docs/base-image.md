# bwdc-base image

This README documents the `bwdc-base` image, also referred to as the "base image."
> [!TIP]
> If you are using the directory connector "typed" containers (Gsuite, etc),
which is the primary use case of this repo, you do not need to do anything
documented here!
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!TIP]
> If you are using the pre-built [`bwdc-base` package] hosted on [ghcr.io] with
the [BYO data.json method], you can skip directly to that section below.

## Table of Contents

- [Description](#description)
- [Building](#building)
  - [When](#when)
  - [Requirements](#requirements)
  - [How](#how)
- [Published Image](#published-image)
- [BYO data.json method](#byo-datajson-method)
  - [What the `${SECRETS}`?](#what-the-secrets)

## Description

The [`bwdc-base` image] is the `FROM` of the directory connector "typed" images
(Gsuite, etc) and it can be used if you are bringing your own (complete)
`data.json` files (rather than using the [config file method]). The image is
based on [Debian 12 slim] and it:

- Upgrades itself.
- Installs only the necessary packages.
- Creates a non-root `bitwarden` user and working directory.
- Downloads and installs [`bwdc` from Github] to `/usr/local/bin`
  (`BWDC_VERSION` specified in [`defaults.conf`] / `custom.conf`).
- Sets the `BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS` environment variable to
  `true` (necessary because we are working with [secrets in a headless
  environment]).
- Copies in the [`entrypoint.sh`] helper script (which has options to configure
  the `data.json` file with secrets exported to the environment, run `bwdc test`
  and/or `bwdc sync`, ensuring you are logged in and back out as necessary).

## Building

### When

Building the [`bwdc-base` image] is only required if:

1. You require a different version of `bwdc` than is already available in the
   [`bwdc-base` package] list.
2. You have trust issues (I get it, respect it, and I am you).
3. You are the maintainer or a contributor to this project.

### Requirements

- Podman _([Issue #5] - add Docker support)_

### How

> [!NOTE]
> This section is written _mostly_ from a contributor perspective.

1. SET the desired `BWDC_VERSION` and the `BDCC_VERSION` (active release) in...:
   - (_If you are a Contributor_): [`defaults.conf`]
   - (_For private use_): `custom.conf`
2. EXECUTE [`build-base-image.sh`] with the `-c` argument to confirm you want to
   build the [`bwdc-base` image] LOCALLY (_This will not push_):
    ```bash
    ./build-base-image.sh -c
    ```
3. TEST the produced `localhost/hdub-tech/bwdc-base:$BWDC_VERSION` container
   locally to ensure it still works.
<!-- markdownlint-disable blanks-around-lists ol-prefix -->
> [!IMPORTANT]
> Demonstrating how you tested will be REQUIRED for your PR, so please take
some screenshots and/or keep your test commands!
4. COMMIT the [`defaults.conf`] file (_Signed and Signed-Off commits please,
   real name is **NOT** required - see [CONTRIBUTING.md]_).
5. Open a PR to bump the version. Document how you tested. Ensure the Actions
   for your PR passed.
<!-- markdownlint-enable blanks-around-lists ol-prefix -->

## Published image

For the convenience of everyone, this repository publishes the
[`bwdc-base` package] to ghcr.io using the [`Build/Push` workflow] on new
Releases. The image is tagged with the version number of `bwdc` installed within
it. See [`bitwarden-directory-connector-containers` Releases] for currently
supported versions.

## BYO data.json method

The `ghcr.io/hdub-tech/bwdc-base` container DOES support being used in the same
fashion as the individually created directory connector "typed" containers.

> [!NOTE]
> _I created this project as part of a work task so, for the time being, I am only putting 9-5 time in on the things I need, while still trying to keep it decently clean, modular and professional. This means that it is currently only useful to other people using Gsuite OR people who have a pile of data.json files that they manage in some way, shape or form. Please understand that even though this method works, it was not intentionaly designed...it was just one of those things I realized would work after the fact. If you are using any of the other directory connectors, please comment on the corresponding open issue so I know you are interested in me moving forward on them ([LDAP], [Azure], [OneLogin], [Okta])._
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!NOTE]
> _Issue #4 tracks the desire to create a script for this._
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!CAUTION]
> The `bwdc` commands (and in turn, the [`entrypoint.sh`] script) modify things
like logged in status, last sync time, and sync hashes within the `data.json`
file.
>
> - If you do NOT want your `data.json` file modified at all, be sure to
include the `:O` (overlay) with the `--volume` option in the commands below.
> - If you DO want your `data.json` changes saved (for example, if you are
synchronizing large environments), omit the `:O` in the commands below.

### Non-interactively

To run the `bwdc-base` container NON-INTERACTIVELY using your own `data.json`
file, mount the directory containing your `data.json` file and utilize the
options for the [`entrypoint.sh`] script. If you have multiple `data.json`
files, ensure they are in separate directories, and run the command multiple
times, changing the volume as needed.

> [!IMPORTANT]
> Review the [What the `${SECRETS}`?](#what-the-secrets) section below

```bash
# Displays the entrypoint.sh usage message, describing how to config, test and sync (Does NOT edit the mounted directory [overlay]).
podman run ${SECRETS} --rm --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector:O --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_VERSION} -h
```

```bash
# Displays the entrypoint.sh usage message, describing how to config, test and sync (Syncs the mounted directory [no overlay]).
podman run ${SECRETS} --rm --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_VERSION} -h
```

### Interactively

To run the `bwdc-base` container INTERACTIVELY using your own `data.json` file,
mount the directory containing your `data.json` file and change the `entrypoint`
to `bash`:

> [!IMPORTANT]
> Review the [What the `${SECRETS}`?](#what-the-secrets) section below

```bash
# Executes container interactively WITHOUT allowing edits to the mounted directory (overlay).
podman run ${SECRETS} -it --rm --entrypoint bash --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector:O --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_VERSION}
```

```bash
# Executes container interactively WITH allowing edits to the mounted directory (no overlay).
podman run ${SECRETS} -it --rm --entrypoint bash --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_VERSION}
```

### The view from in the container

```bash
bitwarden@abcdef123456:~$ bwdc --version
2024.10.0

bitwarden@abcdef123456:~$ ls
entrypoint.sh

bitwarden@abcdef123456:~$ ./entrypoint.sh -h
  USAGE:
    entrypoint.sh [-c] [-t] [-s] [-h]
    ...
<snipped>
```

#### What the `${SECRETS}`?

As of this writing, I have only done the investigation and work for what is
needed for Gsuite. You might have to do some investigation of your own if using
other Directory Connector types. If you do, please share your findings on the
related tickets ([LDAP], [Azure], [OneLogin], [Okta])!

- **Option 1**: Your `data.json` files already contain the secrets in plain
  text (ANY directory connector type). You can just omit the `${SECRETS}`
  argument in the above commands! If you use the `entrypoint.sh` script, omit
  the `-c` flag. If you run `bwdc logout` in the container, and try to `bwdc
  login` again, you will be prompted for the Client ID and Client Secret.
- **Option 2**: You have Gsuite `data.json` files WITHOUT the secrets in them,
  and you are not looking to use the config files method.
  1. Set-up secrets as environment variables ~or with podman secrets~, as
     described in [managing-secrets.md].
  2. Substitute `${SECRETS}` with `--env-file gsuite/env.vars --env
     BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE=gsuite` in the above commands.
  3. If running NON-interactively, be sure to INCLUDE the `-c` option. If
     running interactively, be sure to use `-c` with `entrypoint.sh` OR be sure
     to run `bwdc config` before any other `bwdc` commands.
- **Option 3**: You are using NON-Gsuite directory connector type and the
  secrets are not in the `data.json`. (_If you are using any of the other
  directory connectors, please comment on the corresponding open issue so I know
  you are interested in me moving forward on them ([LDAP], [Azure], [OneLogin],
  [Okta])._)
  1. Run the container in Interactive mode, WITHOUT the `${SECRETS}` argument.
  2. Use the `bwdc config` command to set-up the secrets for your directory
     connector type.
  3. Use the `bwdc test` and `bwdc sync` commands as necessary.

<!-- Links -->
[BYO data.json method]:  #byo-datajson-method
[`build-base-image.sh`]: ../build-base-image.sh
[`Build/Push` workflow]: ../.github/workflows/build-push-base.yml
[`bwdc-base` image]:     ../Containerfile
[config file method]:    ./creating-configs.md
[CONTRIBUTING.md]:       ../CONTRIBUTING.md
[`defaults.conf`]:       ../defaults.conf
[`entrypoint.sh`]:       ../entrypoint.sh
[managing-secrets.md]:   ./managing-secrets.md
[Azure]:                 https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/9
[`bitwarden-directory-connector-containers` Releases]: https://github.com/hdub-tech/bitwarden-directory-connector-containers/releases
[`bwdc-base` package]:   https://github.com/users/hdub-tech/packages?repo_name=bitwarden-directory-connector-containers
[`bwdc` from Github]:    https://github.com/bitwarden/directory-connector/releases
[Debian 12 slim]:        https://hub.docker.com/_/debian/tags?name=12-slim
[ghcr.io]:               https://ghcr.io
[Issue #5]:              https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/5
[LDAP]:                  https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/8
[Okta]:                  https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/11
[OneLogin]:              https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/10
[secrets in a headless environment]: https://bitwarden.com/help/directory-sync-shared/#secret-storage-in-headless-environments

<!-- markdownlint-configure-file {
  MD013: {
    code_blocks: false
  }
} -->