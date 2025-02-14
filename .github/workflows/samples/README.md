# Superproject workflow samples

These workflows should be copied to a superproject where
`bitwarden-directory-connector-containers` is a submodule. Place them in
`$YOUR_PROJECT_REPO_NAME/.github/workflows` to have them appear on the Actions
tab of your superproject.

> [!TIP]
> You will need to set the secrets specified in [managing-secrets.md] in your
[Github repository secrets] settings to successfully execute the workflows.
<!-- markdownlint-disable-next-line no-blanks-blockquote -->
> [!NOTE]
> The workflows in this subdirectory should not appear in the main
`bitwarden-directory-connector-container` Actions because subdirectories are not
supported.

| Workflow | Action | When | Notes |
| --- | --- | --- | --- |
| [build-all-typed-images.yml] | Builds one typed image per `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/*.conf` using [`ci.sh`]`-b` | - PRs to main<BR>- On demand | Just building the images is not really helpful without pushing them, unless you are testing changes to your conf files and want to know they will work when you do push. |
| [build-and-push-all-typed-images.yml] | Builds one typed image per `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/*.conf` and pushes all `bwdc-*` images to `$IMAGE_NAMESPACE` using [`ci.sh`]`-b -p` | On demand | Ideal job to run as needed to get your images built and pushed to your container registry.<BR><BR>By default, this uses `github.actor` and `github.token` to login to the container registry. If these will not work for you, you will need to edit the workflow file. There are commented out examples for using Github Secrets included. |
| [run-all-typed-images.yml] | Runs each container matching to the `$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/*.conf` files using [`ci.sh`]`-r MODE`| On demand (with input) | Options are `config`, `test` and `sync`, and behave the same as they would for `-r MODE` with [`ci.sh`] |

<!-- Links -->
[build-all-typed-images.yml]:          ./build-all-typed-images.yml
[build-and-push-all-typed-images.yml]: ./build-and-push-all-typed-images.yml
[run-all-typed-images.yml]:            ./run-all-typed-images.yml
[`ci.sh`]:                             ../../../ci.sh
[managing-secrets.md]:                 ../../../docs/managing-secrets.md
[Github repository secrets]: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository
<!-- markdownlint-configure-file {
 MD033: false
}
-->
