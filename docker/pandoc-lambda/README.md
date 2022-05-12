## Testing

### ...locally, against the Lambda Runtime Interface Emulator

In development, every Casebook's export will be routed to a local container that runs the lambda function in app.py.

Run `docker-compose logs -f pandoc-lambda` to watch requests come in and review their metrics.

### ...locally, against a function already deployed to AWS Lambda

First, obtain AWS credentials that will let you 1) trigger the function by name and 2) write to and delete from the appropriate S3 bucket... and nothing else, lest you accidentally wreak havoc on our production systems.

Then, add the following to your local H2O's `settings.py`:
```
AWS_LAMBDA_EXPORT_SETTINGS = {
    'bucket_name': <the-bucket-name>,
    'access_key': <the-aws-access-key>,
    'secret_key': <the-aws-secret-key>,
    'function_arn': <the-already-deployed-lambda-function's-arn>
}
```

Connect to the VPN.

When the lambda returns, you should see its log printed to the console and should be served a DOCX... or, failing that, at least be given an instructive error message.


## Updating the image...

### ...after code changes

During local development, changes to `function/app.py` are synced to the running container and should be noticed immediately.
If not, you can run `docker-compose restart pandoc-lambda` to restart the container.

To deploy your changes to production you'll need to bundle the final version of your code into the Docker image and push it to AWS.

Increment the image number in `docker-compose.yml` and re-run `docker-compose up -d`. That will produce a newly-tagged image that includes your code.

(We probably want to script this, adding it to our CI pipeline, similar to how CAP builds and pushes dev images to our registry.)

### ...with new python requirements, including `awslambdaric`

Add new packages or pin versions in `requirements.in`. Then run `docker-compose exec pandoc-lambda pip-compile --allow-unsafe --generate-hashes`.

Increment the image number in `docker-compose.yml` to produce a new image.

If you can't start the container because of a requirements change, you may need to edit docker-compose.yml to temporarily disable the entrypoint.

To update a single (unpinned) package such as `awslambdaric` do the same thing, except add `--upgrade-package awslambdaric` or similar.

### ...with a new Lambda Runtime Interface Emulator

Change the cache-buster hash in `docker-compose.yml`, update the Docker image number, and re-run `docker-compose up -d`. This process could be further scripted, like Perma's Google Chrome update is.

### ...with a new version of pandoc

Change the target version number in `Dockerfile`, increment the image number in `docker-compose.yml`, and re-run `docker-compose up -d`.


## Deploying to AWS Lambda

The general outline is that we build an image, tag it, push it to ECR, and then deploy the new image to the lambda, something like this, starting in this directory:

```
IMG=pandoc-lambda
TAG=`git rev-parse --short HEAD`
ACCT=123456789012
REGION=us-east-1
PROFILE=mfa
FUNC=h2o-export
ARN=arn:aws:lambda:${REGION}:${ACCT}:function:${FUNC}
aws ecr get-login-password --region ${REGION} --profile ${PROFILE} | docker login --username AWS --password-stdin ${ACCT}.dkr.ecr.${REGION}.amazonaws.com
docker buildx build --push --platform linux/amd64 --tag ${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${IMG}:${TAG} .
aws lambda update-function-code --function-name ${ARN} --image-uri ${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${IMG}:${TAG} --profile ${PROFILE} --region ${REGION}
```
