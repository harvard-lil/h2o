## Testing

### ...locally, against the Lambda Runtime Interface Emulator

In the H2O app's `settings.py`, set `FORCE_AWS_LAMBDA_EXPORT = True`. Then, every Casebook's export will be routed to a local container that runs the lambda function.

Or, log in to your local H2O as an administrator and click the "AWS Lambda Export" button.

Run `docker-compose logs -f pandoc-lambda` to watch requests come in and review their metrics.

### ...locally, against a function already deployed to AWS Lambda

This takes a little doing.

First, connect to the LIL Algo VPN.

Then, you'll need the right AWS permissions. You need to be able trigger the function by name and to be able to write to the appropriate S3 bucket. Make sure you are set up to use those credentials locally via the AWS command line tools and a properly configured "profile".

Then, you need to share those credentials with the H2O docker container. Comment in the `~/.aws` volume in `docker-compose.yml` and re-run `docker-compose up -d`.

Next, add some settings to your local H2O's `settings.py`:
```
FORCE_AWS_LAMBDA_EXPORT = True
AWS_S3_SESSION_PROFILE=<the-profile-name>
AWS_LAMBDA_EXPORT_BUCKET=<the-bucket-name>
AWS_LAMBDA_EXPORT_STORAGE_SETTINGS = {}
AWS_LAMBDA_EXPORT_FUNCTION_ARN=<the-correct-arn>
```

As above, decide whether you want to send all casebook exports to the lambda (add `FORCE_AWS_LAMBDA_EXPORT = True` to `settings.py`) or if you prefer to log in as an administrator and click the "AWS Lambda Export" button.

Have your phone handy. Click the export button and watch the dev console. Immediately after you see `Exporting Casebook {casebook.id}: uploading source`, you will be prompted to enter an MFA code. Enter it and press return and the process will continue. You should see `Exporting Casebook {casebook.id}: triggering lambda` a second or two later. If you don't, you might need to press return a second time. (I'm not sure why that happens occasionally...)

When the lambda returns, you should see its log printed to the console and should be served a DOCX in your browser. Or, failing that, you should at least be given a decent error message.


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
