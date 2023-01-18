from celery import shared_task
from celery.signals import task_failure
import socket
from time import sleep

from django.core.mail import mail_admins

import logging

logger = logging.getLogger("celery.django")


### ERROR REPORTING ###


@task_failure.connect()
def celery_task_failure_email(**kwargs):
    """
    Celery 4.0+ has no method to send emails on failed tasks.
    This event handler provides equivalent functionality to Celery < 4.0,
    and reports truly failed tasks, like those terminated after CELERY_TASK_TIME_LIMIT
    and those that throw uncaught exceptions.
    From https://github.com/celery/celery/issues/3389

    Given:
    >>> mocker, _ = [getfixture(i) for i in ['mocker', 'celery_worker']]
    >>> sleep = mocker.patch('main.tasks.sleep')
    >>> mailer = mocker.patch('main.tasks.mail_admins')

    Patch the task so that it errors, and then run in:
    >>> sleep.side_effect = lambda seconds: 1/0
    >>> _ = demo_scheduled_task.apply_async(kwargs={'pause_for_seconds': 1})

    Wait for the task to execute and return (without using the patched copy of sleep)
    >>> import time; time.sleep(1)

    Observe that an error email was sent, as expected.
    >>> mailer.assert_called_once()
    """
    subject = "[{queue_name}@{host}] Error: Task {sender.name} ({task_id}): {exception}".format(
        queue_name="celery", host=socket.gethostname(), **kwargs
    )

    message = """Task {sender.name} with id {task_id} raised exception:
{exception!r}
Task was called with args: {args} kwargs: {kwargs}.
The contents of the full traceback was:
{einfo}
    """.format(
        **kwargs
    )
    mail_admins(subject, message)


### TASKS ###


@shared_task
def demo_scheduled_task(pause_for_seconds=0):
    """
    A demo task, scheduled to run once a minute dev. To see it in action,
    set CELERY_TASK_ALWAYS_EAGER = False in setting.py before running `fab run`.
    """
    if pause_for_seconds:
        sleep(pause_for_seconds)
    return "Celerybeat is working!"
