# Superproject workflow samples

The workflows in this subdirectory should not appear in the main
bitwarden-directory-connector-container Actions because subdirectories are not
supported. These are meant to be copied to a superproject where
bitwarden-directory-connector-containers is a submodule.

| Workflow | Action | When | Notes |
| --- | --- | --- | --- |
| [build-all-typed-images.yml] | Builds one typed image per `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/*.conf` using [`ci.sh`] | - PRs to main<BR>- On demand | Just building the images is not really helpful without pushing them, unless you are testing changes to your conf files and want to know they will work when you do push. |
| [build-and-push-all-typed-images.yml] | Builds one typed image per `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/*.conf` and pushes all `bwdc-*` images to `$IMAGE_NAMESPACE` using [`ci.sh`] | On demand | Ideal job to run as needed to get your images built and pushed to your container registry.<BR><BR>By default, this uses `github.actor` and `github.token` to login to the container registry. If these will not work for you, you will need to edit the workflow file. There are commented out examples for using Github Secrets included. |

<!-- Links -->
[build-all-typed-images.yml]:          ./build-all-typed-images.yml
[build-and-push-all-typed-images.yml]: ./build-and-push-all-typed-images.yml
[`ci.sh`]:                             ../../../ci.sh

<!-- markdownlint-configure-file {
 MD033: false
}
-->
