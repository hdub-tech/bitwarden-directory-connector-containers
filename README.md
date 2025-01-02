# MASSIVE WIP - NOT AT ALL FINALIZED

# ABOUT

This project is designed to simplify automation for [`bwdc`] using containers
and a separate secrets manager so that no secrets are stored within the images.

# USAGE

## Secrets setup (first time)

1. Make sure your history is set to ignore commands with a leading space.
   `HISTCONTROL` should be set to `ignorespace` or `ignoreboth`.
   ```bash
    echo $HISTCONTROL
    ```
    If not set properly, run the following and consider adding it to your bashrc:
    ```bash
    export HISTCONTOL=ignorespace
    ```

2. Tell podman your secrets. ENSURE THESE COMMANDS ARE RUN WITH A LEADING SPACE!

   a. CLIENTID (format: `organization.UUID`) and CLIENTSECRET for logging in.
   ```bash
   # Leading space!
    echo -n "YOUR_BITWARDEN_CLIENT_ID" | podman secret create bw_clientid -
   ```
   ```bash
   # Leading space!
    echo -n "YOUR_BITWARDEN_CLIENT_SECRET" | podman secret create bw_clientsecret -
   ```
   b. The private key for your Google cloud project service user.
   ```bash
   # Leading space! ONE new line at the end!
    echo -n "-----BEGIN PRIVATE KEY-----\nMIIEvalueofGSuitePrivatekey\n-----END PRIVATE KEY-----\n" | podman secret create bw_key -
   ```

3. Make sure podman has your secrets (will not output secret values):
   ```bash
   podman secret list
   ```

## Build image

Execute the `docker-build.sh` script to build the images. This will ONLY
configure images and test `bwdc login` and `bwdc logout`. It will NOT execute
`bwdc test` or `bwdc sync` commands.

_Currently only supports `gsuite`._

```bash
# See detailed usage statement
./docker-build.sh -h
```

```bash
# Execute
./docker-build.sh -t BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE -s SECRETS_MANAGER [-n] [-r]
```

## Run image

After running `docker-build.sh`, the appropriate run command will be output to
the screen, since it varies by type. Running the container will do one of the
following:

* `config`: Finishes necessary configuration using the secrets provided
* `test`: Does the above config + runs "bwdc test"
* `sync`: Does the above config and test + runs "bwdc sync"

Below is a SAMPLE ONLY.

```bash
# SAMPLE ONLY!!
#To run non-interactively:
podman run ${SECRETS[*]} localhost/hdub-tech-bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}:${BWDC_VERSION} config|test|sync
```

```bash
# SAMPLE ONLY!!
#To run interactively:
podman run ${SECRETS[*]} -it --entrypoint bash localhost/hdub-tech-bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}:${BWDC_VERSION}
```

# Contributing

1. Link the pre-commit hook so that it will execute before commits.
    ```bash
    mkdir .git/hooks
    ln -s -r .github/pre-commit.sh .git/hooks/pre-commit
    ```

<!-- Links -->
[`bwdc`]: https://bitwarden.com/help/directory-sync-cli

<!-- markdownlint-configure-file {
  MD013: {
    code_blocks: false
  }
}
-->
