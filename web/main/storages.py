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

    @property
    def connection(self):
        """
        Hang on to the session object when connecting, in case we want to reuse it.
        For example, this is useful when interacting with AWS locally when MFA is required.

        If S3Boto3Storage.connection changes at all during upgrades, we should make this method match.
        >>> from inspect import getsource
        >>> expected = "    @property\\n    def connection(self):\\n        connection = getattr(self._connections, 'connection', None)\\n        if connection is None:\\n            session = self._create_session()\\n            self._connections.connection = session.resource(\\n                's3',\\n                region_name=self.region_name,\\n                use_ssl=self.use_ssl,\\n                endpoint_url=self.endpoint_url,\\n                config=self.config,\\n                verify=self.verify,\\n            )\\n        return self._connections.connection\\n"
        >>> assert getsource(S3Boto3Storage.connection.fget) == expected
        """
        connection = getattr(self._connections, 'connection', None)
        if connection is None:
            session = self._create_session()
            self._connections.connection = session.resource(
                's3',
                region_name=self.region_name,
                use_ssl=self.use_ssl,
                endpoint_url=self.endpoint_url,
                config=self.config,
                verify=self.verify,
            )
            self._connections.connection.session = session
        return self._connections.connection

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



def get_s3_storage(bucket_name='h2o.images', storage_settings=None):
    # We're planning on supporting multiple storage solutions. I'm adding this
    # unnecessary layer of abstraction now, to hopefully encourage design decisions
    # that will make it easier to support multiple and customer-specific storages later.
    if storage_settings is None:
        storage_settings = settings.S3_STORAGE
    return S3Storage(
        **storage_settings,
        bucket_name=bucket_name
    )
