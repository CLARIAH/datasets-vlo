# Upgrade instructions

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
