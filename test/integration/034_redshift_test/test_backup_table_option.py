import os

from test.integration.base import DBTIntegrationTest, use_profile


class TestBackupTableOption(DBTIntegrationTest):
    @property
    def schema(self):
        return 'backup_table_option_034'

    @staticmethod
    def dir(path):
        return os.path.normpath(path)

    @property
    def models(self):
        return self.dir("models_backup")

    @property
    def project_config(self):
        return {
            'config-version': 2,
            'data-paths': [self.dir('seed')],
            'seeds': {
                'quote_columns': False,
            }
        }

    def project_config_append(self, new_name, new_element):
        self._project_config[new_name] = new_element

    def check_backup_param_template(self, test_table_name, backup_is_expected):
        # Use raw DDL statement to confirm backup is set correctly on new table
        with open('target/run/test/models_backup/{}.sql'.format(test_table_name), 'r') as ddl_file:
            ddl_statement = ddl_file.readlines()
            self.assertEqual('backup no' not in ' '.join(ddl_statement).lower(), backup_is_expected)
        # Use information schema to confirm backup is set correctly on new table (0 if BACKUP NO is present)
        if 'view' not in test_table_name:
            check = "select distinct backup from stv_tbl_perm where name = '{}'".format(test_table_name)
            info_schema_result = self.run_sql(check, fetch='all')
            self.assertEqual(info_schema_result[0][0], int(backup_is_expected))
            self.assertEqual(len(info_schema_result), 1)

    @use_profile('redshift')
    def test__redshift_backup_table_option(self):
        self.assertEqual(len(self.run_dbt(["seed"])), 1)
        self.assertEqual(len(self.run_dbt()), 4)

        # model_backup_undefined should not contain a BACKUP NO parameter in the table DDL
        self.check_backup_param_template('model_backup_undefined', True)

        # model_backup_true should not contain a BACKUP NO parameter in the table DDL
        self.check_backup_param_template('model_backup_true', True)

        # model_backup_false should contain a BACKUP NO parameter in the table DDL
        self.check_backup_param_template('model_backup_false', False)

        # Any view should not contain a BACKUP NO parameter, regardless of the specified config (create will fail)
        self.check_backup_param_template('model_backup_true_view', True)
