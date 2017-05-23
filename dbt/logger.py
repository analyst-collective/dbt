import dbt.clients.system
import logging
import os
import sys

import colorama

# disable logs from other modules, excepting CRITICAL logs
logging.getLogger('botocore').setLevel(logging.CRITICAL)
logging.getLogger('contracts').setLevel(logging.CRITICAL)
logging.getLogger('requests').setLevel(logging.CRITICAL)
logging.getLogger('urllib3').setLevel(logging.CRITICAL)
logging.getLogger('snowflake.connector').setLevel(logging.CRITICAL)

if sys.platform == 'win32' and not os.environ.get('TERM'):
    colorama.init(wrap=False)
    stdout = colorama.AnsiToWin32(sys.stdout).stream
else:
    colorama.init()
    stdout = sys.stdout


# create a global console logger for dbt
stdout_handler = logging.StreamHandler(stdout)
stdout_handler.setFormatter(logging.Formatter('%(message)s'))
stdout_handler.setLevel(logging.INFO)

logger = logging.getLogger()
logger.addHandler(stdout_handler)
logger.setLevel(logging.DEBUG)

initialized = False


def make_log_dir_if_missing(log_dir):
    dbt.clients.system.make_directory(log_dir)


def initialize_logger(debug_mode=False, path=None):
    global initialized, logger, stdout_handler

    if initialized:
        return

    if debug_mode:
        stdout_handler.setFormatter(
            logging.Formatter('%(asctime)-18s: %(message)s'))
        stdout_handler.setLevel(logging.DEBUG)

    if path is not None:
        make_log_dir_if_missing(path)
        log_path = os.path.join(path, 'dbt.log')

        # log to directory as well
        logdir_handler = logging.handlers.TimedRotatingFileHandler(
            filename=log_path,
            when='d',
            interval=1,
            backupCount=7,
        )

        logdir_handler.setFormatter(
            logging.Formatter('%(asctime)-18s: %(message)s'))
        logdir_handler.setLevel(logging.DEBUG)

        logger.addHandler(logdir_handler)

    initialized = True


GLOBAL_LOGGER = logger
