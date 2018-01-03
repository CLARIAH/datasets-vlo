# Docker Compose configuration for the Virtual Language Observatory

This Docker Compose configuration combines a Solr server and a VLO web app instance. The 
latter image can also be used to run an import, and is used here to provision a *Solr home
directory* to the Solr server container.

See [VLO on GitHub](https://github.com/clarin-eric/VLO).

## Environment

A number of environment variables are required. The `.env-template` provides a template
for a `.env` with usable defaults. Doing the following should get you started:

```sh
cp clarin/.env-template clarin/.env
```

Alternatively you may want to persist a modified version of the file somewhere else on
your host:

```sh
cp clarin/.env-template /my/configs/vlo/.env
ln -s /my/configs/vlo/.env clarin/.env
```

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

## Scripts

For convenience, a number of scripts have been added that make it easy to run 
docker-compose commands for specific environments. For example:

```sh
./docker-compose-production.sh up
```

will have the same results as issuing the previous example command.

## Solr configuration initialisation

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

## Usage

### Run with sample data

To run the VLO with some [sample data](https://gitlab.com/CLARIN-ERIC/docker-vlo-sample-data)
without the need to configure anything, run the following in the `clarin` directory:

```sh
docker-compose -f docker-compose.yml -f sample-data.yml up [-d]
```

Then connect to [localhost:8181](http://localhost:8181) to visit your local VLO instance.

Make sure to use the following command to bring the services down again:

```sh
docker-compose -f docker-compose.yml -f sample-data.yml down [-v]
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
docker-compose exec vlo_web /opt/importer.sh
```

### Export Solr data

```sh
HOST_EXPORT_TARGET=/my/solr/data
docker-compose stop
docker-compose run -v $HOST_EXPORT_TARGET:/solr-export -e SOLR_DATA_EXPORT_TARGET=/solr-export vlo_solr
```

This will copy the container's `SOLR_DATA_HOME` content to the specified target directory
on the host, and then terminate, i.e. doing this will *not start Solr*.

### Provide (import) existing Solr data

You can provision the Solr image with existing data (in the form as it can be exported
by following the instructions above) by mounting this data directory to
`/docker-entrypoint-initsolr.d/solr_data` 

```sh
HOST_DATA_DIR=/my/solr/data
docker-compose down -v # This removes all data!
docker-compose run -v $HOST_DATA_DIR:/docker-entrypoint-initsolr.d/solr_data vlo_solr
```

This will copy the content of the specified source directory to the `SOLR_DATA_HOME`
directory of the container before starting Solr.

You can provide you own alternative Solr _configuration_ in a similar way by mounting
valid 'Solr home' content to `/docker-entrypoint-initsolr.d/solr_home`. This approach is
used by default to provision the Solr image with Solr home content from the VLO image;
normally you should not have to deviate from this.
