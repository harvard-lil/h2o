import boto3
import os
import subprocess
import tempfile


def handler(event, context):

    input_s3_key = event['filename']
    is_casebook = event['is_casebook']

    s3_config = {}
    if os.environ.get('USE_S3_CREDENTIALS'):
        s3_config['endpoint_url'] = os.environ['S3_ENDPOINT_URL']
        s3_config['aws_access_key_id'] = os.environ['AWS_ACCESS_KEY_ID']
        s3_config['aws_secret_access_key'] = os.environ['AWS_SECRET_ACCESS_KEY']

    with tempfile.NamedTemporaryFile(suffix='.docx') as pandoc_in:

        # get the source html
        s3 = boto3.resource('s3', **s3_config)
        s3.Bucket(os.environ['EXPORT_BUCKET']).download_fileobj(input_s3_key, pandoc_in)
        pandoc_in.seek(0)

        # convert to docx with pandoc
        with tempfile.NamedTemporaryFile(suffix='.docx') as pandoc_out:
            command = [
                'pandoc',
                '--from', 'html',
                '--to', 'docx',
                '--reference-doc', 'reference.docx',
                '--output', pandoc_out.name,
                '--quiet'
            ]
            if is_casebook:
                command.extend(['--lua-filter', 'table_of_contents.lua'])
            try:
                response = subprocess.run(command, input=pandoc_in.read(), stderr=subprocess.PIPE,
                                          stdout=subprocess.PIPE)
            except subprocess.CalledProcessError as e:
                raise Exception(f"Pandoc command failed: {e.stderr[:100]}")
            if response.stderr:
                raise Exception(f"Pandoc reported error: {response.stderr[:100]}")
            return pandoc_out.read()
