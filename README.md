# SETUP

## Secrets setup

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
   a. CLIENTID and CLIENTSECRET for logging in.
   ```bash
    echo -n "organization.UUID" | podman secret create bw_clientid -
   ```
   ```bash
    echo -n "abcdefg" | podman secret create bw_clientsecret -
   ```
   ```bash
    echo -n "-----BEGIN PRIVATE KEY-----\nMIIEvalueofGSuitePrivatekey\n-----END PRIVATE KEY-----\n" | podman secret create bw_key -
   ```

3. Make sure podman has your secrets (will not output secret values):
   ```bash
   podman secret list
   ```
