# Superproject workflow samples

The workflows in this subdirectory should not appear in the main
bitwarden-directory-connector-container Actions because subdirectories are not
supported. These are meant to be copied to a superproject where
bitwarden-directory-connector-containers is a submodule.

| Workflow | Action | When | Notes |
| --- | --- | --- | --- |
| [build-all-typed-images.yml] | Builds one typed images per `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/*.conf` using [`ci.sh`] | - PRs to main<BR>- On demand | Just building the images isn't really helpful without pushing them, unless you are testing changes to your conf files and want to know they will work when you do push. |

<!-- Links -->
[build-all-typed-images.yml]:     ./build-all-typed-images.yml
[`ci.sh`]:                        ../../../ci.sh

<!-- markdownlint-configure-file {
 MD033: false
}
-->