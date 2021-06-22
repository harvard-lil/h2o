from datetime import datetime
import posixpath
from storages.backends.s3boto3 import S3Boto3Storage

from django.conf import settings

# used only for suppressing INFO logging in S3Boto3Storage
import logging


class S3Storage(S3Boto3Storage):
    # suppress boto3's INFO logging per https://github.com/boto/boto3/issues/521
    logging.getLogger('boto3').setLevel(logging.WARNING)
    logging.getLogger('botocore').setLevel(logging.WARNING)

    def augmented_listdir(self, name):
        path = self._normalize_name(self._clean_name(name))
        # The path needs to end with a slash, but if the root is empty, leave
        # it.
        if path and not path.endswith('/'):
            path += '/'

        files = []
        paginator = self.connection.meta.client.get_paginator('list_objects')
        pages = paginator.paginate(Bucket=self.bucket_name, Delimiter='/', Prefix=path)
        for page in pages:
            for entry in page.get('Contents', ()):
                last_modified = entry.get('LastModified')
                age = datetime.now(last_modified.tzinfo) - last_modified
                files.append({'file_name': posixpath.relpath(entry['Key'], path),
                              'last_modified': last_modified,
                              'age': age})
        return files



def get_s3_storage(bucket_name='h2o.images'):
    # We're planning on supporting multiple storage solutions. I'm adding this
    # unnecessary layer of abstraction now, to hopefully encourage design decisions
    # that will make it easier to support multiple and customer-specific storages later.
    return S3Storage(
        **settings.S3_STORAGE,
        bucket_name=bucket_name
    )
