# Upgrade instructions

## vlo-4.10.2 to vlo-4.10.3
Maintenance release, no configuration changes required.

## vlo-4.10.1 to vlo-4.10.2

Maintenance release that addresses the log4shell vulnerabilities (CVE-2021-44228 and
CVE-2021-45046). No configuration changes required.


## vlo-4.10.0 to vlo-4.10.1

- New env variables:
  - `LINK_CHECKER_DB_POOL_SIZE`
  - `LINK_CHECKER_MAX_DAY_SINCE_CHECKED`

See `.env-template` for a brief description of these variables. All of these can be
left to their defaults by not setting them explicitly.

For a standard deployment, add the following to `.env`:

```
## Number of connections to keep in the link checker DB pool for the VLO import
LINK_CHECKER_DB_POOL_SIZE=20

## Threshold age for link checker information
LINK_CHECKER_MAX_DAY_SINCE_CHECKED=100
```

## vlo-4.9.* to vlo-4.10.0

- New env variables:
  - `VLO_DOCKER_LRS_POPUP_ENABLED`
  - `VLO_DOCKER_MONITOR_RULES_FILE_DIR`
  - `VLO_DOCKER_MONITOR_RULES_FILE_NAME`
  - `VLO_DOCKER_MONITOR_RULES_DIR_CONTAINER`
  - `VLO_DOCKER_MONITOR_DB_PATH`
  - `VLO_DOCKER_MONITOR_PRUNE_AFTER_DAYS`
  - `VLO_MONITORING_DATA_VOLUME`
  - `VLO_DOCKER_MONITOR_DB_PATH`

See `.env-template` for a brief description of these variables. All of these can be
left to their defaults by not setting them explicitly.

## vlo-4.9.2 to vlo-4.9.3

The changes in this version apply to the joint deployment of the VLO, harvester and the
curation dashboard/link checker project. To this end, there are two major changes:

- In the default situation, the link checker database is now directly accessible and
the logic and configuration to run a local instance based restored from a dump has been
removed. An external network `network_linkchecker` has been introduced.
- The default metadata volume has been changed into an external volume named `vlo-data`
that can easily and reliably be shared with the curation dashboard and the harvester

Configuration changes:
- IFF using `linkchecker.yml`, review and set the following variable in `.env`:
  - `LINK_CHECKER_HOST_PORT=curation_mysql_1:3306` (note that the exact name of the
  container and port of the database service can be different depending on the
  environment)
  - `LINK_CHECKER_DB_NAME` (align with curation module configuration)
  - `LINK_CHECKER_DB_USER` (align with curation module configuration)
  - `LINK_CHECKER_DB_PASSWORD` (align with curation module configuration)
- Remove or comment out the following variables in `.env`
  - `LINK_CHECKER_DB_ROOT_PASSWD`
  - `LINK_CHECKER_DUMP_URL`
  - `LINK_CHECKER_DUMP_HOST_DIR`
  - `LINK_CHECKER_DUMP_CONTAINER_DIR`
  - `LINK_CHECKER_PRUNE_AGE`
  - `LINK_CHECKER_DEBUG`

## vlo-4.9.1 to vlo-4.9.2

Maintenance release. No changes to the configuration of the VLO are required,
but the resource availability status API requires an updated link checker database
schema. Make sure to restore a recent database before running the import or the
link status update process.

## vlo-4.9.0 to vlo-4.9.1

Maintenance release. The following env variables have changed default values:

- `VLO_DOCKER_VCR_MAXIMUM_ITEMS_COUNT=100`
- `VLO_DOCKER_VCR_SUBMIT_ENDPOINT=https://collections.clarin.eu/submit/extensional`

Advice is to adopt these values.

## vlo-4.8.* to vlo-4.9.0

- Deprecated env variables:
  - `OTHER_PROVIDERS_MARKUP_FILE`
- New env variables:
  - `OTHER_PROVIDERS_MARKUP_DIR=./providers`
  - `OTHER_PROVIDERS_MARKUP_FILENAME=others.html`
  - `VLO_DOCKER_WEB_APP_LOCALE=en-GB`
  - `VLO_DOCKER_DATASET_STRUCTURED_DATA_ENABLED=true`
  - `VLO_DOCKER_LRS_POPUP_SCRIPT_URL=https://switchboard.clarin.eu/popup/switchboardpopup.js`
  - `VLO_DOCKER_LRS_POPUP_STYLE_URL=https://switchboard.clarin.eu/popup/switchboardpopup.css`

You can copy the directory `clarin/providers` to a location outside the compose project
and adapt the new `OTHER_PROVIDERS_MARKUP_DIR` variable accordingly to allow for
on-the-fly adaptations to the "Other contributors" list in the VLO web app
(see <https://vlo.clarin.eu/contributors>).

## vlo-4.8.* to vlo-4.8.2

- New overlays:
  - `linkchecker`
- Removed overlays:
  - `mongo`
- New env variables:
  - `VLO_DOCKER_ENABLE_FCS_LINKS`,`LINK_CHECKER_DB_ROOT_PASSWD`,`LINK_CHECKER_DB_NAME`,`
  LINK_CHECKER_DB_USER`,`LINK_CHECKER_DB_PASSWORD`,`LINK_CHECKER_DUMP_URL`,`
  LINK_CHECKER_DUMP_HOST_DIR`,`LINK_CHECKER_DUMP_CONTAINER_DIR`,`LINK_CHECKER_PRUNE_AGE`,`
  LINK_CHECKER_DEBUG`,`LINK_CHECKER_HOST_PORT`
  
To use the new MariaDB based link checker database, replace the 'mongo' overlay with
the 'linkchecker' overlay and add a number of .env variables:

```sh
DEPLOY_DIR="/home/deploy/vlo"
LINKCHECKER_DUMPS_DIR="${DEPLOY_DIR}/linkchecker_dumps"
mkdir -p "${LINKCHECKER_DUMPS_DIR}" && 
echo "
VLO_DOCKER_ENABLE_FCS_LINKS=false

LINK_CHECKER_DB_ROOT_PASSWD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
LINK_CHECKER_DB_NAME=linkchecker
LINK_CHECKER_DB_USER=linkchecker
LINK_CHECKER_DB_PASSWORD=linkchecker

LINK_CHECKER_DUMP_URL=https://curate.acdh.oeaw.ac.at/mysqlDump.gz
LINK_CHECKER_DUMP_HOST_DIR=${LINKCHECKER_DUMPS_DIR}
LINK_CHECKER_DUMP_CONTAINER_DIR=/data/dump
LINK_CHECKER_PRUNE_AGE=100
LINK_CHECKER_DEBUG=false

#Don't change this if you want to use the service configured in linkchecker.yml
LINK_CHECKER_HOST_PORT=vlo-linkchecker-db:3306
" >> "${DEPLOY_DIR}/.env"
```

## vlo-4.7.* to vlo-4.8.0-*

- New overlays:
  - `exposure`
  - `exposure-frontend`

These should be added to ``.overlays` for production to enable exposure statistics 
gathering. Furthermore, the following .env variables need to be added:

```
# Solr init script (absolute path or else relative to compose_vlo/clarin directory)
SOLR_INIT_SCRIPT=./solr/solr.in.sh

## --- Set the following if you are using exposure statistics gathering ---
VLO_DOCKER_EXPOSURE_DB_PASSWORD=vlo_exposure

## --- Set the following if you want to enable the exposure statistics front end ---
## Basic auth password file - location relative to compose_vlo/clarin directory
## initialise with e.g. htpasswd -n -B user1 > exposure-frontend/htpasswd
VLO_EXPOSURE_FRONTEND_PASSWORD_FILE=../../exposure-frontend/htpasswd
```

Finally initialise a file `exposure-frontend/htpasswd` (relative to the parent directory
of the compose project) in the following way:

```sh
mkdir -p ${DEPLOY_HOME}/vlo/exposure-frontend
htpasswd -n -B ${USERNAME} >> ${DEPLOY_HOME}/vlo/exposure-frontend/htpasswd 
# manually enter password on the CLI
```

and repeat for every user that should get access to the exposure statistics front end
(or ask users to provide their own password hash this way and append).

Note that for this release you will also need to drop the Solr database and run a fresh
import:

```sh
cd ${DEPLOY_HOME}
./control.sh vlo drop-solr-data
#manually confirm
./control.sh vlo restart
./control.sh vlo run-import
```

## vlo-4.7.1-1 to vlo-4.7.2-1

- New mandatory .env variable:

```
VLO_DOCKER_AVAILABILITY_STATUS_UPDATE_BATCH_SIZE=25
```

## 1.8.0 to vlo-4.7.1-1

Note that the version scheme has changed as of this release. Apart from that it's a
maintenance release compared to 1.8.0. No configuration changes are needed. There are
some new control.sh subcommands to be aware of:

```
restart-web-app           Restart VLO web app (no container recreate) 
restart-solr              Restart VLO Solr instance (no container recreate) 
restart-proxy             Restart nginx proxy service (no container recreate) 
restart-mongo             Restart mongo linkchecker database (no container recreate) 
restart-jmxtrans          Restart jmxtrans (no container recreate) 
drop-solr-data [-f]       Drop the VLO Solr index (requires confirmation unless -f is provided)
```

Please also update the VLO/harvester orchestration scripts if you are using them. 
See https://gitlab.com/CLARIN-ERIC/vlo-harvesting-orchestration/.

## 1.7.0 to 1.80

- New overlays:

```
#For a local link checker database (see new .env variables)
mongo
```

- New .env variables:

```
### Mandatory settings for the new contributions page
# Connection to centre registry
VLO_DOCKER_CENTRE_REGISTRY_CENTRES_LIST_JSON_URL=https://centres.clarin.eu/api/model/Centre
VLO_DOCKER_CENTRE_REGISTRY_OAI_PMH_ENDPOINTS_LIST_JSON_URL=https://centres.clarin.eu/api/model/OAIPMHEndpoint
# Custom markup for list of other providers (bundled with compose project or change to customise)
OTHER_PROVIDERS_MARKUP_FILE=./providers/others.html

### Optional settings. Uncomment and/or tweak to enable link checker integration
# VLO_LINK_CHECKER_MONGO_DB_NAME=curateLinkTest
# VLO_LINK_CHECKER_MONGO_MEM_LIMIT=4g
# VLO_LINK_CHECKER_DUMP_URL=https://curate.acdh-dev.oeaw.ac.at/mongoDump.gz
# VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR=/home/deploy/vlo/linkchecker_dump
# VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR=/data/dump
# VLO_LINK_CHECKER_PRUNE_AGE=100
# VLO_LINK_CHECKER_DEBUG=false
```

- Link checker integration:
  * Enable the 'mongo' overlay
  * Enable (and optionally tweak) the VLO_LINK_CHECKER_* variables in the .env file
  * Retrieve the database by running `control.sh vlo update-linkchecker-db`
  * Schedule regular database retrieval via the same command
  * Import will communicate with the mongo database and incorporate link checker 
  information in the index
  * In between imports a utility can be executed to update only the link checker 
  information without carrying out a full import. This can be triggered with the
  `run-link-status-update` subcommand of the control script.

- A Solr index created with a previous version of the VLO is not compatible. Remove the
vlo_vlo-solr-data (or possibly different depending on the project name) volume and run a
new import; note that this may take up to several hours depending on the volume of the
imported data.

## 1.6.3 to 1.7.0
- If using the proxy (i.e. in production), an htpasswd file has to be created for
protecting the new `/config` location. This can also be empty to not allow any access.
This file should be placed in a host location defined in the
`PROXY_VLO_CONFIG_HTPASSWD_FILE` variable. You can create a file with one or more users 
by doing:

```
(cd ./clarin && htpasswd -n ${USERNAME} >> ../../vlo-config-htpasswd)
```

and entering the
password for `${USERNAME}` twice, assuming that the templated location of 
`PROXY_VLO_CONFIG_HTPASSWD_FILE` is kept.

- A Solr index created with a previous version of the VLO is not compatible. Remove the
vlo_vlo-solr-data (or possibly different depending on the project name) volume and run a
new import; note that this may take up to several hours depending on the volume of the
imported data. You can also remove the content from an existing volume and replace it
with content from a volume that was populated by a compatible version (>=4.6.0-beta1) of
the VLO importer.

- The solr endpoint now is being proxied via vlo-proxy (at `/solr`). Most likely you
can disable the 'expose-solr' overlay if currently enabled.

- Page and app title can be customised by setting the following variables in `.env`:
  - `VLO_APPLICATION_TITLE=Virtual Language Observatory`
  - `VLO_PAGE_TITLE=CLARIN VLO`

## 1.6.2 to 1.6.3
- The following environment variables have been added (listed here with default values
that can be adopted):
  - `NGINX_PROXY_HTTP_PORT=8181`
  - `NGINX_PROXY_HTTPS_PORT=8143`
  - `BOTTOM_SNIPPETS_DIR=./vlo-web/snippets`
  - `BOTTOM_SNIPPET_FILE=bottomsnippets-mopinion.html`

## 1.6.1 to 1.6.2
- The following environment variables have been added (listed here with default values
that can be adopted):

  - `VLO_DOCKER_VCR_MAXIMUM_ITEMS_COUNT=1000`
  - `VLO_DOCKER_CONCEPT_REGISTRY_URL=https://concepts.clarin.eu/ccr/api/find-concepts`
  - `VLO_DOCKER_VOCABULARY_REGISTRY_URL=http://clavas.clarin.eu/clavas/public/api/find-concepts`
  - `VLO_DOCKER_FEEDBACK_FORM_URL=http://www.clarin.eu/node/3759?url=`
  - `VLO_DOCKER_FCS_BASE_URL=https://spraakbanken.gu.se/ws/fcs/2.0/aggregator/`
  - `VLO_DOCKER_LRS_BASE_URL=https://switchboard.clarin.eu/`
  - `VLO_DOCKER_VCR_SUBMIT_ENDPOINT=https://clarin.ids-mannheim.de/vcr/service/submit`

- The overlay `switchboard-url-fix.yml` that was introduced in 1.6.1c is no longer
included. Remove it from your deployment's `.compose-overlay` file if applicable.

## 1.6.0 to >= 1.6.1
- The project name has changed from `clarin` (default through directory name) to `vlo`.
Adapt existing volume names accordingly:

`clarin_solr-home-provisioning` -> `vlo_solr-home-provisioning`
`clarin_vlo-solr-data` -> `vlo_vlo-solr-data`
`clarin_vlo-statsd` -> `vlo_vlo-statsd`
`clarin_vlo-sitemap` -> `vlo_vlo-sitemap`
`clarin_vlo-data` -> `vlo_vlo-data`
`clarin_vlo-resultsets` -> `vlo_vlo-resultsets`

- Nearly all variables defined in the environment specific .yml files have been migrated
to the .env (template) file. Suggested procedure is to adopt the template file, and
apply (or append) all values from the old .yml file (see
<https://gitlab.com/CLARIN-ERIC/compose_vlo/compare/master...release-1.6.0>) and then
all values and/or additional variables defined in the old .env file.
