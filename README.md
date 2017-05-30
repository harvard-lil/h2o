# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface where instructors and students alike can author, organize, view and print public-domain course material.

## Contents

1. [Live version](#live-version)
2. [Development](#development)
3. [Testing](#testing)
3. [Contributions](#contributions)
3. [License](#license)

## [Live version](https://h2o-dev.lil.tools) &nbsp; [![Build Status](https://travis-ci.org/harvard-lil/h2o.svg?branch=master)](https://travis-ci.org/harvard-lil/h2o)
## [![Coverage Status](https://coveralls.io/repos/harvard-lil/h2o/badge.png?branch=master)](https://coveralls.io/r/harvard-lil/h2o?branch=master)

Auto-deploy of the latest master. If the build is green, it's up-to-date.


## Development

> TODO: These instructions are incomplete for dev platforms other than OS X, and probably lack steps needed on a fresh machine.

### Set up RVM

1. Install RVM (if missing) with `\curl -sSL https://get.rvm.io | bash -s stable --auto-dotfiles`, then `source ~/.bash_profile` etc.
2. Install the project Ruby version (e.g. `rvm install $(<.ruby-version)`)
2. `cd` into the h2o directory (or `cd .` if already there) to create the gemset.

### Install gems with Bundler

1. `gem install bundler && bundle install`
2. (If Bundler complains about missing library dependencies, install them and `bundle install` until it succeeds.)

### Set up the Postgres database

1. Install postgres (if missing) with e.g. `brew install postgres` for OS X.
3. Create and initialize the database with `rake db:setup` (or `rake db:reset`)

> TODO: Populate `seeds.rb`. Without certain seed data the app might still not be fully working.

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

## Testing

### Test design

Since we're going to be heavily refactoring and likely removing a lot of code, the focus for now will be on high-level feature tests which will survive that. [cases_test.rb](test/features/cases_test.rb) is an example of the test pattern using Minitest and Capybara which exercises the full stack from a user's point of view.

### Javascript

Test scenarios marked with `js: true` will be run in a headless WebKit environment via Poltergeist. This requires the PhantomJS binary to be installed, e.g. `brew install phantomjs`. Headless tests are significantly slower than static tests, so prefer to avoid writing tests (and features!) that require JS when possible.

Guard will not automatically run these tests. This is less than ideal when working on a client-side feature, so you can mark a given test with `focus: true` to force Guard to run it. If no JS tests are enabled, PhantomJS will not boot, speeding up the whole test suite considerably.

### Guard testing

Guard will automatically run all static tests after booting Rails and  again after any test or app file is edited. By default, Guard _won't_ run any tests that require JS, since they're so much slower. You can run those tests manually:

1. `bin/rails test:system` runs all tests, including JS tests.
1. `bin/rails test test/system/cases_test.rb` runs the case feature test, and so on, including JS tests.

### Coverage

Coverage will be generated automatically for all manually-run tests.

> TODO: When coverage is a bit higher, add a git commit hook which runs the coverage report and fails if under some value.

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
