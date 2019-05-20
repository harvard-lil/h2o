# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface where instructors and students alike can author, organize, view and print public-domain course material.

## Contents

1. [Live version](#live-version)
2. [Development: manual setup](#development-manual-setup)
2. [Development: using Docker](#development-docker-experimental)
3. [Testing](#testing)
3. [Migration](#migration)
3. [Contributions](#contributions)
3. [License](#license)

## [Live version](https://h2o-dev.lil.tools) &nbsp; [![Build Status](https://travis-ci.org/harvard-lil/h2o.svg?branch=master)](https://travis-ci.org/harvard-lil/h2o)
## [![Coverage Status](https://coveralls.io/repos/harvard-lil/h2o/badge.png?branch=master)](https://coveralls.io/r/harvard-lil/h2o?branch=master)

Auto-deploy of the latest master. If the build is green, it's up-to-date.


## Development: manual setup

> TODO: These instructions are incomplete for dev platforms other than OS X, and probably lack steps needed on a fresh machine.

### Set up RVM

1. Install RVM (if missing) with `\curl -sSL https://get.rvm.io | bash -s stable --auto-dotfiles`, then `source ~/.bash_profile` etc.
2. Install the project Ruby version (e.g. `rvm install $(<.ruby-version)`)
2. `cd` into the h2o directory (or `cd .` if already there) to create the gemset.

### Install gems with Bundler

1. `gem install bundler && bundle install`
2. (If Bundler complains about missing library dependencies, install them and `bundle install` until it succeeds.)

### Install node and npm packages

#### With Yarn
1. [Installation of yarn](https://yarnpkg.com/lang/en/docs/install/) is platform-specific. On a Mac: if you already have node installed, `brew install yarn --without-node`, or `brew install yarn` to simultaneously install node.
2. `yarn install`

Heads up: `yarn install` might get re-run for you behind the scenes under a number of circumstances. For instance,
- [Guard is configured to re-run yarn install](https://github.com/harvard-lil/h2o/blob/master/Guardfile#L10) when package.json changes
- Rails includes a `yarn:install` task that may be called from other Rails/Rake tasks, including `assets:precompile`
- Webpacker also runs `yarn:install` under certain circumstances

[We disabled some of the magic](https://github.com/harvard-lil/h2o/blob/master/Rakefile) to give us more control. You might want to keep an eye on your console, in case you are expecting `yarn install` to run automatically some place we've disabled it, or in case it runs some time when you aren't expecting it!

### Set up the Postgres database

1. Install postgres ~9.6 (if missing). Note: `brew install postgres` now installs postgres 10+. To install 9.6.5 via Homebrew, install postgres using the specific version formula (`brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/d014fa223f77bee4b4097c5e80faa0954e28182f/Formula/postgresql.rb`) and then run `brew switch postgres 9.6.5`
2. Start solr with `rails sunspot:solr:start`
3. Create and initialize the database with `rake db:setup` (or `rake db:reset`)
4. Stop solr with `rails sunspot:solr:stop`

*Note:* If `rake db:setup` fails with a message like `Sunspot::Solr::Server::NotRunningError`, try
`rails sunspot:solr:run` to see why solr failed to start. You may need to update your java installation
with `brew cask install java`

### Set Environment Variables

1. Copy `.env.example` to `.env`
2. Replace the values in `.env` with your own environment variables

### Run Guard

1. Run `guard`. It will take several seconds to:
2. Make sure the bundle is up-to-date;
2. Start the dev/test Solr server;
3. Load Spring for fast `rails`/`rake` commands;
4. And finally boot Rails.
3. (Optionally, install a notifier such as Growl or `brew install terminal-notifier` for Guard notifications.)
4. Guard will now be watching the project for changes and will restart Spring/Rails when needed. This can also be done from the guard command line, e.g. `reload rails`.
5. When finished, type `exit` to shut everything down and close Guard.

### Configure the local domain

1. e.g. OS X: `echo 127.0.0.1 h2o-dev.local | sudo tee -a /etc/hosts`
2. Go to [http://h2o-dev.local:8000](http://h2o-dev.local:8000)


## Development: Docker (experimental)

### Hosts

To ensure that URLs resolve correctly, add the following domain to your computer's hosts file:

127.0.0.1 h2o-dev.local

For additional information on modifying your hosts file, [try this help doc](http://www.rackspace.com/knowledge_center/article/how-do-i-modify-my-hosts-file).

### Spin up some containers

Start up the Docker containers in the background:

    $ docker-compose up -d

The first time this runs, it will build the 2.33GB Docker image, which
may take several minutes. (After the first time, it should only take
1-3 seconds.)

Finally, initialize an empty database...

    $ bash docker/init.sh

...or a database seeded with data from a pg_dump file:

    $ bash docker/init.sh -f ~/database.dump

### Run some commands

You should now have a working installation of H2O!

Spin up the development server:

    $ bash docker/run.sh

Or, run the tests:

    $ bash docker/test.sh

### Stop

When you are finished, spin down Docker containers by running:

    $ docker-compose down

Your database and solr index will persist and will load automatically the next time you run `docker-compose up -d`.

Or, you can clean up everything Docker-related, so you can start fresh, as with a new installation:

    $ bash docker/clean.sh


## Testing

### Test design

Since we're going to be heavily refactoring and likely removing a lot
of code, the focus for now will be on high-level feature tests which
will survive that. [cases_test.rb](test/features/cases_test.rb) is an
example of the test pattern using Minitest and Capybara which
exercises the full stack from a user's point of view.

Rails test scenarios marked with `js: true` will be run in a headless WebKit
environment via Poltergeist. This requires the chromedriver binary to
be installed, e.g. `brew cask install chromedriver`. Headless tests
are significantly slower than static tests, so prefer to avoid writing
Rails tests (and features!) that require JS when possible.

### Dependencies

ImageMagick and a global installation of the "Garamond" font are required. On Macs, you can verify the presence of Garamond in Applications > FontBook, and can install ImageMagick via `brew install imagemagick`.

### Test Commands

1. `yarn test` runs javascript tests using [Mocha](https://mochajs.org)
1. `bin/rails test` runs non-system Rails tests.
1. `bin/rails test:system` runs system Rails tests, including tests requiring JS.
1. `bin/rails test test/system/cases_test.rb` runs the case feature test, and so on.

### Coverage

Coverage will be generated automatically for all manually-run tests.

> TODO: When coverage is a bit higher, add a git commit hook which runs the coverage report and fails if under some value.

## Migration

Legacy Playlists must be converted into Casebooks. To convert all un-migrated, use this rake task:

`bin/rails h2o:migrate_playlists`

Any Playlists that don't have a Casebook with a matching `created_at` date will be migrated.

You can also migrate individual playlists from the rails console:

```
bin/rails c

> Migrate::Playlist.find(52410).migrate
=> #<Content::Casebook ... >

> Migrate::Playlist.find([11494, 5456, 1496]).map &:migrate
=> [#<Content::Casebook id: ...>, ...]
```

## Importing Data

If importing data from another installation of H2O into your local database, you may need to create an h2oadmin role in postgres first (e.g., `psql postgres`, followed by `CREATE ROLE h2oadmin;`. Note the terminating semi-colon).

Be advised that depending on the source of the data, some local rake tasks (e.g. `db:reset`) may subsequently fail with spurious warnings about affecting production data, regardless of the current value of `RAILS_ENV`.


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

This codebase is Copyright 2017 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
