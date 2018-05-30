# Docker Compose configuration for the Virtual Language Observatory

This Docker Compose configuration combines a Solr server and a VLO web app instance. The 
latter image can also be used to run an import, and is used here to provision a *Solr home
directory* to the Solr server container.

See [VLO on GitHub](https://github.com/clarin-eric/VLO).

## Environment

A number of environment variables are required. The `.env-template` provides a template
for a `.env` with usable defaults. A symlink `clarin/.env` to `clarin/../../.env` 
is included (note that this is pointing out of the repository context, adhering to common
practice within the CLARIN central infrastructure). 

Therefore the following should get you started:

```sh
cp clarin/.env-template ../.env
```

You can then tweak or add the configuration depending for your specific environment and
needs. Make sure to **check for changes in the bundled template when upgrading**.

Note that some configuration overlays (see below) may need additional variables set.

## Configuration overlays

In addition to `docker-compose.yml`, a number of `.yml` files are present that can be
used as configuration overlays. They apply to different environments and/or usage
scenarios. To use them, provide both the 'base' configuration and the overlay as input
files to the `docker-compose` command. For example, a complete configuration ready to be
launched in _production_ can be started by executing:

```sh
docker-compose -f docker-compose.yml -f production.yml up
```

There are overlays for development, the beta and production environments and
environments that have a fluentd running on the host. Note that more than one overlay can
be applied if needed.

### Static metadata serving

A nginx based container for serving the metadata records as static content can be enabled
by including the `data.yml` overlay. The following environment variable has to be set
to the location of these files on disk in order to make this work:

* `HOST_METADATA_DIR`

The files will then become available (by default) at `http://localhost:8184/data/`.

See [.env-template](clarin/.env-template) for an example.

### JMX

JMX reporting of the Solr server can be enabled by including the `jmx.yml` overlay and
setting the following environment variables: 

* `JMXTRANS_HOST_ALIAS`
* `JMXTRANS_STATSD_HOST`
* `JMXTRANS_STATSD_PORT`

See [.env-template](clarin/.env-template) for details and examples.

### User satisfaction scores and CouchDB

To configure the VLO to gather user satisfaction scores via the web app, use the
`usersatisfaction.yml` overlay. This also defines a `vlo_couchdb` service for storing
the submitted ratings. Set the following environment variables to override the 
default behaviour:

* `VLO_DOCKER_RATING_SERVICE_NAME`
* `VLO_DOCKER_RATING_SHOW_PANEL_DELAY`
* `VLO_DOCKER_RATING_DISMISS_TIMEOUT`
* `VLO_DOCKER_RATING_SUBMIT_TIMEOUT`

Note that you can also connect to an **external CouchDB instance** instead by setting the 
following environment variables (and not using `usersatisfaction.yml`):

* `VLO_DOCKER_RATING_ENABLED=true`
* `VLO_DOCKER_RATING_COUCHDB_URL`
* `VLO_DOCKER_RATING_COUCHDB_USER`
* `VLO_DOCKER_RATING_COUCHDB_PASSWORD`

See [.env-template](clarin/.env-template) for configuration details and examples.

## Usage

### Control script

For convenience, a script ([control.sh](./control.sh)) has been included that make it easy
to run  docker-compose commands for specific environments. 

For example:

```sh
./control.sh beta up -d
```

will do two things:

0. The current hostname is verified against the expected hostname for the specified 
environment, in this case `beta` (note that for some "environments" this is omitted)
0. the `up -d` command is issued to docker-compose with the appropriate configuration
overlays applied (which ones depend on the environment)

Note that in the examples below the variable `$MY_ENV` is used as a placeholder for the
environment id.

### Run with sample data

To run the VLO with some [sample data](https://gitlab.com/CLARIN-ERIC/docker-vlo-sample-data)
without the need to configure anything, run the following in the `clarin` directory:

```sh
./control.sh $MY_ENV -f sample-data.yml up [-d]
```

Then connect to [localhost:8181](http://localhost:8181) to visit your local VLO instance.

Make sure to use the following command to bring the services down again:

```sh
./control.sh $MY_ENV -f sample-data.yml down [-v]
```

### Run the importer to ingest CMDI metadata into the VLO

Set the following **environment variables** or a version thereof that applies to your
environment:

- `METADATA_DIR=/srv/vlo-data`
- `VLO_DOCKER_DATAROOTS_FILE=/opt/vlo/config/my-dataroots.xml`

Assuming the following **mounts**:
- `/my/local/vlo-data` -> `/srv/vlo-data`
- `/my/local/vlo/config` -> `/opt/vlo/config`

The latter contains your custom dataroots definition pointing to the dataroots in 
aforementioned metadata directory. You can also use one of the [bundled data root
definitions](https://github.com/clarin-eric/VLO/tree/master/vlo-commons/src/main/resources),
in which case you don't have to mount a configuration overlay - only data. For example,
you can set:

- `VLO_DOCKER_DATAROOTS_FILE=dataroots-production.xml`

to use
[dataroots-production.xml](https://github.com/clarin-eric/VLO/blob/master/vlo-commons/src/main/resources/dataroots-production.xml).
Make sure that the paths match your data mount!

After having started the services, you can start the import by running:

```sh
./control.sh $MY_ENV exec vlo_web /opt/importer.sh
```

### Solr configuration initialisation

The configuration uses a shared volume (`solr-home-provisioning`) to provision the Solr
container with the VLO specific configuration (i.e. the contents of the `SOLR_HOME`
directory). As the content of this volume only gets initialised if the volume is empty,
it is **necessary to erase this volume before starting the services** (unless the version
of the VLO and therefore the bundled Solr configuration has not changed). Unfortunately
this cannot be automated through docker-compose; instead, run the following command:

```sh
docker volume rm ${PROJECT}_solr-home-provisioning
```

`${PROJECT}` defaults to `clarin`.
Depending on the environment, the volume may have a different name or prefix. 
Note that this will **NOT** remove any indexed data assuming that separate `SOLR_DATA_HOME`
location is configured.

### Export Solr data

```sh
HOST_EXPORT_TARGET=/my/solr/data
./control.sh $MY_ENV stop
./control.sh $MY_ENV run -v $HOST_EXPORT_TARGET:/solr-export -e SOLR_DATA_EXPORT_TARGET=/solr-export vlo_solr
```

This will copy the container's `SOLR_DATA_HOME` content to the specified target directory
on the host, and then terminate, i.e. doing this will *not start Solr*.

### Provide (import) existing Solr data

You can provision the Solr image with existing data (in the form as it can be exported
by following the instructions above) by mounting this data directory to
`/docker-entrypoint-initsolr.d/solr_data` 

```sh
HOST_DATA_DIR=/my/solr/data
./control.sh $MY_ENV down -v # This removes all data!
./control.sh $MY_ENV -v $HOST_DATA_DIR:/docker-entrypoint-initsolr.d/solr_data vlo_solr
```

This will copy the content of the specified source directory to the `SOLR_DATA_HOME`
directory of the container before starting Solr.

You can provide you own alternative Solr _configuration_ in a similar way by mounting
valid 'Solr home' content to `/docker-entrypoint-initsolr.d/solr_home`. This approach is
used by default to provision the Solr image with Solr home content from the VLO image;
normally you should not have to deviate from this.
