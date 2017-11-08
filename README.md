# Compose configuration for the Virtual Language Observatory

This configuration combines a Solr server and a VLO web app instance. The latter image
can also be used to run an import, and contains an initialisation mechanism for the *Solr
home directory*, which is executed before the Server is started.

See [VLO on GitHub](https://github.com/clarin-eric/VLO).

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

### Import or export the VLO Solr index

Be aware that the importing will **overwrite the existing index**, so be **_CAREFUL_**!

To export:

```sh
docker-compose exec vlo_web /opt/solr-replication.sh --export my_backup
```

To import:

```sh
docker-compose exec vlo_web /opt/solr-replication.sh --import my_backup
```

Mount a volume to `/srv/vlo-solr-export` if you want to transfer the exported data to
another host.

