# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface
>where instructors and students alike can author, organize, view and print public-domain course material.


[![test status](https://github.com/harvard-lil/h2o/actions/workflows/tests.yml/badge.svg)](https://github.com/harvard-lil/h2o/actions)
[![codecov](https://codecov.io/gh/harvard-lil/h2o/branch/main/graph/badge.svg)](https://codecov.io/gh/harvard-lil/h2o)

## Development

We support local development with [Docker Compose](https://docs.docker.com/compose/).

### Hosts Setup

Add the following to `/etc/hosts`:

    127.0.0.1 opencasebook.test opencasebook.minio.test

### Spin up some containers

Start up the Docker containers in the background:

    $ docker compose up -d

The first time this runs it will build the Docker images, which
may take several minutes. (After the first time, it should only take
1-3 seconds.)

If the H2O team has provided you with a pg_dump file, seed the database with data:

    $ bash docker/init.sh -f ~/database.dump

Then log into the main Docker container:

    $ docker compose exec web bash

(Commands from here on out that start with `#` are being run in Docker.)

### Run Django

You should now have a working installation of H2O!

The images are built locally rather than pulled, so the first
`docker compose up -d` takes a few minutes. After that it is a fraction of a
second: Compose rebuilds only when something a build depends on has changed, so
pulling a colleague's dependency change is picked up automatically and there is
no flag to remember.

Spin up the development server (this also starts the frontend build, so run
`npm install` first if you have not already)...

    # invoke run

or, with [Django Debug Toolbar](https://django-debug-toolbar.readthedocs.io/en/latest/index.html#) enabled,

    # invoke run --debug-toolbar

...and visit http://opencasebook.test:8000

### Frontend assets

Frontend assets live in `frontend/` and are compiled with vue-cli.

`invoke run` starts the vue-cli dev server alongside Django, so edits under
`frontend/` are picked up without a restart. There is no separate
`invoke run-frontend` any more -- it is what `invoke run` does.

The compiled bundles (`static/dist/` and `webpack-stats.json`) are build output
and are **not** committed. You do not normally need to think about them: both
`invoke run` and `pytest` compile them when they are missing or out of date. To
build them by hand:

    # invoke build-frontend

Staleness is decided by hashing the build's inputs -- `frontend/`,
`static/images/`, and the npm and vue configs -- against the hash recorded when
the bundles were last built, so pulling someone else's frontend change triggers
a rebuild on your next run or test.

The `prod` image runs `collectstatic` during the build, so the `web/static` it
carries holds those bundles together with the files Django gathers from
installed packages -- `admin/`, `rest_framework/`, `django_extensions/`,
`css/`. WhiteNoise serves that directory, so a running container can answer for
every static URL the app renders.

### Stop

When you are finished, spin down Docker containers by running:

    $ docker compose down

Your database will persist and will load automatically the next time you run `docker compose up -d`.

Or, you can clean up everything Docker-related, so you can start fresh, as with a new installation:

    $ bash docker/clean.sh


## Testing

### Test Commands

Run these from inside the container.

1. `pytest` runs python tests
1. `pytest -n auto --dist loadgroup` runs python tests with concurrency (faster, same config as CI)
1. `flake8` runs python lints
1. `npm run test` runs javascript unit tests using [Mocha](https://mochajs.org)
1. `npm run test-watch` runs javascript unit tests with the `--watch` option to auto-rerun on test changes
1. `npm run lint` runs javascript lints
1. `pytest -k functional` runs the Playwright tests only.

Playwright tests spawn their own test runner against the compiled bundles. Those
are rebuilt automatically when your frontend changes, so a JS edit is reflected
in the next test run without any manual step.

To debug failed Playwright runs, use:

```
pytest -k functional --video retain-on-failure
```

and look in `web/test-results` for video recordings of the failures.

### Coverage

Coverage will be generated automatically for all manually-run tests.

## Migrations

We use standard Django migrations.

### The migration list in an image

Every built image carries `/app/web/migrations.json`, written during the build
by `./manage.py migration_manifest`. It lists the migrations that image has on
disk -- those from installed packages as well as this repository's -- so what an
image expects of the database can be read without running it:

```json
{
  "format": 1,
  "hash": "8e169dee97f0",
  "count": 67,
  "migrations": ["admin.0001_initial", "auth.0001_initial", "..."]
}
```

`migrations` holds sorted `app_label.migration_name` strings. `hash` is the
first 12 hex digits of the sha256 of those names, one per line, each terminated
by a newline. `format` is bumped if this shape changes, so a mismatch there
reads as a version difference rather than a disagreement about migrations.

The same command run in a container produces the same document, which is what
makes an image and a deployed environment comparable by `hash` alone. It reports
what is on disk and never what a database has applied; `MigrationLoader` is
constructed with no connection.

## Deploys

A merge to `main` builds one image, runs the suite against it, and publishes it.
Merging `main` into `staging` deploys that published image; merging `staging`
into `prod` deploys the image staging is running. Nothing after the build on
`main` builds anything, so the bytes production serves are the bytes the suite
ran against.

### One registry

Every h2o web image lives in the ECR repository `h2o`, and both tiers run out of
it. Production is promoted by adding a tag to the image that is already there,
so the digest production runs is the digest staging tested -- there is no copy
step and no second digest to reconcile.

Four kinds of tag appear in `h2o`:

| Tag | Written by | Means |
| --- | --- | --- |
| `<commit sha>` | the build on `main` | a candidate the suite passed; immutable, and what a staging deploy resolves to a digest |
| `staging-deployed-<sha>` | the staging deploy | staging promoted this image |
| `prod-deployed-<sha>` | the production deploy | production promoted this image |
| `latest` | either deploy | a moving pointer at whichever tier deployed most recently |

`latest` is a placeholder. The Terraform task definitions name it so they have
some image to reference, and every deploy replaces it with a digest before the
service runs that revision; nothing reads it to decide what to ship.

The repository's lifecycle policy gives each population its own count:
`prod-deployed-` first, then `staging-deployed-`, then a catch-all for build
candidates. An image production has promoted carries both deploy tags, and ECR
lets the first matching rule govern an image, so such an image is kept on
production's longer count.

The export Lambda's image lives separately, in `pandoc-lambda`, tagged with the
commit SHA and marked `deployed-<sha>` by a deploy. That repository serves both
tiers and its retention rule selects `deployed-`, with no tier in it.

### The old repositories

`staging-h2o` and `prod-h2o` held these images before, one repository per tier.
Nothing writes to them now. They are kept, and readable, because an ECS task
definition pins its image by digest: a revision registered before the
consolidation names one of them, and can only be run again while it exists.
Neither carries a lifecycle policy, so nothing in them expires.

### Rolling back

To roll back to an image in `h2o`, find the tag and resolve it to a digest:

```
aws ecr describe-images --repository-name h2o --filter tagStatus=TAGGED \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[].{pushed:imagePushedAt,tags:imageTags}' \
  --output table

aws ecr describe-images --repository-name h2o \
  --image-ids imageTag=prod-deployed-<sha> \
  --query 'imageDetails[0].imageDigest' --output text
```

Then register a task definition whose web container names
`<registry>/h2o@<digest>` and update the service to it -- the same two steps the
deploy sequence takes, with an older digest.

Pre-consolidation targets are in `prod-h2o`, under the older `deployed-<sha>`
tag shape and any tag put there by hand, such as
`deployed-rollback-2026-07-09`. The same commands work against that repository
name, and the image URI is then `<registry>/prod-h2o@<digest>`. This is a manual
ECS operation: the deploy workflows only ever deploy digests in `h2o`, and the
static files and migration list a deploy expects to read off an image were
attached to images in `h2o`, so an archive image is deployed by pointing the
service at it rather than by re-running a workflow.

## Contributions

Contributions to this project should be made in individual forks and then merged by pull request. Here's an outline:

1. Fork and clone the project.
1. Make a branch for your feature: `git branch feature-1`
1. Commit your changes with `git add` and `git commit`. (`git diff  --staged` is handy here!)
1. Push your branch to your fork: `git push origin feature-1`
1. Submit a pull request to the upstream main through GitHub.

## License

This codebase is Copyright 2021 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
