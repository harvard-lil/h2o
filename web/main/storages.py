from storages.backends.s3boto3 import S3Boto3Storage

from django.conf import settings

# used only for suppressing INFO logging in S3Boto3Storage
import logging


class S3Storage(S3Boto3Storage):
    # suppress boto3's INFO logging per https://github.com/boto/boto3/issues/521
    logging.getLogger('boto3').setLevel(logging.WARNING)
    logging.getLogger('botocore').setLevel(logging.WARNING)


def get_s3_storage(bucket_name='h2o.images'):
    # We're planning on supporting multiple storage solutions. I'm adding this
    # unnecessary layer of abstraction now, to hopefully encourage design decisions
    # that will make it easier to support multiple and customer-specific storages later.
    return S3Storage(
        **settings.S3_STORAGE,
        bucket_name=bucket_name
    )
