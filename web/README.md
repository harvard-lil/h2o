# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface 
>where instructors and students alike can author, organize, view and print public-domain course material.

[![CircleCI](https://circleci.com/gh/harvard-lil/h2o.svg?style=svg)](https://circleci.com/gh/harvard-lil/h2o) 
[![codecov](https://codecov.io/gh/harvard-lil/h2o/branch/master/graph/badge.svg)](https://codecov.io/gh/harvard-lil/h2o)

## Development: Docker

### Hosts

To ensure that URLs resolve correctly, add the following domain to your computer's hosts file:

127.0.0.1 h2o-dev.local

For additional information on modifying your hosts file, 
[try this help doc](http://www.rackspace.com/knowledge_center/article/how-do-i-modify-my-hosts-file).

### Spin up some containers

Start up the Docker containers in the background:

    $ docker-compose up -d

The first time this runs it will build the Docker images, which
may take several minutes. (After the first time, it should only take
1-3 seconds.)

Finally, initialize an empty database...

    $ bash docker/init.sh

...or a database seeded with data from a pg_dump file:

    $ bash docker/init.sh -f ~/database.dump
    
Then log into the main Docker container:

    $ docker-compose exec python bash
    #
    
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
1. Submit a pull request to the upstream master through GitHub.

Whenever possible, pull requests should be fast-forwarded (i.e., `Rebase and Merge`d). This creates a nice, linear record of commits, without ugly merge commits that lose context and history.

In order to fast-forward a pull request, `upstream/master` shouldn't have any commits that aren't also on the fork in the same order— in other words, they have to agree about the history of the repo. This is a problem if upstream has changed since you created your branch!

Rather than creating a merge commit which reconciles the changes, you'll want to `rebase` your branch to `upstream/master`. Rebasing simply means that you stash your new commits temporarily, fast-forward your local repo to the updated `upstream/master`, and then apply your changes on top,  pretending that your commits are the most recent changes.

In general, GitHub can automatically rebase a pull request, but if there are any conflicts you'll need to resolve them manually with this process:

1. Add the upstream repository with `git remote add upstream`
1. Fetch the latest changes with `git fetch upstream`
1. Rebase your branch to upstream: `git rebase upstream/master`
1. (You can do both of these in one step with `git pull upstream master --rebase`)
1. If `upstream/master` has changes that conflict with your commits, you'll need to amend them at this time.
1. Push and pull request.

In the case of particularly ugly conflicts, rebasing can be more trouble than it's worth to preserve history, and a big merge commit will be the best option, but that should be avoided whenever possible. Rebasing your local branch to `upstream/master` frequently is the best way to avoid headaches later on.

## License

This codebase is Copyright 2019 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
