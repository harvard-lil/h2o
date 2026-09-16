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

Frontend assets live in `frontend/` and are compiled with Vite.

`invoke run` starts the Vite dev server alongside Django, so edits under
`frontend/` are picked up without a restart. There is no separate
`invoke run-frontend` any more -- it is what `invoke run` does.

The compiled bundles (`static/dist/`, including `manifest.json`) are build output
and are **not** committed. You do not normally need to think about them: both
`invoke run` and `pytest` compile them when they are missing or out of date. To
build them by hand:

    # invoke build-frontend

Staleness is decided by hashing the build's inputs -- `frontend/`,
`static/images/`, and the npm and Vite configs -- against the hash recorded when
the bundles were last built, so pulling someone else's frontend change triggers
a rebuild on your next run or test.

The `prod` image runs `collectstatic` during the build, so the `web/static` it
carries holds those bundles together with the files Django gathers from
installed packages -- `admin/`, `rest_framework/`, `django_extensions/`,
`css/`. WhiteNoise serves that directory, so a running container can answer for
every static URL the app renders.

### Dependency stack

The containers use Python 3.14 on Debian Trixie, Django 6.1, Node 24 LTS,
PostgreSQL 16.13, and Pandoc 3.11. Python dependencies are locked with uv;
JavaScript dependencies are locked with npm.

The frontend runs Vue 3 using its compatibility build while existing components
are migrated to native Vue 3 APIs. Vite replaces Vue CLI/Webpack, and Vitest
replaces Mocha. The table-of-contents drag-and-drop components are maintained in
`web/frontend/components/nestable/`, with their upstream MIT license, because
the previous package included its own Vue 2 runtime.

### Python dependencies

Python dependencies are managed with uv. The web app and export Lambda each have
an independent `pyproject.toml` and `uv.lock`. From the repository root:

    uv add --project web PACKAGE
    uv add --project web --group dev DEV_PACKAGE
    uv lock --project web --upgrade
    uv add --project docker/pandoc-lambda PACKAGE
    uv lock --project docker/pandoc-lambda --upgrade

Rebuild affected containers after changing a lockfile (`docker compose up -d --build`).
Production installs only runtime dependencies with `uv sync --locked --no-dev`.
The dev and test images also install the `dev` group, which contains linting,
type-checking, debugging, and test tools. Keep deployment commands such as
`invoke` in runtime dependencies. All images use `/opt/venv`, so mounting the
checkout does not replace installed dependencies.

### PostgreSQL version

The local PostgreSQL image must always match the `engine_version` pinned in
[`lil-terraform/h2o/aws/db/db_instance.tf`](https://github.com/harvard-lil/lil-terraform/blob/main/h2o/aws/db/db_instance.tf),
which manages the staging and production databases. The current version is
16.13. Update `docker-compose.yml` when that Terraform pin changes, and keep the
client major version in `docker/install-test-toolchain.sh` aligned as well.
Database upgrades should be coordinated separately from application dependency updates.

Local data uses the existing `db_data_16` volume mounted at
`/var/lib/postgresql/data`.

### Stored files

Uploaded images, and the intermediate files exports pass through, go to the
`s3` service. It keeps objects as plain files in the `s3_data` Docker volume:
each bucket (`h2o.images`, `h2o.exports`, `h2o.pdf_exports`) is a directory
under `/data`, and each object is a file at its key's path. To look at them:

    $ docker compose exec s3 ls -R /data/h2o.images
    $ docker compose cp s3:/data/h2o.images ./h2o-images-copy

Read files this way, but add or change them through the app or an S3 client.
The gateway keeps each object's ETag and content type in extended file
attributes, which files written directly into the volume lack.

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
1. `npm run test` runs javascript unit tests using [Vitest](https://vitest.dev)
1. `npm run test-watch` runs javascript unit tests with the `--watch` option to auto-rerun on test changes
1. `npm run lint` runs javascript lints
1. `pytest -k functional` runs the Chromium Playwright tests only.
1. `pytest -k functional --browser firefox` runs the same browser tests in Firefox.

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

### Published migration manifests

The shared `django-migration-manifest` action inspects the built production image
with build-only settings and writes a format-1 manifest on the CI runner. Shared
`ecr-artifacts` attaches it, alongside the reproducible static archive, to the
published image digest. The application contains no manifest management command.
Deployment fetches these referrers without pulling or launching the image:

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

The shared inspector also runs through ECS Exec in an existing service task,
so the incoming manifest and deployed migrations can be compared. It reports
what is on disk and never what a database has applied; `MigrationLoader` is
constructed with no connection.

## Error monitoring

CI passes `H2O_RELEASE=h2o@<commit SHA>` to both Docker build targets. The frontend
bundles and Django Sentry SDK report this baked-in release, which remains the same
when the image is promoted through staging and production. Locally the value is
unset unless supplied explicitly. A browser tab still running an older bundle
reports that bundle's release, rather than the current server's release.

Source maps are not generated or uploaded. Adding private uploads later requires
a Sentry upload credential and keeping map files out of the published static
archive. Release tags alone require no new credential or runtime service.

The frontend drops only the confirmed Zotero `i18n.getStrings` background-page
error. Other extension errors, HTTP errors, and network failures remain visible.

### Browser verification for annotation requests

Cloudflare protects H2O's database from heavy crawler traffic. Its bot checks
sometimes also challenge legitimate readers loading annotations or saving edits.
A challenge returns an HTML verification page instead of the expected API
response, so a background request cannot complete it on its own.

Turnstile is Cloudflare's embeddable browser-verification widget. H2O shows it in
a dialog only when a request is challenged. With **pre-clearance** enabled,
completing the widget gives the browser a Cloudflare clearance cookie, allowing
subsequent requests through applicable challenge checks without leaving the page.
H2O then retries the blocked request once. Existing bot rules and Django access
permissions remain in effect.

The integration is disabled until `TURNSTILE_SITE_KEY` and `TURNSTILE_SECRET_KEY`
are set in the tier's application configuration. Create a Managed Turnstile
widget for the exact staging/production hostnames and enable **managed**
pre-clearance. The site key identifies the widget publicly; the secret key stays
on the server and is used to validate its result through Cloudflare's Siteverify
API. See [Cloudflare's clearance configuration](https://developers.cloudflare.com/cloudflare-challenges/concepts/clearance/).

Only same-origin Axios requests returning HTTP 403 with
`cf-mitigated: challenge` open the dialog. This header identifies requests
intercepted before reaching Django, so retrying a save will not duplicate a
completed operation. Ordinary permission errors, network failures, and server
errors are never automatically replayed. Simultaneous challenges share one
check; Cancel leaves the page open so users can copy unsaved text. Legacy jQuery
requests and ordinary HTML form submissions are outside this integration.

The `/browser-verification/` endpoint requires CSRF protection and validates the
widget token's hostname and action before releasing waiting requests. If
verification fails, the dialog explains the failure and offers Close; no request
is retried.

Before enabling production, test on staging with real widget keys: complete
verification for a challenged annotation read and save, confirming one successful
save without a reload. Also test cancellation with note text, concurrent failed
reads, a blocked widget script, and a second challenge after retry. Cloudflare
test keys exercise widget UI but do not demonstrate real edge clearance.

## Deploys

A merge to `main` builds one image, runs the suite against it, and publishes it.
Merging `main` into `staging` deploys that published image; merging `staging`
into `prod` deploys the image staging is running. Nothing after the build on
`main` builds anything, so the bytes production serves are the bytes the suite
ran against.

Publication and promotion use the shared `lil-actions` helpers at `@main`,
following the policy for LIL-owned actions. A retry reuses a complete web publication, including its static
and migration referrers. An absent image is built and tested before publication;
a partially published web image stops the run rather than overwriting its SHA
tag. Repair missing referrers from the existing image digest before retrying.
Deployments also stop on missing, conflicting, or corrupt referrers; there is no
automatic full-image fallback. Shared `ecs-django-maintenance` owns the migration
comparison, pending-plan check, and existing force/skip maintenance policy.
The Lambda image is inspected independently so a retry can finish its publication.

Staging requires the selected image's source tree to match the promotion commit.
Production requires a stable staging service, an image in the expected registry,
one unambiguous source commit tag, and a matching production source tree.
Deployments are serialized per tier. Completion requires the requested task
revision, so a rollback cannot silently count as success. Scheduled target updates
preserve existing settings and check both the API result and the stored revision.

### The maintenance window

A deploy puts the site into maintenance only when the schema the running tasks
serve against is not the schema the new code expects. That is worked out from
the migration list built into the image and the one a running task reports, so
an ordinary deploy that adds no migrations replaces tasks with the site up. Any
answer the deploy cannot get -- no running task, an exec session that will not
start, output it cannot read -- takes the window, because guessing wrong in the
other direction serves traffic against a schema in motion.

Two labels on the pull request being merged override that decision:

`deploy:force-maintenance-mode` takes the window whatever the migrations say.
This is also the only way to exercise the maintenance path on a deploy that
carries no migrations, which is otherwise the only thing that opens one.

`deploy:skip-maintenance-mode` deploys without the window whatever the
migrations say. It does not skip the migrations -- they still run, against a
service still taking traffic -- so it asserts that they are backward compatible
with the code currently serving. Additive columns, new tables and new indexes
are; dropping or renaming something the running code still reads is not.

Setting both takes the window.

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
| `staging-latest` / `prod-latest` | the corresponding tier deploy | Terraform placeholder, advanced after rollout and migrations succeed |

The tier tags are placeholders. Terraform task definitions name them so they
have an image to reference; deployment registers a digest-pinned revision. The
placeholders are not inputs to artifact selection.

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

`just rollback` in [lil-terraform](https://github.com/harvard-lil/lil-terraform)
does this. `just rollback h2o prod` lists what can be rolled back to and
`just rollback h2o prod <revision>` does it:

```
h2o / prod    cluster prod-h2o    running prod-h2o:26

   REV  REGISTERED        BUILT FROM                      DIGEST
    26  2026-09-04 10:00  707c30974d3273deba449d13077c3b  bdd975254d2d…  <- running
    24  2026-09-04 09:21  707c30974d3273deba449d13077c3b  bdd975254d2d…
    23  2026-09-03 16:11  85cb78114e91450aa07002792f9796  ce339856e858…
    22  2026-09-02 17:45  deployed-rollback-2026-07-09    b24a98874179…
```

It lists only revisions that name a digest. Terraform registers revisions into
the same family naming a moving tag, and rolling back to one of those would run
whatever that tag points at now -- which after a deploy is the code you are
trying to get away from.

Images in the archive repositories are reached the same way, because a revision
records the image it pinned: revision 22 above names an image in `prod-h2o`,
tagged by hand before the consolidation, and rolling back to it works without
anything special. What a rollback cannot do is re-run a deploy, so the static
files and migration list are not republished; the assets an older image expects
are already in the bucket, which is only ever added to.

## Contributions

Contributions to this project should be made in individual forks and then merged by pull request. Here's an outline:

1. Fork and clone the project.
1. Make a branch for your feature: `git branch feature-1`
1. Commit your changes with `git add` and `git commit`. (`git diff  --staged` is handy here!)
1. Push your branch to your fork: `git push origin feature-1`
1. Submit a pull request to the upstream main through GitHub.

## License

This codebase is Copyright 2021 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
