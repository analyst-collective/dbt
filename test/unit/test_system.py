import mock
import unittest

import dbt.clients.system


class SystemTest(unittest.TestCase):

    def test_make_directory(self):
        target = '/tmp/abc'

        dbt.clients.system.make_directory(target)

        with mock.patch('os.path.exists', return_value=False):
            dbt.clients.system.make_directory(target)
