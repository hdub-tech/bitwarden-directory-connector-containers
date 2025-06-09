# Configuration files

This project contains two different sets of configuration files, none of which
contain secrets:

* One set for common configurations across multiple shell scripts and all
  Containerfiles ([`defaults.conf`/ `custom.conf`](#defaultsconf--customconf)).
* One set specific to each of the typed images
([`$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`])

This document explains how to set-up configuration files based on your use case.

## Table of Contents

* [Submodule set-up](#submodule-set-up)
  * [Adding bitwarden-directory-connector-containers as a submodule](#adding-bitwarden-directory-connector-containers-as-a-submodule)
  * [Setting submodule to a specific release](#setting-submodule-to-a-specific-release)
* [`defaults.conf` / `custom.conf`](#defaultsconf--customconf)
* [`$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`](#bitwardencli_connector_directory_typeargfileconftemplate)
  * [Common](#common)
  * [G Suite](#g-suite)

## Submodule set-up

It is recommended that you create your own private repository to track these
config files, and add this project as a [git submodule]. This means you will not
need to fork and commit the files on a separate branch. The directory structure
for your project should be as follows:

```bash
YOUR_PROJECT_REPO_NAME
├── custom.conf
├── gsuite/
│   ├── administration.conf
│   ├── sales.conf
│   └──  ...
├── .github/workflows/  # Copy from this project's .github/workflows/samples
|   ├── build-all-typed-images.yml
|   ├── build-and-push-all-typed-images.yml
|   └── run-all-typed-images.yml
└── bitwarden-directory-connector-containers/   # <-- [git submodule]
```

### Adding bitwarden-directory-connector-containers as a submodule

> [!TIP]
> Please review [git submodule] documentation to ensure you have an
understanding of how these work before continuing.

The commands to add this project to your git project as a submodule would look
something like this:

```bash
cd YOUR_PROJECT_REPO_NAME
git submodule add https://github.com/hdub-tech/bitwarden-directory-connector-containers
git commit -m "Add hdub-tech/bitwarden-directory-connector-containers as submodule"
```

### Setting submodule to a specific release

> [!WARNING]
> The following assumes you have already added the submodule to your project.

When you add a submodule to your project, it will be locked to the commit you
checked out. If you would like to lock it to a specific tag/release, you can do
the following:

```bash
cd YOUR_PROJECT_REPO_NAME/bitwarden-directory-connector-containers
git fetch  # To fetch new tags/branches
git checkout v1.3.0  # Or your preferred tag
cd ..
git add bitwarden-directory-connector-containers
git commit -m "Set bitwarden-directory-connector-containers to v1.3.0"
```

## `defaults.conf` / `custom.conf`

The [`defaults.conf`] file contains variables which are used across multiple
scripts and Containerfiles. You should be able to use this project without
modifying any of these settings. However, the following chart is supplied for
advanced users and includes a description of the variables contained within
and where/how they are used.

> [!WARNING]
> If you plan to push images to a registry, you must set `IMAGE_NAMESPACE`
to match your registry in `custom.conf`!
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!WARNING]
> Do not edit `defaults.conf` directly! Instead, COPY `defaults.conf` to
`custom.conf` and update that file.

| Variable | Format | Options | Description of use |
| --- | --- | --- | --- |
| `BWDC_VERSION` | YYYY.M.N | Building typed images (general users):<UL><LI>2024.10.0</LI><LI>2025.1.0</LI><LI>2025.5.0</LI></UL>Building `bwdc-base` image (maintainers/power users):<UL><LI>[Any released Directory Connector] version (no leading 'v')</LI></UL> | <LI>When running [`build-typed-images.sh`] or [`ci.sh`]`-b`, this specifies which version of `ghcr.io/hdub-tech/bwdc-base` (_See Issue #15_) to pull `FROM` in the typed container (See [typed-images.md] for details).</LI><LI>When running [`build-base-image.sh`], this variable specifies which version of `bwdc` to download to the [`bwdc-base` image] (See [base-image.md] for details).</LI> |
| `BDCC_VERSION` | X.Y.Z | Building typed images: <UL><LI>[Any tag for this project] (no leading 'v')</LI></UL>Building `bwdc-base` image<UL><LI>Follow [Semantic versioning]</LI></UL> | This is for: <UL><LI> Maintainers to tag and release `bwdc-base` tied to the Github project release version</LI><LI>Users who are uncomfortable with image tags being rewritten (Again, I get it, I am you). See also `USE_BDCC_VERSION_FOR_TYPED`</LI></UL> |
| `USE_BDCC_VERSION_FOR_TYPED` | Boolean | <UL><LI>false (default)</LI><LI>true</LI></UL> | Set this to `true` if you want to pull the `bwdc-base` image using the `BDCC_VERSION` tag instead of the `BWDC_VERSION` tag when running [`build-typed-images.sh`].<BR><BR>I initially designed the tagging of `bwdc-base` with simplicity and convenience in mind - users would only need to know the version of `bwdc` they cared about, and that would be the tag. However, when I found [the first real bug], I realized I would have to republish the `bwdc-base` image, and if I tagged only on the version of `bwdc`, I would be overwriting an existing tagged image. Being a security minded person myself, I knew I would HATE being on the receiving end of that without at least an OPTION to control it. In my defense, I was additionally tagging `bwdc-base` with the git ref, but I didn't implement any way for users to utilize that, plus a sha isn't exactly a user friendly format. So tagging based on the release and adding this boolean is the best I could come up with on short notice. |
| `SECRETS_MANAGER` | String | <UL><LI>env</LI><LI>~podman~</LI></UL> | When running [`build-typed-images.sh`] or [`ci.sh`]`-r MODE`, this specifies how you are managing the secrets which will be used when the container is run (See [managing-secrets.md] for details). |
| `IMAGE_NAMESPACE` | REGISTRY/NAMESPACE | Examples: <LI>ghcr.io/hdub-tech</LI><LI>docker.io/orgname</LI><LI>localhost/orgname</LI> | The registry/namespace of the [`build-typed-images.sh`] / [`ci.sh`]`[-b\|-p]` generated/pushed images.<BR>Images are ONLY pushed with the `-p` option on `ci.sh`(See [typed-images.md] for details). |

## `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`

Each Directory Connector Type (G Suite, Okta, AD/LDAP, Entra ID/Azure, OneLogin)
has it's own settings which require configuration in order to use. In the
Bitwarden Directory Connector, these settings are input using a GUI app and
output to `$HOME/.config/Bitwarden Directory Connector/data.json`. The container
images in this project are built with the `--build-arg-file` flag using the path
to your configuration file, which should be copied from the
`$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`.

### Common

* `BWDC_${TYPE}_IMAGE_VERSION`: this setting allows you to specify the image tag
  for each individual configuration file/typed image. _Updating it is OPTIONAL
  and completely up to you and has NO EFFECT on what underlying bwdc base is
  used!_ It was _designed_ to be used to tag typed images with a version that
  only conveys the `bwdc-base` version the image was built on, while still allowing
  users to version their own changes to the configuration files.
  * G Suite Example: `BWDC_GSUITE_IMAGE_VERSION=1.2.0-0` would be a simple way
    to tag an image to indicate the base image was `1.2.0` and that this conf
    file is on its first iteration. If users need to update something like
    `GOOGLE_SERVICE_USER_EMAIL`, they can update the version to `1.2.0-1` to
    tag the image with a different version.

> [!TIP]
> Extra emphasis that this version number has nothing to do with which
> bwdc-base version is used for the typed image (That is driven by `BWDC_VERSION`
> or `BDCC_VERSION` in [`defaults.conf`]). This setting is for tagging and
> _informational_ use only.
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!NOTE]
> [Issue #46] is planned to create a script which will allow users to easily
> update the base image version portion of this field in all configuration
> files.

* "Sync Interval" was deliberately omitted, as these containers were designed
   to be short lived, if not just for security reasons. The only time secrets
   are accessible is while the containers are running.

### G Suite

This section documents the [`gsuite` argfile template]. The template has
required values uncommented, detailed comments on what each setting corresponds
to and examples. If you are trying to compare the template values to their
corresponding `data.json` values, refer to the `jq` command in the
[`gsuite/Containerfile`].

| Setting(s) | Reference |
| --- | --- |
| `GOOGLE_DOMAIN`<BR>`GOOGLE_ADMIN_USER_EMAIL`<BR>`GOOGLE_CUSTOMER` | These are the Google Admin settings, which map to the `Settings > Directory` panel in the Directory Connector app, referenced in Bitwarden's [Google Workspace > Connect to your directory] documentation |
| `GOOGLE_SERVICE_USER_EMAIL` | This is the Google Cloud service user email, which maps to the `Client Email (from key file)` field on the `Settings > Directory` panel in the Directory Connector app. This field isn't directly mentioned in the Bitwarden docs, because it is parsed from the uploaded JSON formatted key from the [Google Workspace > Connect to your directory] documentation (Step 7) |
| `GOOGLE_SYNC_USERS`<BR>`GOOGLE_SYNC_USER_FILTER`<BR>`GOOGLE_SYNC_GROUPS`<BR>`GOOGLE_SYNC_GROUP_FILTER`<BR>`GOOGLE_SYNC_REMOVE_DISABLED`<BR>`GOOGLE_SYNC_LARGE_IMPORT`<BR>`GOOGLE_SYNC_OVERWRITE_EXISTING` | These are the Google specific Sync settings, which map to the `Settings > Sync` panel in the Directory Connector app, referenced in Bitwarden's [Google Workspace > Configure sync options] documentation. |

<!-- Links -->
[`$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`]:  #bitwardencli_connector_directory_typeargfileconftemplate
[base-image.md]:             ./base-image.md
[`build-base-image.sh`]:     ../build-base-image.sh
[`build-typed-images.sh`]:   ../build-typed-images.sh
[`bwdc-base` image]:         ../Containerfile
[`ci.sh`]:                   ../ci.sh
[`defaults.conf`]:           ../defaults.conf
[`gsuite/Containerfile`]:    ../gsuite/Containerfile
[`gsuite` argfile template]: ../gsuite/argfile.conf.template
[managing-secrets.md]:       ./managing-secrets.md
[typed-images.md]:           ./typed-images.md
[Any released Directory Connector]: https://github.com/bitwarden/directory-connector/releases
[Any tag for this project]:         https://github.com/hdub-tech/bitwarden-directory-connector-containers/tags
[git submodule]:                    https://git-scm.com/book/en/v2/Git-Tools-Submodules
[Google Workspace > Configure sync options]:    https://bitwarden.com/help/ldap-directory/#configure-sync-options
[Google Workspace > Connect to your directory]: https://bitwarden.com/help/workspace-directory/#connect-to-your-directory
[Issue #46]:                                    https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/46
[Semantic versioning]:                          https://semver.org
[the first real bug]:                           https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/27
