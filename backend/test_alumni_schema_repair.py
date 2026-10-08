import unittest, importlib.util
from pathlib import Path
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

class AlumniSchemaRepairTests(unittest.TestCase):
    def migration(self):
        path=Path(__file__).parent/'alembic/versions/20261006_0024_repair_alumni_join_year.py'
        spec=importlib.util.spec_from_file_location('alumni_repair',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        return module

    def test_repairs_stamped_database_without_touching_historical_rows(self):
        module=self.migration()
        engine=sa.create_engine('sqlite://')
        with engine.begin() as conn:
            conn.exec_driver_sql('CREATE TABLE alumni_profiles (id INTEGER PRIMARY KEY, user_id TEXT, graduation_year INTEGER, experience_summary TEXT)')
            conn.exec_driver_sql("INSERT INTO alumni_profiles VALUES (1, 'old-member', 2020, 'Parcours conservé')")
            with Operations.context(MigrationContext.configure(conn)):
                module.upgrade();module.upgrade()
                self.assertEqual(tuple(conn.exec_driver_sql('SELECT * FROM alumni_profiles').one()),(1,'old-member',2020,'Parcours conservé',None))
                conn.exec_driver_sql('UPDATE alumni_profiles SET enactus_join_year=2017')
                module.downgrade()
                self.assertEqual(conn.exec_driver_sql('SELECT enactus_join_year FROM alumni_profiles').scalar(),2017)
                module.upgrade()
                self.assertEqual(conn.exec_driver_sql('SELECT enactus_join_year FROM alumni_profiles').scalar(),2017)
        engine.dispose()

    def test_existing_year_is_never_overwritten(self):
        module=self.migration()
        engine=sa.create_engine('sqlite://')
        with engine.begin() as conn:
            conn.exec_driver_sql('CREATE TABLE alumni_profiles (id INTEGER PRIMARY KEY, enactus_join_year INTEGER)')
            conn.exec_driver_sql('INSERT INTO alumni_profiles VALUES (1, 2019)')
            with Operations.context(MigrationContext.configure(conn)):
                module.upgrade();module.downgrade()
                self.assertEqual(tuple(conn.exec_driver_sql('SELECT * FROM alumni_profiles').one()),(1,2019))
        engine.dispose()


# PostgreSQL uses a dedicated test database and a unique, disposable schema.
import os,uuid
@unittest.skipUnless(os.environ.get('VEILLE_TEST_POSTGRESQL_URL'),'Dedicated PostgreSQL test URL not provided')
class AlumniSchemaRepairPostgresqlTests(unittest.TestCase):
    def test_postgresql_additive_repair_and_existing_year_preservation(self):
        url=os.environ['VEILLE_TEST_POSTGRESQL_URL'].replace('postgresql://','postgresql+psycopg://',1)
        engine=sa.create_engine(url)
        schema='alumni_repair_'+uuid.uuid4().hex
        try:
            with engine.begin() as conn:
                conn.exec_driver_sql('CREATE SCHEMA "'+schema+'"')
                conn.exec_driver_sql('SET LOCAL search_path TO "'+schema+'"')
                conn.exec_driver_sql('CREATE TABLE alumni_profiles (id INTEGER PRIMARY KEY, experience_summary TEXT)')
                conn.exec_driver_sql("INSERT INTO alumni_profiles VALUES (1, 'Mémoire conservée')")
                module=AlumniSchemaRepairTests().migration()
                with Operations.context(MigrationContext.configure(conn)):
                    module.upgrade();module.upgrade()
                    self.assertEqual(tuple(conn.exec_driver_sql('SELECT * FROM alumni_profiles').one()),(1,'Mémoire conservée',None))
                    conn.exec_driver_sql('UPDATE alumni_profiles SET enactus_join_year=2018')
                    module.downgrade();module.upgrade()
                    self.assertEqual(conn.exec_driver_sql('SELECT enactus_join_year FROM alumni_profiles').one()._mapping['enactus_join_year'],2018)
        finally:
            with engine.begin() as conn:
                conn.exec_driver_sql('DROP SCHEMA IF EXISTS "'+schema+'" CASCADE')
            engine.dispose()

class SchemaValidationTests(unittest.TestCase):
    def test_detects_missing_columns_despite_current_migration_stamp(self):
        from app.db.schema_validation import schema_gaps
        engine=sa.create_engine('sqlite://')
        metadata=sa.MetaData()
        sa.Table('alumni_profiles',metadata,sa.Column('id',sa.Integer,primary_key=True),sa.Column('enactus_join_year',sa.Integer))
        sa.Table('mentorships',metadata,sa.Column('id',sa.Integer,primary_key=True))
        with engine.begin() as conn:
            conn.exec_driver_sql('CREATE TABLE alumni_profiles (id INTEGER PRIMARY KEY)')
            conn.exec_driver_sql('CREATE TABLE alembic_version (version_num TEXT)')
            conn.exec_driver_sql("INSERT INTO alembic_version VALUES ('20261006_0023')")
            result=schema_gaps(conn,metadata)
            self.assertEqual(result['missing_tables'],['mentorships'])
            self.assertEqual(result['missing_columns'],[{'table':'alumni_profiles','column':'enactus_join_year'}])
            metadata.create_all(conn)
            with Operations.context(MigrationContext.configure(conn)):
                AlumniSchemaRepairTests().migration().upgrade()
            result=schema_gaps(conn,metadata)
            self.assertEqual(result['missing_tables'],[])
            self.assertEqual(result['missing_columns'],[])
        engine.dispose()

if __name__=='__main__':unittest.main()
