# Managing Secrets

This project currently supports the following methods of managing secrets when
running the containers:

* Secrets as exported environment variables (recommended)
* ~Secrets managed with [Podman secrets]~ (Nope - see [Issue #16])

> [!NOTE]
> In case you are wondering why Bitwarden secrets manager is not supported, it
is because this was created to _SETUP_ Bitwarden...so I have no vaults to even
pull from yet. Maybe once I play around with it, I will add support for it. Feel
free to open an issue if you are interested in seeing that feature.

## Exported environment variables (recommended)

1. If you are running this manually locally, make sure your history is set to
   ignore commands with a leading space. `HISTCONTROL` should be set to
   `ignorespace` or `ignoreboth`.
   ```bash
    echo $HISTCONTROL
    ```
    If not set properly, run the following and consider adding it to your bashrc:
    ```bash
    export HISTCONTROL=ignorespace
    ```

   <!-- markdownlint-disable-next-line no-space-in-code -->
2. Set your secrets by running ` export VARIABLE="VALUE"` (WITH A LEADING
   SPACE!) or setting them in your CI tool. The following table explains which
   variables are required and when, and points out if there are any quirks. All
   these variable names must be exact.

   | Variable | Type | Export if running... | Notes |
   | --- | --- | --- | --- |
   | `BW_CLIENTID` | All | - [`build-typed-images.sh`]<BR>- [`ci.sh`]<BR>- `podman run hdub-tech/bwdc-base` <BR>- `podman run bwdc-$TYPE-$CONF` | Format: `organization.UUID`<BR>Found in [Bitwarden Admin Console]. |
   | `BW_CLIENTSECRET` | All | - [`build-typed-images.sh`]<BR>- [`ci.sh`]<BR>- `podman run hdub-tech/bwdc-base`<BR>- `podman run bwdc-$TYPE-$CONF`  | Format: alphanumeric<BR>Found in [Bitwarden Admin Console]. |
   | `BW_GSUITEKEY` | Gsuite | - [`ci.sh`]<BR>- `podman run bwdc-$TYPE-$CONF` | Format (ONE new line at the end): `-----BEGIN PRIVATE KEY-----\nMIIEvalueofGSuitePrivatekey\n-----END PRIVATE KEY-----\n`<BR>Found in the GCP Console json formatted key for your [GCP service account]. |

## Podman secrets

This is currently only partially supported, and therefore I am skipping updating
this section and just leaving my original notes hidden. Please see [Issue #16] for
full details on how I got in this pickle.

<details>

   Tell podman your secrets. The secrets must be named as indicated below.
   ENSURE THESE COMMANDS ARE RUN WITH A LEADING SPACE!

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
         echo -n "-----BEGIN PRIVATE KEY-----\nMIIEvalueofGSuitePrivatekey\n-----END PRIVATE KEY-----\n" | podman secret create bw_gsuitekey -
        ```

</details>

<!-- Links -->
[Bitwarden Admin Console]: https://bitwarden.com/help/public-api/#authentication
[`build-typed-images.sh`]: ../build-typed-images.sh
[`ci.sh`]:                 ../ci.sh
[GCP service account]:     https://bitwarden.com/help/workspace-directory/#obtain-service-account-credentials
[Issue #16]:               https://github.com/hdub-tech/bitwarden-directory-connector-containers/issues/16
[Podman secrets]:          https://docs.podman.io/en/latest/markdown/podman-secret.1.html

<!-- markdownlint-configure-file {
  MD013: {
    code_blocks: false
  },
  MD033: false
}
-->
