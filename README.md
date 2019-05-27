# Docker Compose configuration for the Virtual Language Observatory

This Docker Compose configuration combines a Solr server and a VLO web app instance. The 
latter image can also be used to run an import, and is used here to provision a *Solr home
directory* to the Solr server container.

See [VLO on GitHub](https://github.com/clarin-eric/VLO).

## Using the compose project

{TODO: Use general CLARIN control.sh script, see "Running the VLO"}

### Environment

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

### Configuration overlays

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

#### Nginx for proxying and static metadata serving

A nginx based container can be enabled by including the `nginx.yml` overlay that serves
a number of purposes:

1. Proxying the VLO front end, including caching, compression and a number of redirects
to support requests on legacy URLs; certain parts, specifically all paths under `/config`
are protected via basic authentication through the proxy.
1. Proxying Solr
1. Serving the metadata records, result sets, sitemap and optionally some additional
static root content

A number of `TOMCAT_PROXY_*` variables have to be configured, but in most cases the
values from the `.env-template` file can be kept. The served content is taken from
several volumes, governed by the variables `METADATA_VOLUME`, `RESULTSETS_VOLUME`,
`SITEMAP_VOLUME` and `WEB_STATIC_DATA_VOLUME`.

Set the `PROXY_VLO_CONFIG_HTPASSWD_FILE` variable to specify the location of a
`htpassword` file to be used to protected the `/config/` path of the web app. See the
[nginx configuration](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/)
for instructions on how to create such a file.

{TODO: Alternatively expose Tomcat and Solr without proxy}

#### JMX

JMX reporting of the Solr server to a Statsd server can be enabled by including the 
`jmxtrans.yml` overlay and setting the following environment variables: 

* `JMXTRANS_HOST_ALIAS`
* `JMXTRANS_STATSD_HOST`
* `JMXTRANS_STATSD_PORT`

See [.env-template](clarin/.env-template) for details and examples.

#### User satisfaction scores

To configure the VLO to gather user satisfaction scores via the web app, use the
`mopinion.yml` overlay. This will cause a snippet to be included at the end of every
rendered page that enables a feedback panel defined and controlled via 
[Mopinion](https://app.mopinion.com).

The following variables have to be set for this to work:

* `BOTTOM_SNIPPETS_DIR`
* `BOTTOM_SNIPPET_FILE`

Be aware that, if adopting the `.env` template, the snippets directory is host-mounted
into the container from a directory within the compose project.

### Running the VLO

#### Control script

{TODO Common script https://gitlab.com/CLARIN-ERIC/control-script/. Directory structure }
For convenience, a script ([control.sh](./control.sh)) has been included that make it easy
to run common operations:

```sh
./control.sh [start|stop|restart|run-import|backup|restore|status] [-hd]
```
{TODO Add retrieve mongo db, update link checker info subcommands}

Run `./control.sh -h` to get a more detailed description of all the options.

Additional configuration overlays (see above) will be loaded according to the list in
a file `.compose-overlays` in the control script directory if present. See
the bundled template file [.compose-overlays-template](./.compose-overlays-template)
for more information.

In most cases you will want to enable either the `nginx` overlay or the `expose-tomcat`
overlay, otherwise the VLO web app will not be exposed to the host.

#### Run with sample data

To run the VLO with some [sample data](https://gitlab.com/CLARIN-ERIC/docker-vlo-sample-data)
without the need to configure anything, include `sample-data.yml` in your overlay file
(see above) or run the following in the `clarin` directory:

```sh
docker-compose -f docker-compose.yml -f expose-tomcat.yml -f sample-data.yml up [-d]
```

Then connect to [localhost:8181](http://localhost:8181) to visit your local VLO instance.

Make sure to use the following command to bring the services down again:

```sh
docker-compose -f docker-compose.yml -f expose-tomcat.yml -f sample-data.yml down [-v]
```

#### Run the importer to ingest CMDI metadata into the VLO

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
./control.sh run-import
```

#### Solr configuration initialisation

The configuration uses a shared volume (`solr-home-provisioning`) to provision the Solr
container with the VLO specific configuration (i.e. the contents of the `SOLR_HOME`
directory). As the content of this volume only gets initialised if the volume is empty,
it is **necessary to erase this volume before starting the services** (unless the version
of the VLO and therefore the bundled Solr configuration has not changed). Unfortunately
this cannot be automated through docker-compose; instead, run the following command:

```sh
docker volume rm ${COMPOSE_PROJECT_NAME}_solr-home-provisioning
```

`${COMPOSE_PROJECT_NAME}` defaults to `vlo`.
Depending on the environment, the volume may have a different name or prefix. 
Note that this will **NOT** remove any indexed data assuming that separate `SOLR_DATA_HOME`
location is configured.

#### Export Solr data

```sh
HOST_EXPORT_TARGET=/my/solr/data
./control.sh stop
(cd clarin && docker-compose run -v $HOST_EXPORT_TARGET:/solr-export -e SOLR_DATA_EXPORT_TARGET=/solr-export vlo-solr)
```

This will copy the container's `SOLR_DATA_HOME` content to the specified target directory
on the host, and then terminate, i.e. doing this will *not start Solr*.

#### Provide (import) existing Solr data

You can provision the Solr image with existing data (in the form as it can be exported
by following the instructions above) by mounting this data directory to
`/docker-entrypoint-initsolr.d/solr_data` 

```sh
HOST_DATA_DIR=/my/solr/data
docker-compose down -v # This removes all data!
docker-compose run -v $HOST_DATA_DIR:/docker-entrypoint-initsolr.d/solr_data vlo-solr
```

This will copy the content of the specified source directory to the `SOLR_DATA_HOME`
directory of the container before starting Solr.

You can provide you own alternative Solr _configuration_ in a similar way by mounting
valid 'Solr home' content to `/docker-entrypoint-initsolr.d/solr_home`. This approach is
used by default to provision the Solr image with Solr home content from the VLO image;
normally you should not have to deviate from this.
