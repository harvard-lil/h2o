"""
    This file contains helpers for the permissions tests in test_permissions.py. These can't go in test_permissions.py
    without causing a circular import, as they need to be imported from views.py and urls.py and that file needs to
    inspect urls.py during test setup.
"""

# test configs for use in @perms_test
viewable_section = [
    {'args': ['full_casebook', 'full_casebook.sections.first'], 'results': {200: [None, 'other_user', 'full_casebook.testing_editor']}},
    {'args': ['full_private_casebook', 'full_private_casebook.sections.first'], 'results': {200: ['full_private_casebook.testing_editor'], 'login': [None], 403: ['other_user']}},
    {'args': ['full_casebook_with_draft.draft', 'full_casebook_with_draft.draft.sections.first'], 'results': {200: ['full_casebook_with_draft.draft.testing_editor'], 'login': [None], 403: ['other_user']}},
]
directly_editable_section = [
    {'args': ['full_casebook', 'full_casebook.sections.first'], 'results': {403: ['other_user', 'full_casebook.testing_editor'], 'login': [None]}},
    {'args': ['full_private_casebook', 'full_private_casebook.sections.first'], 'results': {200: ['full_private_casebook.testing_editor'], 'login': [None], 403: ['other_user']}},
    {'args': ['full_casebook_with_draft.draft', 'full_casebook_with_draft.draft.sections.first'], 'results': {200: ['full_casebook_with_draft.draft.testing_editor'], 'login': [None], 403: ['other_user']}},
]
viewable_resource = [
    {'args': ['full_casebook', 'full_casebook.resources.first'], 'results': {200: [None, 'other_user', 'full_casebook.testing_editor']}},
    {'args': ['full_private_casebook', 'full_private_casebook.resources.first'], 'results': {200: ['full_private_casebook.testing_editor'], 'login': [None], 403: ['other_user']}},
    {'args': ['full_casebook_with_draft.draft', 'full_casebook_with_draft.draft.resources.first'], 'results': {200: ['full_casebook_with_draft.draft.testing_editor'], 'login': [None], 403: ['other_user']}},
]
directly_editable_resource = [
    {'args': ['full_casebook', 'full_casebook.resources.first'], 'results': {403: ['other_user', 'full_casebook.testing_editor'], 'login': [None]}},
    {'args': ['full_private_casebook', 'full_private_casebook.resources.first'], 'results': {200: ['full_private_casebook.testing_editor'], 'login': [None], 403: ['other_user']}},
    {'args': ['full_casebook_with_draft.draft', 'full_casebook_with_draft.draft.resources.first'], 'results': {200: ['full_casebook_with_draft.draft.testing_editor'], 'login': [None], 403: ['other_user']}},
]
patch_directly_editable_resource = [
    {'method': 'patch', 'args': ['full_casebook', 'full_casebook.resources.first'], 'results': {403: ['other_user', 'full_casebook.testing_editor'], 'login': [None]}},
    {'method': 'patch', 'args': ['full_private_casebook', 'full_private_casebook.resources.first'], 'results': {400: ['full_private_casebook.testing_editor'], 'login': [None], 403: ['other_user']}},
    {'method': 'patch', 'args': ['full_casebook_with_draft.draft', 'full_casebook_with_draft.draft.resources.first'], 'results': {400: ['full_casebook_with_draft.draft.testing_editor'], 'login': [None], 403: ['other_user']}},
]
# for annotations: args = resource ID rather than casebook and ordinals
post_directly_editable_resource = [
    {'method': 'post', 'args': ['full_casebook.resources.first'], 'results': {403: ['other_user', 'full_casebook.testing_editor'], 'login': [None]}},
    {'method': 'post', 'args': ['full_private_casebook.resources.first'], 'results': {400: ['full_private_casebook.testing_editor'], 'login': [None], 403: ['other_user']}},
    {'method': 'post', 'args': ['full_casebook_with_draft.draft.resources.first'], 'results': {400: ['full_casebook_with_draft.draft.testing_editor'], 'login': [None], 403: ['other_user']}},
]


def perms_test(*config):
    """
        View decorator that attaches a test config to the view for later use by test_permissions.
    """
    def decorator(func):
        func.perms_test = config[0] if type(config[0]) is list else config
        return func
    return decorator


def no_perms_test(func):
    """
        View decorator that attaches an empty test config.
    """
    func.perms_test = []
    return func
