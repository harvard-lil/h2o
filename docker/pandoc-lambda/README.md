## Test invocation

`docker-compose exec web curl -X POST "http://pandoc-lambda:8080/2015-03-31/functions/function/invocations" -d '{}'`


## Updating the image...

## ...after code changes

For convenience during local development, changes to `function/app.py` are synced to the running container, but you have to restart the local Lambda emulator for it to pick them up. Run `docker-compose restart pandoc-lambda`.

To deploy your changes to production you'll need to bundle the final version of your code into the Docker image and push it to AWS.

Increment the image number in `docker-compose.yml` and re-run `docker-compose up -d`. That will produce a newly-tagged image that includes your code.

(We probably want to script this, adding it to our CI pipeline, similar to how CAP builds and pushes dev images to our registry.)

## ...with new python requirements, including `awslambdaric`

Add new packages or pin versions in `requirements.in`. Then, follow the instructions in `docker-compose.yml` to recompile `requirements.txt` and update the Docker image.

To update a single (unpinned) package such as `awslambdaric` do the same thing, except add `--upgrade-package awslambdaric` or similar to the cmd in `docker-compose.yml`.

### ...with a new Lambda Runtime Interface

Change the cache-buster hash in `docker-compose.yml`, update the Docker image number, and re-run `docker-compose up -d`. This process could be further scripted, like Perma's Google Chrome update is.

### ...with a new version of pandoc

Change the target version number in `Dockerfile`, increment the image number in `docker-compose.yml`, and re-run `docker-compose up -d`.


## Deploying to AWS Lambda
TBD
