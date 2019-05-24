# Upgrade instructions

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
