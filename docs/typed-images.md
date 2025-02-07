# Typed images

"Typed images" refer to the images which are built off [`bwdc-base`] and are
specific to a Directory Connector type (also referred to as
`$BITWARDENCLI_DIRECTORY_CONNECTOR_TYPE`) and a config file (which would map to
a `data.json` file in Bitwarden Directory Connector). These containers are the
primary purpose/use case for this project.

Typed images (Example: [`gsuite/Containerfile`]) are driven by configuration
files which are expected to be in the format of the type specific template
(Example: [`gsuite` argfile template]) and in a directory named after the type
(Example: `gsuite`).

Typed image Containerfiles all follow the same basic format:

* Pull `FROM` [ghcr.io/hdub-tech/bwdc-base:$BWDC_VERSION].
* Export the `BITWARDENCLI_DIRECTORY_CONNECTOR_TYPE`.
* Set various OCI labels/
* Uses a non-privileged `bitwarden` user to:
  * Copy a `sync.json` file with the type specific sync settings (to be used in
    the `data.json` file).
  * Mounts the `BW_CLIENTID` and `BW_CLIENTSECRET` secrets for use during the
    build.
  * `bwdc login` (generates the `data.json` file).
  * `bwdc config directory $N` (with the appropriate directory connector type).
  * `bwdc logout`.
  * A massive `jq` statement to create a `data.json.new` file using the
    settings in the `*.conf` file.
  * Backs up the existing `data.json` file to `.old` and copies the `.new` one
    in its place.

> [!TIP]
> This guide assumes you have already set-up your configuration files and
optionally (but recommended) put them in your own project using this project as
a [git submodule]. Please see [config-files.md] for details.
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!TIP]
> This guide assumes you have already set-up your secrets. Please see
[managing-secrets.md] for details.

## Table of Contents

* [Building AND running (`ci.sh`)](#building-and-running-cish)
  * [Examples](#examples)
    * [WARNING](#warning)
    * [Build all images and run in test mode](#build-all-images-and-run-in-test-mode)
    * [Build all images and run in sync mode](#build-all-images-and-run-in-sync-mode)
    * [Run all containers in sync mode without building images or installing pre-requisites](#run-all-containers-in-sync-mode-without-building-images-or-installing-pre-requisites)
    * [Only build all images](#only-build-all-images)
* [Building](#building)
  * [build-typed-images.sh](#build-typed-imagessh)
    * [Examples](#examples-1)
      * [Build all gsuite images, using cached layers if available](#build-all-gsuite-images-using-cached-layers-if-available)
      * [Build all gsuite images, while always rebuilding the login stage](#build-all-gsuite-images-while-always-rebuilding-the-login-stage)
      * [Build all gsuite images, without using the cache](#build-all-gsuite-images-without-using-the-cache)
  * [podman build](#podman-build)
* [Running](#running)
  * [ci.sh](#cish)
  * [podman run](#podman-run)

## Building AND running (`ci.sh`)

> [!TIP]
> This is the ultimate and recommended way to use this project.

The [`ci.sh`] was designed to be the only command a CI system needs to execute.
It will **_build and run_** all typed images, depending on the options sent to
the script. A summary of the script is provided below.

> [!NOTE]
> **_Building_** an image will result in `bwdc login` and `bwdc logout`
commands being executed.
> **_Running_** a container can result in `bwdc test` and `bwdc sync` being
executed, if the options for that were specified.
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!WARNING]
> Run this script with `-h` to see the most up to date usage statement.

* Pre-requisites will be installed on the system, unless `-s` (skip) is specified.
* If this project is embedded as a submodule, configuration files will be copied
  into the submodule (_Stopgap until [Issue #14] is resolved_).
* Pulls in [`defaults.conf`], and then `custom.conf` for any overrides.
* Builds all images for all configuration files for all supported Directory
  Connector types, if `-b` was specified.
* Runs all containers in the specified `MODE`, if `-r MODE` was specified, where
  `MODE` is one of:
  * `config`: Runs each container, finishing the necessary configuration using
  the secrets provided
  * `test`: Does the above config AND runs "bwdc test"
  * `sync`: Does the above config + test AND runs "bwdc sync"

### Examples

#### WARNING

> [!WARNING]
> The following commands are listed as if this project was a submodule of your
project. Omit the leading `bitwarden-directory-connector-containers` directory
and add the option `-p $PWD` if you are still playing around and have not gotten
to that stage yet.

#### Build all images and run in test mode

```bash
# Install pre-reqs, build all images, and run all images in config+test mode
./bitwarden-directory-connector-containers/ci.sh -b -r test
```

#### Build all images and run in sync mode

```bash
# Slow primary use case
# Install pre-reqs, build all images, and run all images in config+test+sync mode
./bitwarden-directory-connector-containers/ci.sh -b -r sync
```

#### Run all containers in sync mode without building images or installing pre-requisites

This is particularly useful if you have published the typed images to your own
container registry and updated `IMAGE_NAMESPACE` in `custom.conf`, and are
looking to save time on the build. Skipping the pre-requisites is useful if you
already have a basic runner set-up with the dependencies and/or you need to
manage the installation of podman manually (i.e. because the version in Debian
is too old).

```bash
# Fast primary use case
# ONLY run all images in config+test+sync mode
./bitwarden-directory-connector-containers/ci.sh -s -r sync
```

#### Only build all images

This is useful if you want to push the images to your own container registry so
you can take advantage of the previous example, which will speed up runtimes.

```bash
# ONLY build all images
./bitwarden-directory-connector-containers/ci.sh -s -b
```

## Building

### build-typed-images.sh

The [`build-typed-images.sh`] script will build one image per
`$BITWARDENCLI_DIRECTORY_CONNECTOR_TYPE/*.conf` file, based on the option
provided to the script. It is used under the hood by [`ci.sh`]. While `ci.sh`
is the workhorse/recommended use case, this script is useful if you are just
getting started testing this project to see if it works for your use case, and
you haven't set-up your own project with this project as a submodule (Details:
[Submodule set-up]). A summary of the script is provided below.

> [!WARNING]
> Run this script with `-h` to see the most up to date usage statement.

* Script confirms the appropriate secrets are available (`BW_CLIENTID` and
  `BW_CLIENTSECRET`), based on the `SECRETS_MANAGER` setting in
  [`defaults.conf`]/`custom.conf`
* For each `*.conf` file in the `$BITWARDENCLI_DIRECTORY_CONNECTOR_TYPE`
  directory, `podman build` is executed:
  * supplying the `.conf` file with `--build-arg-file`
  * supplying the secrets with `--secret`
  * supplying the `BWDC_VERSION` and the name of the conf file with `--build-arg`
  * tagging it as the `$IMAGE_NAMESPACE/bwdc-${BITWARDENCLI_DIRECTORY_CONNECTOR_TYPE}-${CONF_NAME}:${BWDC_<TYPE>_IMAGE_VERSION}`
  * The Containerfile build process is described at [the top of this document]
* A `podman run` usage statement is output, in case a user wants a quick way to
  see how to use the generated image.

#### Examples

##### Build all gsuite images, using cached layers if available

Primary use case for this script.

```bash
# GSUITE EXAMPLE
./build-typed-images.sh -t gsuite
```

##### Build all gsuite images, while always rebuilding the login stage

This is useful if you have recently rotated secrets (which would not be picked
up by podman) and/or you want to regenerate the `data.json` within the image (no
secrets are stored within) and/or test `bwdc login` and `bwdc logout`.

```bash
# GSUITE EXAMPLE
./build-typed-images.sh -t gsuite -r
```

##### Build all gsuite images, without using the cache

```bash
# GSUITE EXAMPLE
./build-typed-images.sh -t gsuite -n
```

### podman build

If you really want to use `podman build` directly, please see the USAGE
statement at the top of the corresponding Containerfile.

* [`gsuite/Containerfile`]

## Running

### ci.sh

Refer to the [Run all containers] example in the [Building and running
(`ci.sh`)] section.

### podman run

If you really want to use `podman run` directly, please see the USAGE statement
at the top of the corresponding Containerfile.

* [`gsuite/Containerfile`]

<!-- Links -->
[Building AND running (`ci.sh`)]: #building-and-running-cish
[the top of this document]:       #typed-images
[Run all containers]:             #run-all-containers-in-sync-mode-without-building-images-or-installing-pre-requisites
[`bwdc-base`]:                   ./base-image.md
[`build-typed-images.sh`]:       ../build-typed-images.sh
[`ci.sh`]:                       ../ci.sh
[config-files.md]:               ./config-files.md
[Submodule set-up]:              ./config-files.md#submodule-set-up
[`defaults.conf`]:               ../defaults.conf
[`gsuite` argfile template]:     ../gsuite/argfile.conf.template
[`gsuite/Containerfile`]:        ../gsuite/Containerfile
[managing-secrets.md]:           ./managing-secrets.md
[ghcr.io/hdub-tech/bwdc-base:$BWDC_VERSION]: https://github.com/users/hdub-tech/packages?repo_name=bitwarden-directory-connector-containers
[git submodule]:                             https://git-scm.com/book/en/v2/Git-Tools-Submodules
[Issue #14]:                                 https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/14

<!-- markdownlint-configure-file {
  MD024: false
}
-->
