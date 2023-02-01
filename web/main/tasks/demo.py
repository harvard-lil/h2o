from celery import shared_task
from time import sleep

import logging

logger = logging.getLogger("celery.django")


### TASKS ###


@shared_task
def demo_scheduled_task(pause_for_seconds=0):
    """
    A demo task, scheduled to run once a minute dev. To see it in action,
    set CELERY_TASK_ALWAYS_EAGER = False in setting.py before running `fab run`.

    >>> caplog = getfixture('caplog')
    >>> settings = getfixture('settings')
    >>> settings.CELERY_TASK_ALWAYS_EAGER = True
    >>> with caplog.at_level(logging.DEBUG):
    ...     _ = demo_scheduled_task.apply_async(kwargs={'pause_for_seconds': 1})
    >>> assert 'Celerybeat is working!' in caplog.text
    """
    if pause_for_seconds:
        sleep(pause_for_seconds)
    return "Celerybeat is working!"
