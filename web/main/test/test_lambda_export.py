"""Do not download Lambda failures as Word documents."""

from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import pytest

from main.models import Casebook
from main.utils import LambdaException, export_via_aws_lambda


def incomplete_docx():
    output = BytesIO()
    with ZipFile(output, "w") as archive:
        archive.writestr("word/document.xml", "<document/>")
    return output.getvalue()


@pytest.mark.parametrize("transport", ["stream", "url"])
@pytest.mark.parametrize("result", ["docx", "json_error", "incomplete_zip", "empty"])
def test_lambda_export_response(mocker, settings, transport, result):
    payloads = {
        "docx": Path(
            settings.BASE_DIR, "test/files/export/export-casebook-with-annotations.docx"
        ).read_bytes(),
        "json_error": b'{"errorMessage":"Undefined namespace prefix","errorType":"XPathEvalError"}',
        "incomplete_zip": incomplete_docx(),
        "empty": b"",
    }
    payload = payloads[result]
    config = dict(settings.AWS_LAMBDA_EXPORT_SETTINGS)
    if transport == "stream":
        config.update(function_arn="test", function_region="us-east-1", function_name="test")
        client = mocker.patch("main.utils.boto3.client").return_value
        client.invoke_with_response_stream.return_value = {
            "StatusCode": 200,
            "EventStream": [
                {"PayloadChunk": {"Payload": payload}},
                {"InvokeComplete": {}},
            ],
        }
    else:
        config.update(function_arn=None, function_url="http://lambda.test/")
        response = mocker.patch("main.utils.requests.post").return_value
        response.status_code = 200
        response.content = payload
        response.headers = {"content-type": "application/octet-stream"}
    settings.AWS_LAMBDA_EXPORT_SETTINGS = config
    storage = mocker.patch("main.utils.get_s3_storage").return_value
    casebook = Casebook(id=284)
    failed = mocker.patch.object(casebook, "inc_export_fails")
    reset = mocker.patch.object(casebook, "reset_export_fails")
    if result == "docx":
        assert export_via_aws_lambda(casebook, "<p>Example</p>", "docx") == payload
        failed.assert_not_called()
    else:
        with pytest.raises(LambdaException):
            export_via_aws_lambda(casebook, "<p>Example</p>", "docx")
        failed.assert_called_once_with()
        reset.assert_not_called()
    storage.delete.assert_called_once_with(storage.save.call_args.args[0])
