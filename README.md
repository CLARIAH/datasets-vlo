# Docker Compose configuration for the Virtual Language Observatory

This Docker Compose configuration combines a Solr server and a VLO web app instance. The 
latter image can also be used to run an import, and is used here to provision a *Solr home
directory* to the Solr server container.

See [VLO on GitHub](https://github.com/clarin-eric/VLO).

## Using the compose project

To use this project, you need to have Docker Compose installed as well as a compatible
version of the general CLARIN control script. More details are provided in the
[Running the VLO](#running-the-vlo) section of this document. The rest of this section
describes the steps necessary to configure the project before running the services
defined in this project.

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
scenarios. They can be used in two ways:

1. Directly with `docker-compose` by specifying them in addition
to the 'base' `docker-compose.yml` configuration
2. **Preferably**: in combination with the general CLARIN control script by including them 
uncommented in the `.overlays` file. See [control script documentation](https://gitlab.com/CLARIN-ERIC/control-script/) and 
[.overlays-tempate](./.overlays-template) file for more information. 

Note that the `.yml` file extension should be **excluded** when specifying overlays 
in the `.overlays` file whereas it must be included if running `docker-compose` manually.

#### Nginx for proxying and static metadata serving

A nginx based container can be enabled by including the `nginx` overlay that serves
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

#### Direct port mapping for the Tomcat and/or Solr services (no proxy)

This approach can be taken as an *alternative* to running the Nginx proxy (see above).
The two approaches cannot be combined without altering the port mappings. Doing the
following will map the internal ports of the Tomcat and/or Solr service to local ports:

* Disable the `nginx` overlay
* Enable the `expose-tomcat` overlay to make Tomcat available on port 8181
* And/or enable the `expose-solr` overlay to make the Solr server available on port 8183

Note that this cannot fully replace the nginx proxy as it does not serve the metadata
and other static content.

#### JMX

JMX reporting of the Solr server to a Statsd server can be enabled by including the 
`jmxtrans` overlay and setting the following environment variables: 

* `JMXTRANS_HOST_ALIAS`
* `JMXTRANS_STATSD_HOST`
* `JMXTRANS_STATSD_PORT`

See [.env-template](clarin/.env-template) for details and examples.

#### User satisfaction scores

To configure the VLO to gather user satisfaction scores via the web app, use the
`mopinion` overlay. This will cause a snippet to be included at the end of every
rendered page that enables a feedback panel defined and controlled via 
[Mopinion](https://app.mopinion.com).

The following variables have to be set for this to work:

* `BOTTOM_SNIPPETS_DIR`
* `BOTTOM_SNIPPET_FILE`

Be aware that, if adopting the `.env` template, the snippets directory is host-mounted
into the container from a directory within the compose project.

#### Link checker database

The VLO can access and process data gathered by the
[Curation Module](http://curate.acdh.oeaw.ac.at/)'s link checker during import. For this,
a Mongo database has to be accessible. Normally this is a local instance that gets
populated on basis of an import or replication. Enabling the `mongo` overlay will
include a service `vlo-linkchecker-mongo` and set up a connection from the VLO service.

The following environment variables need to be set:

* `VLO_LINK_CHECKER_MONGO_DB_NAME`
* `VLO_LINK_CHECKER_MONGO_MEM_LIMIT`
* `VLO_LINK_CHECKER_DUMP_URL`
* `VLO_LINK_CHECKER_MONGO_DUMP_HOST_DIR`
* `VLO_LINK_CHECKER_MONGO_DUMP_CONTAINER_DIR`
* `VLO_LINK_CHECKER_PRUNE_AGE`

See [.env-template](clarin/.env-template) for details and examples.

The control script provides a number of commands for managing the link checker database
and updating the Solr index on basis of its information (see below).

### Running the VLO

#### Control script

The VLO services defined in this project can be controlled with 
[CLARIN's common control script](https://gitlab.com/CLARIN-ERIC/control-script).
The script can easily be deployed and can be used immediately after setting up the
required directory structure:
```
 ├── control.sh -> control-script/control.sh   Symlink to control-script/control.sh
 ├── control-script/                           A clone or copy of the control-script project
 └── vlo/                                      Project directory
     ├── .env                                  Environment variables (initialise from compose_vlo/clarin/.env-template)
     ├── .overlays                             Enabled overlays (initialise from compose_vlo/.overlays-template)
     └── compose_vlo/                          A clone or copy of this project
```

Using the control script, it is easy to run common operations without manually calling
docker-compose:

```sh
./control.sh vlo -h
./control.sh [-v] vlo [start|stop|restart|status|logs]
./control.sh [-v] vlo [run-import|run-link-status-update|update-linkchecker-db]
./control.sh [-v] vlo [backup|restore]
./control.sh [-v] vlo exec <name> <command>
./control.sh [-v] vlo restart-[web-app|solr|proxy|mongo]
./control.sh [-v] vlo drop-solr-data
```

Run `./control.sh vlo -h` to get a more detailed description of all the options. Note that
the script checks the username against an expected the name of a predefined deploy
user. This can be overridden by setting the `DEPLOY_USER` environment variable:

```sh
DEPLOY_USER=$(whoami) ./control.sh <arguments>
```

More information can be found in the documentation at the
[control-script repository](https://gitlab.com/CLARIN-ERIC/control-script).

Additional configuration overlays (see above) will be loaded automatically according to 
the list in a file `.overlays` if present in the control script directory. See
the bundled template file [.overlays-template](./.overlays-template)
for more information.

In most cases you will want to enable either the `nginx` overlay or the `expose-tomcat`
overlay, otherwise the VLO web app will not be exposed to the host.

To start all enabled services, simply run

```sh
DEPLOY_USER=$(whoami) ./control.sh start
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

After having started the services, you can start the import by running the general
control script (see above):

```sh
./control.sh vlo run-import
```
