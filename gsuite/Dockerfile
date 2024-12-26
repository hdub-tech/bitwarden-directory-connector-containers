ARG BWDC_VERSION=2024.10.0
FROM hdub-tech-bwdc-base:$BWDC_VERSION

# User
ARG BWUSER=bitwarden
ARG BWUID=1000
USER $BWUSER

# Configurable arguments
ARG GOOGLE_DOMAIN
ARG GOOGLE_ADMIN_USER_EMAIL
ARG GOOGLE_CUSTOMER=""
ARG GOOGLE_SERVICE_USER_EMAIL

# Update the bwdc data-file
RUN --mount=type=secret,id=bw_orguuid,uid=$BWUID \
    --mount=type=secret,id=bw_key,uid=$BWUID \
    BW_ORGUUID="$( cat /run/secrets/bw_orguuid )" \
    && GOOGLE_PRIVATE_KEY="$( cat /run/secrets/bw_key )" \
    && BW_DATAFILE="$( bwdc data-file 2>/dev/null )" \
    && jq -r \
      --arg orgid "${BW_ORGUUID}" \
      --arg googleDomain "$GOOGLE_DOMAIN" \
      --arg googleAdminUserEmail "$GOOGLE_ADMIN_USER_EMAIL" \
      --arg googleCustomer "$GOOGLE_CUSTOMER" \
      --arg googleServiceUserEmail "$GOOGLE_SERVICE_USER_EMAIL" \
      --arg googlePrivateKey "${GOOGLE_PRIVATE_KEY}" \
      '.[$orgid].directorySettings.directoryType = 2 \
       | .[$orgid].directorySettings.organizationId = $orgid \
       | .[$orgid].directoryConfigurations.gsuite.domain = $googleDomain \
       | .[$orgid].directoryConfigurations.gsuite.adminUser = $googleAdminUserEmail \
       | .[$orgid].directoryConfigurations.gsuite.clientEmail = $googleServiceUserEmail \
       | .[$orgid].directoryConfigurations.gsuite.customer = $googleCustomer \
       | .[$orgid].directoryConfigurations.gsuite.privateKey = $googlePrivateKey' \
       "$BW_DATAFILE" > "$BW_DATAFILE".new \
    && cp "$BW_DATAFILE" "$BW_DATAFILE".old \
    && cp "$BW_DATAFILE".new "$BW_DATAFILE"
