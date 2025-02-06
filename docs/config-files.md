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
* [`defaults.conf` / `custom.conf`](#defaultsconf--customconf)
* [`$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`](#bitwardencli_connector_directory_typeargfileconftemplate)
  * [Common](#common)
  * [G Suite](#g-suite)

## Submodule set-up

It is recommended that you create your own private github repo to track these
config files, and add this project as a [git submodule]. This means you will not
need to fork and commit the files on a separate branch. The directory structure
for your project should be as follows:

```bash
YOUR_PROJECT_REPO_NAME
├── custom.conf
├── gsuite
│   ├── administration.conf
│   ├── sales.conf
│   └──  ...
└── bitwarden-directory-connector-containers   # <-- [git submodule]
```

<!-- markdownlint-disable-next-line no-emphasis-as-heading -->
_TODO: Add actual steps (Issue #17)_

## `defaults.conf` / `custom.conf`

The [`defaults.conf`] file contains variables which are used across multiple
scripts and Containerfiles. Do not edit `defaults.conf`! Instead, copy
`defaults.conf` to `custom.conf` and update that file.

The following chart is a description of the variables contained within and
where/how they are used.

| Variable | Format | Options | Description of use |
| --- | --- | --- | --- |
| `BWDC_VERSION` | YYYY.MM.N | Only building typed images:<UL><LI>2024.10.0</LI><LI>2025.01.0</LI></UL>Building `bwdc-base` image:<UL><LI>[Any released Directory Connector] version (no leading 'v')</LI></UL> | <LI>When running [`build-base-image.sh`], this variable specifies which version of `bwdc` to download to the [`bwdc-base` image] (See [base-image.md] for details).</LI><LI>When running [`build-typed-images.sh`] or [`ci.sh`]`-b`, this specifies which version of `ghcr.io/hdub-tech/bwdc-base` (_See Issue #15_) to pull FROM in the typed container (See [typed-images.md] for details).</LI> |
| `SECRETS_MANAGER` | String | <UL><LI>env</LI><LI>~podman~</LI></UL> | When running [`build-typed-images.sh`] or [`ci.sh`]`-r MODE`, this specifies how you are managing the secrets which will be used when the container is run (See [managing-secrets.md] for details). |
| `IMAGE_NAMESPACE` | [REGISTRY/]NAMESPACE | Examples: <LI>ghcr.io/hdub-tech</LI><LI>docker.io/orgname</LI><LI>orgname (registry defaults to localhost)</LI> | The namespace (optionally with registry) of the [`build-typed-images.sh`] / [`ci.sh`]`-b` generated images.<BR>NO IMAGES ARE PUSHED IN ANY OF THESE SCRIPTS, so this is for local tagging purposes only (See [typed-images.md] for details). |

## `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`

Each Directory Connector Type (G Suite, Okta, AD/LDAP, Entra ID/Azure, OneLogin)
has it's own settings which require configuration in order to use. In the
Bitwarden Directory Connector, these settings are input using a GUI app and
output to `$HOME/.config/Bitwarden Directory Connector/data.json`. The container
images in this project are built with the `--build-arg-file` flag using the path
to your configuration file, which should be copied from the
`$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/argfile.conf.template`.

### Common

* The `BWDC_${TYPE}_IMAGE_VERSION` setting allows you to individually tag a
  version for each individual configuration file/typed image. Updating it is
  optional and completely up to you.
* "Sync Interval" was deliberately omitted, as I didn't forsee these containers
  being a long running thing, if not just for security reasons. The only time
  secrets are accessible is while the containers are running.

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
| `GOOGLE_SYNC_USERS`<BR>`GOOGLE_SYNC_USER_FILTER`<BR>`GOOGLE_SYNC_GROUPS`<BR>`GOOGLE_SYNC_GROUP_FILTER`<BR>`GOOGLE_SYNC_REMOVE_DISABLED`<BR>`GOOGLE_SYNC_LARGE_IMPORT`<BR>`GOOGLE_SYNC_OVERWRITE_EXISTING` | These are the Google specify Sync settings, which map to the `Settings > Sync` panel in the Directory Connector app, referenced in Bitwarden's [Google Workspace > Configure sync options] documentation. |

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
[git submodule]:                    https://git-scm.com/book/en/v2/Git-Tools-Submodules
[Google Workspace > Configure sync options]:    https://bitwarden.com/help/ldap-directory/#configure-sync-options
[Google Workspace > Connect to your directory]: https://bitwarden.com/help/workspace-directory/#connect-to-your-directory

<!-- markdownlint-configure-file {
  MD033: false
}
-->
