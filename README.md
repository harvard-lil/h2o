# h2o

> h2o is open-source software designed to replace bulky and expensive law textbooks with an easy-to-use web interface where instructors and students alike can author, organize, view and print public-domain course material.

## Contents

1. [Live version](#live_version)
2. [Development](#development)
3. [Testing](#testing)
3. [License](#license)

## [Live version](https://h2o.law.harvard.edu/)

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

The dev server is now accessible at http://localhost:8000, but it likely won't look quite right because Typekit isn't loading. To fix:

1. e.g. OS X: `echo 127.0.0.1 h2o.murk.law.harvard.edu | sudo tee -a /etc/hosts`
2. Go to [http://h2o.murk.law.harvard.edu:8000](http://h2o.murk.law.harvard.edu:8000)

> TODO: Change this to something more like `h2o.local` and add that to Typekit :)

## Testing

### Test design

Since we're going to be heavily refactoring and likely removing a lot of code, the focus for now will be on high-level feature tests which will survive that. [cases_test.rb](test/features/cases_test.rb) is an example of the test pattern using Minitest and Capybara which exercises the full stack from a user's point of view.

### Javascript

Test scenarios marked with `js: true` will be run in a headless WebKit environment via Poltergeist. This requires the PhantomJS binary to be installed, e.g. `brew install phantomjs`. Headless tests are significantly slower than static tests, so prefer to avoid writing tests (and features!) that require JS when possible.

### Guard testing

Guard will automatically run all tests after booting Rails and (should) again after any test or app file is edited. Tests can also be run manually:

1. `bin/rake test:all` runs all tests.
1. `bin/rake test test/features/cases_test.rb` runs the case feature test, and so on.

### Coverage

1. `bin/rake test:coverage` will run all tests and generate a coverage report in `coverage/index.html`.

> TODO: When coverage is a bit higher, add a git commit hook which runs the coverage report and fails if under some value.

## License

This codebase is Copyright 2017 The President and Fellows of Harvard College and is licensed under the open-source AGPLv3 for public use and modification. See [LICENSE](LICENSE) for details.
