# Pulsar without shared storage, for Galaxy development

Galaxy runs from a checkout on the host. Pulsar runs in a container that sees the checkout (read-only, as `galaxy_home`) but not Galaxy's object store, like a Pulsar on another machine. Destination: REST, `remote_metadata: true`, `metadata_strategy: extended` (`galaxy/job_conf.yml`).

The tokens and passwords (`dev-token`, `dev-admin-key`, `devpassword`) are local placeholders; both services listen on localhost only.

Needs Docker, `jq`, and a Galaxy checkout with its venv (`./scripts/common_startup.sh --skip-client-build`).

```
export GALAXY_ROOT=/path/to/galaxy          # checkout to test
export REPRO=$PWD                           # this directory
sed -e "s#@REPRO@#$REPRO#g" -e "s#@GALAXY_ROOT@#$GALAXY_ROOT#g" galaxy/galaxy.yml.in > galaxy/galaxy.yml

docker build -t pulsar-dev pulsar/
docker run -d --name pulsar-dev -p 127.0.0.1:8913:8913 \
    -v "$GALAXY_ROOT":/galaxy:ro -v pulsar-dev-venv:/venv-galaxy pulsar-dev
docker logs -f pulsar-dev                   # first start builds /venv-galaxy, then serves on 8913

(cd "$GALAXY_ROOT" && GALAXY_CONFIG_FILE=$REPRO/galaxy/galaxy.yml GALAXY_SKIP_CLIENT_BUILD=1 ./run.sh)

./test-plain.sh
```

`test-plain.sh` uploads a text file (local runner), runs `cat1` on Pulsar and prints the output's size in Galaxy, the file in Galaxy's object store, and any copy in the container.

For Crypt4GH-protected jobs (galaxyproject/galaxy#23986), also set `crypt4gh_enabled: true` in `galaxy/galaxy.yml.in`.

## Result

Reproduces on Galaxy `dev` at 5bf7abf5e3 and on galaxyproject/galaxy#23986 at 9f067a0767, Pulsar 0.15.16:

```
cat1 (pulsar): ok
Galaxy says: state=ok file_size=27 uuid=2436a752-...
Galaxy object store: .../galaxy-data/objects/2/4/3/dataset_2436a752-....dat (0 bytes)
Pulsar container:
-rw-r--r--. 1 root root 27 ... .../galaxy-data/objects/2/4/3/dataset_2436a752-....dat
```

The job and dataset are `ok` with the right size, but the file in Galaxy's object store is empty: the remote metadata step wrote the output to the object store path inside the container. Downloading the dataset then fails with `h11._util.LocalProtocolError: Too little data for declared Content-Length`.

After changing Galaxy code: restart Galaxy, and `docker restart pulsar-dev` (the checkout is mounted, so no rebuild). After changing Galaxy's dependencies: `docker volume rm pulsar-dev-venv` and recreate the container.
