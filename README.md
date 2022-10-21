# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface
>where instructors and students alike can author, organize, view and print public-domain course material.


[![test status](https://github.com/harvard-lil/h2o/actions/workflows/tests.yml/badge.svg)](https://github.com/harvard-lil/h2o/actions)
[![codecov](https://codecov.io/gh/harvard-lil/h2o/branch/develop/graph/badge.svg)](https://codecov.io/gh/harvard-lil/h2o)

## Development

We support local development with [Docker Compose](https://docs.docker.com/compose/).

### Hosts Setup

Add the following to `/etc/hosts`:

    127.0.0.1 opencasebook.test opencasebook.minio.test

### Spin up some containers

Start up the Docker containers in the background:

    $ docker-compose up -d

The first time this runs it will build the Docker images, which
may take several minutes. (After the first time, it should only take
1-3 seconds.)

If the H2O team has provided you with a pg_dump file, seed the database with data:

    $ bash docker/init.sh -f ~/database.dump

Then log into the main Docker container:

    $ docker-compose exec web bash

(Commands from here on out that start with `#` are being run in Docker.)

### Run Django

You should now have a working installation of H2O!

Spin up the development server...

    # fab run
    or, with [Django Debug Toolbar](https://django-debug-toolbar.readthedocs.io/en/latest/index.html#) enabled,
    # fab run:debug_toolbar=True

...and visit http://opencasebook.test:8000

### Frontend assets

Frontend assets live in `frontend/` and are compiled with vue-cli. If you want to run frontend assets:

Install requirements:

    # npm install

Run the development server with hot-reloading vue-cli pipeline:

    # fab run_frontend
    or, with [Django Debug Toolbar](https://django-debug-toolbar.readthedocs.io/en/latest/index.html#) enabled,
    # fab run_frontend:debug_toolbar=True

After making changes to frontend/, compile new assets if you want to see them from plain `fab run`:

    # npm run build

`npm run build` will be automatically run by Github Actions as well, so it is unnecessary (but harmless) to build and
commit the new assets locally, unless you want to use them immediately.

### Stop

When you are finished, spin down Docker containers by running:

    $ docker-compose down

Your database will persist and will load automatically the next time you run `docker-compose up -d`.

Or, you can clean up everything Docker-related, so you can start fresh, as with a new installation:

    $ bash docker/clean.sh


## Testing

### Test Commands

1. `pytest` runs python tests
1. `pytest -n auto --dist loadgroup` runs python tests with concurrency (faster, same config as CI)
1. `flake8` runs python lints
1. `npm run test` runs javascript tests using [Mocha](https://mochajs.org)
1. `npm run lint` runs javascript lints

### Coverage

Coverage will be generated automatically for all manually-run tests.

## Migrations

We use standard Django migrations.

## Contributions

Contributions to this project should be made in individual forks and then merged by pull request. Here's an outline:

1. Fork and clone the project.
1. Make a branch for your feature: `git branch feature-1`
1. Commit your changes with `git add` and `git commit`. (`git diff  --staged` is handy here!)
1. Push your branch to your fork: `git push origin feature-1`
1. Submit a pull request to the upstream develop through GitHub.

## License

This codebase is Copyright 2021 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
