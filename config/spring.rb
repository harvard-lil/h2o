%w(
  .ruby-version
  .rbenv-vars
  tmp/restart.txt
  tmp/caching-dev.txt
).each { |path| Spring.watch(path) }

# Uncomment to suppress output from Spring.
# See https://github.com/harvard-lil/h2o/issues/743
# Spring.quiet = true
