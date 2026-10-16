# Containerized Pulsar for Galaxy development

Connects a Galaxy checkout you already run to a Pulsar in Docker that cannot see Galaxy's object store, as if Pulsar ran on another machine. Made to test `remote_metadata: true` with `metadata_strategy: extended` on Pulsar (`job_conf.yml`, REST runner).

The Pulsar token (`dev-token`) is a local placeholder; Pulsar listens on localhost only.

## 1. Start Pulsar

```
docker build -t pulsar-dev pulsar/
docker run -d --name pulsar-dev -p 127.0.0.1:8913:8913 \
    -v /path/to/galaxy:/galaxy:ro -v pulsar-dev-venv:/venv-galaxy pulsar-dev
docker logs -f pulsar-dev
```

The checkout is mounted read-only as `galaxy_home`, for the remote metadata step. The first start builds a venv from the checkout's `pinned-requirements.txt`. Mount it at `/galaxy`, not at its own path, so Galaxy's object store path does not exist in the container.

## 2. Point Galaxy at it

From the checkout, without changing its config:

```
GALAXY_CONFIG_JOB_CONFIG_FILE=/path/to/this/repo/job_conf.yml \
GALAXY_CONFIG_METADATA_STRATEGY=extended \
GALAXY_CONFIG_OBJECT_STORE_STORE_BY=uuid \
./run.sh
```

Uploads run on the local runner, everything else on Pulsar. `object_store_store_by: uuid` is required by extended metadata; on an existing database with datasets stored by id, use a fresh `database/` instead.

## 3. Submit a job

Upload a small text file and run "Concatenate datasets" on it. Take the output's UUID from its dataset details, then from the checkout:

```
find database/objects -name "dataset_<uuid>.dat" -exec ls -l {} \;
docker exec pulsar-dev find / -xdev -name "dataset_<uuid>.dat" -exec ls -l {} \;
```

## Result

```
$ find database/objects -name "dataset_03d0df09-144c-464c-af93-9d1738c9367c.dat" -exec ls -l {} \;
-rw-r--r--. 1 rocky rocky 0 Oct 16 18:29 database/objects/0/3/d/dataset_03d0df09-144c-464c-af93-9d1738c9367c.dat
$ docker exec pulsar-dev find / -xdev -name "dataset_03d0df09-144c-464c-af93-9d1738c9367c.dat" -exec ls -l {} \;
-rw-r--r--. 1 root root 12 Oct 16 16:29 /path/to/galaxy/database/objects/0/3/d/dataset_03d0df09-144c-464c-af93-9d1738c9367c.dat
```

On Galaxy `dev` at 5bf7abf5e3 and on galaxyproject/galaxy#23986 at 9f067a0767, with Pulsar 0.15.16, the job and dataset are `ok` with the right size, but the file in `database/objects` is 0 bytes and the output is inside the container, at Galaxy's object store path. The remote metadata step writes outputs to the object store from the Pulsar side. Downloading the dataset fails with `h11._util.LocalProtocolError: Too little data for declared Content-Length`.

## After changing code

Restart Galaxy and `docker restart pulsar-dev`; the checkout is mounted, so no rebuild. After changing Galaxy's dependencies: `docker rm -f pulsar-dev && docker volume rm pulsar-dev-venv`, then start it again.
