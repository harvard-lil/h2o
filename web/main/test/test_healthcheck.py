from test.test_helpers import check_response


def test_healthcheck(client):
    check_response(client.get("/healthcheck/"), content_includes=["Running ✅!"])
