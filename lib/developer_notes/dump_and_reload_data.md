

1. `rake db:schema:load` clear the database and rebuild the sceme
1. Make sure you have the `h2o_prod-data.dump` file in your root directory.
1. `pg_restore --verbose --clean --no-acl --no-owner -U h2oadmin -h [aws link] -d h2o ~/h2o_prod-data.dump` port the data dump into the database
  1. (for running locally: `pg_restore --verbose --clean --no-acl --no-owner -h localhost -d h2o_dev ~/h2o_prod-data.dump `)
1. `rake db:migrate`
1. `rails c`
