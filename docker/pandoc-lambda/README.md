## Testing

### ...locally, against the Lambda Runtime Interface Emulator

In development, every Casebook's export will be routed to a local container that runs the lambda function in app.py.

Run `docker compose logs -f pandoc-lambda` to watch requests come in and review their metrics.

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
If not, you can run `docker compose restart pandoc-lambda` to restart the container.

To deploy your changes to production you'll need to bundle the final version of your code into the Docker image and push it to AWS.

Rebuild the local image with `docker compose up -d --build pandoc-lambda`.

### Python dependencies

From the repository root, use `uv add --project docker/pandoc-lambda PACKAGE`
or `uv lock --project docker/pandoc-lambda --upgrade`. Commit both
`pyproject.toml` and `uv.lock` with the code change. The image installs the exact
lockfile using `uv sync --locked`.

### Pandoc and the Lambda Runtime Interface Emulator

Update `PANDOC_VERSION` or `LAMBDA_RIE_VERSION` in `Dockerfile`, then rebuild the service.
The build selects the matching amd64 or arm64 release for the target platform.

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
