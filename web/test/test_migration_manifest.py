"""Tests for the migration_manifest command.

The image build runs it to record the migration graph inside the built image
(see the Dockerfile), and a deploy compares that record against the same command
run elsewhere -- so the document's shape and its hash are the interface, not an
implementation detail.

Nothing here needs a database: the command loads migrations from disk.
"""

import json

import pytest
from django.core.management import call_command

from main.management.commands.migration_manifest import (
    FORMAT_VERSION,
    manifest,
    manifest_hash,
    migration_names,
)


@pytest.fixture
def real_migrations(settings):
    """Let the loader see the migrations that are actually on disk.

    The suite runs under --nomigrations, which pytest-django implements by
    replacing settings.MIGRATION_MODULES with a mapping returning None for every
    app. The loader then finds nothing on disk, which is the right answer for
    building a test database quickly and the wrong one for a command whose
    entire job is to report that graph.

    It is applied once for the whole session, not per test, so it reaches tests
    that never touch a database -- these among them. That is also why running
    this file on its own passes: nothing sets up the test environment, so
    nothing disables anything. The settings fixture restores it afterwards.
    """
    settings.MIGRATION_MODULES = {}


def test_migration_names_reach_beyond_this_repository(real_migrations):
    # Loading the graph from disk inside the built environment is what picks up
    # migrations shipped by installed packages, alongside the apps here.
    apps = {name.split(".")[0] for name in migration_names()}
    assert {"main", "reporting"} <= apps
    assert {"admin", "auth", "contenttypes", "sessions"} <= apps


def test_manifest_describes_its_own_list(real_migrations):
    document = manifest()
    # An empty graph satisfies every other assertion here, and is what a
    # misconfigured loader produces, so say out loud that there is something to
    # check rather than passing on nothing.
    assert document["count"] > 0
    assert document["format"] == FORMAT_VERSION
    assert document["count"] == len(document["migrations"])
    assert document["migrations"] == sorted(document["migrations"])
    assert document["hash"] == manifest_hash(document["migrations"])


def test_hash_distinguishes_different_migration_sets(real_migrations):
    names = migration_names()
    assert manifest_hash(names) != manifest_hash(names[:-1])


def test_command_writes_the_manifest_to_a_file(tmp_path, real_migrations):
    output = tmp_path / "migrations.json"
    call_command("migration_manifest", output=str(output))
    assert json.loads(output.read_text()) == manifest()
