## Testing

### ...locally, against the Lambda Runtime Interface Emulator

In the H2O app's `settings.py`, set `FORCE_AWS_LAMBDA_EXPORT = True`. Then, every Casebook's export will be routed to a local container that runs the lambda function.

Or, log in to your local H2O as an administrator and click the "AWS Lambda Export" button.

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

Then, as above, decide whether you want to send all casebook exports to the lambda (add `FORCE_AWS_LAMBDA_EXPORT = True` to `settings.py`) or if you prefer to log in as an administrator and click the "AWS Lambda Export" button.

When the lambda returns, you should see its log printed to the console and should be served a DOCX... or, failing that, at least be given an instructive error message.


## Updating the image...

### ...after code changes

For convenience during local development, changes to `function/app.py` are synced to the running container, but you have to restart the local Lambda emulator for it to pick them up. Run `docker-compose restart pandoc-lambda`.

To deploy your changes to production you'll need to bundle the final version of your code into the Docker image and push it to AWS.

Increment the image number in `docker-compose.yml` and re-run `docker-compose up -d`. That will produce a newly-tagged image that includes your code.

(We probably want to script this, adding it to our CI pipeline, similar to how CAP builds and pushes dev images to our registry.)

### ...with new python requirements, including `awslambdaric`

Add new packages or pin versions in `requirements.in`. Then, follow the instructions in `docker-compose.yml` to recompile `requirements.txt` and update the Docker image.

To update a single (unpinned) package such as `awslambdaric` do the same thing, except add `--upgrade-package awslambdaric` or similar to the cmd in `docker-compose.yml`.

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
ARN=arn:aws:lambda:$REGION:$ACCT:function:$FUNC
docker build -t $IMG:$TAG .
docker tag $IMG:$TAG $ACCT.dkr.ecr.$REGION.amazonaws.com/$IMG:$TAG
aws ecr get-login-password --region $REGION --profile $PROFILE | docker login --username AWS --password-stdin $ACCT.dkr.ecr.$REGION.amazonaws.com
docker push $ACCT.dkr.ecr.$REGION.amazonaws.com/$IMG:$TAG
aws lambda update-function-code --function-name $ARN --image-uri `docker image inspect $IMG:$TAG | jq -r '.[0].RepoDigests[0]'` --profile $PROFILE
```
