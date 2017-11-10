# Docker Compose configuration for the Virtual Language Observatory

This Docker Compose configuration combines a Solr server and a VLO web app instance. The 
latter image can also be used to run an import, and is used here to provision a *Solr home
directory* to the Solr server container.

See [VLO on GitHub](https://github.com/clarin-eric/VLO).

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

## Usage

### Import metadata into the VLO

Set the following **environment variables** or a version thereof that appies to your
environment:

- `METADATA_DIR=/srv/vlo-data`
- `VLO_DOCKER_DATAROOTS_FILE=/opt/vlo/config/my-dataroots.xml`

Assuming the following **mounts**:
- `/my/local/vlo-data` -> `/srv/vlo-data`
- `/my/local/vlo/config` -> `/opt/vlo/config`

The latter contains your custom dataroots definition pointing to the dataroots in 
aforementioned metadata directory.

Then run:

```sh
docker-compose exec vlo_web /opt/importer.sh
```

### Export Solr data

```sh
HOST_EXPORT_TARGET=/my/solr/data
docker-compose down
docker-compose run -v $HOST_EXPORT_TARGET:/solr-export -e SOLR_DATA_EXPORT_TARGET=/solr-export vlo_solr
```

This will copy the container's `SOLR_DATA_HOME` content to the specified target directory
on the host, and then start the Solr server normally.

### Provide existing Solr data

You can provision the Solr image with existing data by mounting it to 
`/docker-entrypoint-initsolr.d/solr_data` 

```sh
HOST_DATA_DIR=/my/solr/data
docker-compose down -v
docker-compose run -v $HOST_DATA_DIR:/docker-entrypoint-initsolr.d/solr_data vlo_solr
```

This will copy the content of the specified source directory to the `SOLR_DATA_HOME`
directory of the container before starting Solr.

You can provide you own alternative Solr _configuration_ in a similar way by mounting
valid 'Solr home' content to `/docker-entrypoint-initsolr.d/solr_home`. This approach is
used by default to provision the Solr image with Solr home content from the VLO image;
normally you should not have to deviate from this.
