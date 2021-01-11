# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface
>where instructors and students alike can author, organize, view and print public-domain course material.

[![CircleCI](https://circleci.com/gh/harvard-lil/h2o.svg?style=svg)](https://circleci.com/gh/harvard-lil/h2o)
[![codecov](https://codecov.io/gh/harvard-lil/h2o/branch/master/graph/badge.svg)](https://codecov.io/gh/harvard-lil/h2o)

## Development: Docker

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

Spin up the development server:

    # fab run

### Frontend assets

Frontend assets live in `frontend/` and are compiled with vue-cli. If you want to run frontend assets:

Install requirements:

    # npm install

Run the development server with hot-reloading vue-cli pipeline:

    # fab run_frontend

After making changes to frontend/, compile new assets:

    # npm run build

(Or if you run_frontend and don't end up changing anything, then instead of running `npm run build` afterward
you can just revert the changes to `webpack-stats.json`)

### Stop

When you are finished, spin down Docker containers by running:

    $ docker-compose down

Your database will persist and will load automatically the next time you run `docker-compose up -d`.

Or, you can clean up everything Docker-related, so you can start fresh, as with a new installation:

    $ bash docker/clean.sh


## Testing

### Test Commands

1. `pytest` runs python tests
1. `flake8` runs python lints
1. `npm run test` runs javascript tests using [Mocha](https://mochajs.org)
1. `npm run lint` runs javascript lints

### Coverage

Coverage will be generated automatically for all manually-run tests.

## Migrations

We use standard Django migrations

## Contributions

Contributions to this project should be made in individual forks and then merged by pull request. Here's an outline:

1. Fork and clone the project.
1. Make a branch for your feature: `git branch feature-1`
1. Commit your changes with `git add` and `git commit`. (`git diff  --staged` is handy here!)
1. Push your branch to your fork: `git push origin feature-1`
1. Submit a pull request to the upstream develop through GitHub.

## License

This codebase is Copyright 2021 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
