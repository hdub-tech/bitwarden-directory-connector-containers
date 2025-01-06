# MASSIVE WIP - NOT AT ALL FINALIZED

# ABOUT

This project is designed to simplify automation for [`bwdc`] using containers
and a separate secrets manager so that no secrets are stored within the images.

# REQUIREMENTS

Podman. (_TODO: Ensure works with Docker_)

# USAGE

## Configuration files

Template configuration files are included for each supported Directory Connector
type.  _Currently only supports `gsuite`._

> _COMING "SOON": data.json support_

1. Change to the `BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE` directory and copy the
   template file. Give it a descriptive name ending in `.conf`. For example, if
   this conf file will contain a User filter for your "Engineering" OU, call it
   `engineering.conf`.

   The following is an EXAMPLE:
   ```bash
   cd gsuite
   cp argfile.conf.template engineering.conf
   ```

2. Edit the new conf file for your needs. There are detailed comments in this
   file describing each option and what the equivalent setting is in the
   Bitwarden Directory Connector app.

## Secrets setup (first time)

1. Make sure your history is set to ignore commands with a leading space.
   `HISTCONTROL` should be set to `ignorespace` or `ignoreboth`.
   ```bash
    echo $HISTCONTROL
    ```
    If not set properly, run the following and consider adding it to your bashrc:
    ```bash
    export HISTCONTROL=ignorespace
    ```

2. Set your secrets. Currently only supports podman secrets or environment variables.

   a. OPTION A: Tell podman your secrets. The secrets must be named as
      indicated below. ENSURE THESE COMMANDS ARE RUN WITH A LEADING SPACE!

     1. CLIENTID (format: `organization.UUID`) and CLIENTSECRET for logging in.
        ```bash
        # Leading space!
         echo -n "YOUR_BITWARDEN_CLIENT_ID" | podman secret create bw_clientid -
        ```
        ```bash
        # Leading space!
         echo -n "YOUR_BITWARDEN_CLIENT_SECRET" | podman secret create bw_clientsecret -
        ```
     2. GSUITE ONLY: The private key for your Google cloud project service user.
        ```bash
        # Leading space! ONE new line at the end!
         echo -n "-----BEGIN PRIVATE KEY-----\nMIIEvalueofGSuitePrivatekey\n-----END PRIVATE KEY-----\n" | podman secret create bw_key -
        ```

   b. OPTION B: Set secrets as environment variables. The variables must be
      named as indicated below. ENSURE THESE COMMANDS ARE RUN WITH A LEADING
      SPACE!

     1. CLIENTID (format: `organization.UUID`) and CLIENTSECRET for logging in.
        ```bash
        # Leading space!
          export BW_CLIENTID="YOUR_BITWARDEN_CLIENT_ID"
        ```
        ```bash
        # Leading space!
         export BW_CLIENT_SECRET="YOUR_BITWARDEN_CLIENT_SECRET"
        ```
     2. GSUITE ONLY: The private key for your Google cloud project service user.
        ```bash
        # Leading space! ONE new line at the end!
         export BW_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvalueofGSuitePrivatekey\n-----END PRIVATE KEY-----\n"
        ```

## Build images

Execute the `docker-build.sh` script to build the images. This will ONLY
configure images and test `bwdc login` and `bwdc logout`. It will NOT execute
`bwdc test` or `bwdc sync` commands. No images will store any secrets.

All `*.conf` files in the `BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE` directory will
be processed, and an image will be created and tagged for each.

_Currently only supports `gsuite`._

```bash
# See detailed usage statement
./docker-build.sh -h
```

```bash
# Execute
./docker-build.sh -t BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE [-s SECRETS_MANAGER] [-b BWDC_VERSION] [-n] [-r]
```

After successful execution, a USABLE sample run command will be output.

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
podman run ${SECRETS[*]} localhost/hdub-tech/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-CONFNAME:${VERSION} config|test|sync
```

```bash
# SAMPLE ONLY!!
#To run interactively:
podman run ${SECRETS[*]} -it --entrypoint bash localhost/hdub-tech/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-CONFNAME:${VERSION}
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
