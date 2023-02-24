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

    # invoke run

or, with [Django Debug Toolbar](https://django-debug-toolbar.readthedocs.io/en/latest/index.html#) enabled,

    # invoke run --debug-toolbar

...and visit http://opencasebook.test:8000

### Frontend assets

Frontend assets live in `frontend/` and are compiled with vue-cli. If you want to run frontend assets:

Install requirements:

    # npm install

Run the development server with hot-reloading vue-cli pipeline:

    # invoke run-frontend

or, with [Django Debug Toolbar](https://django-debug-toolbar.readthedocs.io/en/latest/index.html#) enabled,

    # invoke run-frontend --debug-toolbar

After making changes to frontend/, compile new assets if you want to see them from plain `invoke run`:

    # npm run build

`npm run build` will be automatically run by Github Actions as well, so it is unnecessary (but harmless) to build and
commit the new assets locally, unless you want to use them immediately.

### Asynchronous tasks with Celery

We use [Celery](https://docs.celeryq.dev/en/stable/index.html) to run tasks
asynchronously, which is to say, outside the usual request/response flow of the
Django application.

Tasks are defined in `main/celery_tasks.py`.

Tasks are put on a FIFO queue backed by redis/ElastiCache (configured by
`CELERY_BROKER_URL`), and are taken off the queue and processed by
Celery "workers": Linux processes that you spin up independently of the web
server. Each running task is effectively its own, short-lived instance of your
Django application: you can access Django settings, interact with models and
the database, etc.

To put a task on the queue, use the [`delay`]
(https://docs.celeryq.dev/en/stable/reference/celery.app.task.html?highlight=delay#celery.app.task.Task.delay)
or [`apply_async`]
(https://docs.celeryq.dev/en/stable/reference/celery.app.task.html?highlight=delay#celery.app.task.Task.apply_async)
methods. E.g.:

    my_task.delay()

To schedule a task to run regularly, configure `CELERY_BEAT_SCHEDULE` with the
desired schedule, route the task to an appropriate queue using
`CELERY_TASK_ROUTES` (or let it default to the main queue, which is
called 'celery'), ensure that [celery beat is running]
(https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html#starting-the-scheduler),
and ensure that at least one worker is listening to the configured queue.

#### Local development

For developers' convenience, Celery tasks can be run synchronously locally by
the Django development server or in the Django shell: if
`CELERY_TASK_ALWAYS_EAGER = True`, when you call `my_task.delay()`, the task
runs right there in the calling process, as though you had invoked a "normal"
python function rather than a celery task.

This not only reduces the amount of RAM/CPU utilized (because you don't need to
be running redis, and don't need to have any worker processes running), but
also makes it easy to drop into the debugger, and prints/logs to the console
like Django does.

`CELERY_TASK_ALWAYS_EAGER` is set to `True` by default in our development
environment.

To test the full asynchronous setup, quit the dev server, add
`CELERY_TASK_ALWAYS_EAGER = False` to `settings.py` and re-run `invoke run`:
Invoke will spin up workers in a background process and start celery beat. You
should see the workers restarting whenever you save a python file (just like
the Django dev server does).

Note that celery beat will not schedule or run any tasks if
`CELERY_TASK_ALWAYS_EAGER = True`; celery beat only works with the full
asynchronous setup.

#### Testing

The easiest way to test tasks is to call them directly in your test code:

    def test_my_task():
        my_task.apply()

But, if you need to test with the full Celery apparatus (for instance, to check error handling and recovery, timeouts, etc.), a number of pytest fixtures are available. See the [Celery docs](https://docs.celeryq.dev/en/stable/userguide/testing.html) for further information.


### Stop

When you are finished, spin down Docker containers by running:

    $ docker-compose down

Your database will persist and will load automatically the next time you run `docker-compose up -d`.

Or, you can clean up everything Docker-related, so you can start fresh, as with a new installation:

    $ bash docker/clean.sh


## Testing

### Test Commands

Run these from inside the container.

1. `pytest` runs python tests
1. `pytest -n auto --dist loadgroup` runs python tests with concurrency (faster, same config as CI)
1. `flake8` runs python lints
1. `npm run test` runs javascript unit tests using [Mocha](https://mochajs.org)
1. `npm run lint` runs javascript lints
1. `pytest -k functional` runs the Playwright tests only.

Playwright tests will spawn their own test runner. You will need to run `npm run build` manually for the test runner to pick up any changes to the JS.

To debug failed Playwright runs, use:

```
pytest -k functional --video retain-on-failure
```

and look in `web/test-results` for video recordings of the failures.

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
