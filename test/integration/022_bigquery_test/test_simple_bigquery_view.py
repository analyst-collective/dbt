from test.integration.base import DBTIntegrationTest, FakeArgs, use_profile
import random
import time

class TestBaseBigQueryRun(DBTIntegrationTest):

    @property
    def schema(self):
        return "bigquery_test_022"

    @property
    def models(self):
        return "models"

    @property
    def project_config(self):
        return {
            'data-paths': ['data'],
            'macro-paths': ['macros'],
        }

    @property
    def profile_config(self):
        return self.bigquery_profile()

    def assert_nondupes_pass(self):
        # The 'dupe' model should fail, but all others should pass
        test_results = self.run_dbt(['test'], expect_pass=False)

        for result in test_results:
            if 'dupe' in result.node.name:
                self.assertIsNone(result.error)
                self.assertFalse(result.skipped)
                self.assertTrue(result.status > 0)

            # assert that actual tests pass
            else:
                self.assertIsNone(result.error)
                self.assertFalse(result.skipped)
                # status = # of failing rows
                self.assertEqual(result.status, 0)


class TestSimpleBigQueryRun(TestBaseBigQueryRun):

    @use_profile('bigquery')
    def test__bigquery_simple_run(self):
        # make sure seed works twice. Full-refresh is a no-op
        self.run_dbt(['seed'])
        self.run_dbt(['seed', '--full-refresh'])
        results = self.run_dbt()
        self.assertEqual(len(results), 6)
        self.assert_nondupes_pass()


class TestUnderscoreBigQueryRun(TestBaseBigQueryRun):
    prefix = "_test{}{:04}".format(int(time.time()), random.randint(0, 9999))

    @use_profile('bigquery')
    def test_bigquery_run_twice(self):
        self.run_dbt(['seed'])
        results = self.run_dbt()
        self.assertEqual(len(results), 6)
        results = self.run_dbt()
        self.assertEqual(len(results), 6)
        self.assert_nondupes_pass()
