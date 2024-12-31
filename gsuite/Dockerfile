ARG BWDC_VERSION=2024.10.0
FROM hdub-tech-bwdc-base:$BWDC_VERSION

# User
ARG BWUSER=bitwarden
ARG BWUID=1000
USER $BWUSER

ENV BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE=gsuite

# Configurable arguments (Use $REPO/$TYPE/argfile.conf for overrides)
ARG GOOGLE_DOMAIN
ARG GOOGLE_ADMIN_USER_EMAIL
ARG GOOGLE_CUSTOMER=""
ARG GOOGLE_SERVICE_USER_EMAIL
ARG GOOGLE_SYNC_USERS=false
ARG GOOGLE_SYNC_USER_FILTER=""
ARG GOOGLE_SYNC_GROUPS=false
ARG GOOGLE_SYNC_GROUP_FILTER=""
ARG GOOGLE_SYNC_REMOVE_DISABLED=false
ARG GOOGLE_SYNC_OVERWRITE_EXISTING=false
ARG GOOGLE_SYNC_LARGE_IMPORT=false

# Copy in the sync block
COPY --chown=$BWUID:$BWUID --chmod=700 sync.json $WORKING_DIR/

ARG OPTIONAL_REBUILD_BWDC_LOGIN_STAGE
# Run login to initialize the data.json file. bwdc config only works after
# login, and only can set a few options. Logout necessary due to bwdc having a
# heart attack if you modify json file while logged in.
RUN --mount=type=secret,id=bw_clientid,uid=$BWUID \
    --mount=type=secret,id=bw_clientsecret,uid=$BWUID \
    BW_CLIENTID="$( cat /run/secrets/bw_clientid )" \
    && export BW_CLIENTID \
    && BW_CLIENTSECRET="$( cat /run/secrets/bw_clientsecret )" \
    && export BW_CLIENTSECRET \
    && BW_ORGUUID="${BW_CLIENTID#organization.}" \
    && BW_DATAFILE="$( bwdc data-file 2>/dev/null )" \
    && bwdc --version \
    && bwdc login \
    && bwdc config directory 2 \
    && bwdc logout \
    && jq -r \
      --arg orgid "${BW_ORGUUID}" \
      --arg googleDomain "$GOOGLE_DOMAIN" \
      --arg googleAdminUserEmail "$GOOGLE_ADMIN_USER_EMAIL" \
      --arg googleCustomer "$GOOGLE_CUSTOMER" \
      --arg googleServiceUserEmail "$GOOGLE_SERVICE_USER_EMAIL" \
      --arg googleSyncUsers "$GOOGLE_SYNC_USERS" \
      --arg googleSyncUserFilter "$GOOGLE_SYNC_USER_FILTER" \
      --arg googleSyncGroups "$GOOGLE_SYNC_GROUPS" \
      --arg googleSyncGroupFilter "$GOOGLE_SYNC_GROUP_FILTER" \
      --arg googleSyncRemoveDisabled "$GOOGLE_SYNC_REMOVE_DISABLED" \
      --arg googleSyncOverwriteExisting "$GOOGLE_SYNC_OVERWRITE_EXISTING" \
      --arg googleSyncLargeImport "$GOOGLE_SYNC_LARGE_IMPORT" \
      --slurpfile googleSync "$WORKING_DIR"/sync.json \
       '.[$orgid].directoryConfigurations.gsuite.domain = $googleDomain \
       | .[$orgid].directoryConfigurations.gsuite.adminUser = $googleAdminUserEmail \
       | .[$orgid].directoryConfigurations.gsuite.clientEmail = $googleServiceUserEmail \
       | .[$orgid].directoryConfigurations.gsuite.customer = $googleCustomer \
       | .[$orgid].directorySettings.sync = $googleSync[0] \
       | .[$orgid].directorySettings.sync.users = $googleSyncUsers \
       | .[$orgid].directorySettings.sync.userFilter = $googleSyncUserFilter \
       | .[$orgid].directorySettings.sync.groups = $googleSyncGroups \
       | .[$orgid].directorySettings.sync.groupFilter = $googleSyncGroupFilter \
       | .[$orgid].directorySettings.sync.removeDisabled = $googleSyncRemoveDisabled \
       | .[$orgid].directorySettings.sync.overwriteExisting = $googleSyncOverwriteExisting \
       | .[$orgid].directorySettings.sync.largeImport = $googleSyncLargeImport' \
       "$BW_DATAFILE" > "$BW_DATAFILE".new \
    && cp "$BW_DATAFILE" "$BW_DATAFILE".old \
    && cp "$BW_DATAFILE".new "$BW_DATAFILE"