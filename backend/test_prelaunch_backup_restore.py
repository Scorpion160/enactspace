"""Restore safety checks with synthetic files; no production data in tests."""
import importlib.util,io,json,os,subprocess,tarfile,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location("backup",Path(__file__).parent/"app/scripts/prelaunch_backup_restore.py")
backup=importlib.util.module_from_spec(spec);spec.loader.exec_module(backup)

class BackupSafetyTests(unittest.TestCase):
    def archive(self,root,name,kind=tarfile.REGTYPE):
        target=root/"archive.tar.gz"
        with tarfile.open(target,"w:gz") as bundle:
            item=tarfile.TarInfo(name);item.type=kind
            if kind==tarfile.REGTYPE:item.size=4;bundle.addfile(item,io.BytesIO(b"test"))
            else:item.linkname="/outside";bundle.addfile(item)
        return target
    def test_normal_archive_restores_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);destination=root/"restored";destination.mkdir()
            backup.safe_extract(self.archive(root,"files/example.txt"),destination)
            self.assertEqual((destination/"files/example.txt").read_bytes(),b"test")
    def test_parent_and_absolute_archive_paths_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);destination=root/"restored";destination.mkdir()
            for name in ("../outside","/outside","files/../../outside"):
                with self.assertRaises(ValueError):backup.safe_extract(self.archive(root,name),destination)
            self.assertEqual(list(destination.iterdir()),[])
    def test_links_and_special_files_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);destination=root/"restored";destination.mkdir()
            for kind in (tarfile.SYMTYPE,tarfile.LNKTYPE,tarfile.CHRTYPE,tarfile.FIFOTYPE):
                with self.assertRaises(ValueError):backup.safe_extract(self.archive(root,"files/link",kind),destination)
    def test_filesystem_manifest_refuses_symlinks(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/"file").write_bytes(b"test");(root/"link").symlink_to(root/"file")
            with self.assertRaises(ValueError):backup.file_manifest(root)
    def test_unowned_restore_container_rejected_before_command(self):
        with patch.object(backup,"run") as call:
            with self.assertRaises(ValueError):backup.sql("enactspace_postgres","SELECT 1")
            with self.assertRaises(ValueError):backup.sql("another-live-db","SELECT 1",production=True)
            call.assert_not_called()
    def test_private_directory_created_with_restricted_mode(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)/"private";backup.private_directory(root)
            self.assertEqual(root.stat().st_mode&0o777,0o700)
            with self.assertRaises(FileExistsError):backup.private_directory(root)
    def test_hmac_is_order_independent_and_content_sensitive(self):
        first=backup.aggregate_manifest({"b":2,"a":1},b"synthetic-key")
        self.assertEqual(first,backup.aggregate_manifest({"a":1,"b":2},b"synthetic-key"))
        self.assertNotEqual(first,backup.aggregate_manifest({"a":2,"b":2},b"synthetic-key"))
        self.assertNotEqual(first,backup.aggregate_manifest({"a":1,"b":2},b"other-key"))
    def test_record_comparison_ignores_locale_order_but_keeps_business_array_order(self):
        a=[{"name":"Équipe","steps":["learn","do"]},{"name":"Equipe","steps":["do","learn"]}]
        self.assertEqual(backup.record_digest(a,b"k"),backup.record_digest(list(reversed(a)),b"k"))
        b=[dict(a[0],steps=["do","learn"]),a[1]]
        self.assertNotEqual(backup.record_digest(a,b"k"),backup.record_digest(b,b"k"))
    def resources(self):
        return {kind:backup.PREFIX+kind+"_20261008T092200Z_abcdef" for kind in ("pg","net","volume")}
    def test_cleanup_removes_container_left_by_failed_start(self):
        resources=self.resources()
        state={kind:{value} for kind,value in resources.items()}
        def names(kind):return set(state[kind])
        def remove(args,**kwargs):
            kind=next(k for k,v in resources.items() if v==args[-1])
            state[kind].remove(args[-1])
            return subprocess.CompletedProcess(args,0)
        with patch.object(backup,"resource_names",side_effect=names),patch.object(backup.subprocess,"run",side_effect=remove):
            self.assertTrue(backup.cleanup_owned(resources))
        self.assertTrue(all(not values for values in state.values()))
    def test_cleanup_cannot_touch_production_or_mixed_runs(self):
        resources=self.resources()
        with patch.object(backup,"resource_names") as call:
            with self.assertRaises(ValueError):backup.cleanup_owned(dict(resources,pg="enactspace_postgres"))
            with self.assertRaises(ValueError):backup.cleanup_owned(dict(resources,net=resources["net"].replace("abcdef","aaaaaa")))
            call.assert_not_called()
    def test_existing_resource_is_not_reused(self):
        resources=self.resources()
        with patch.object(backup,"resource_names",return_value={resources["pg"]}):
            with self.assertRaises(RuntimeError):backup.ensure_resources_absent(resources)
    def test_cleanup_failure_is_not_reported_as_success(self):
        resources=self.resources()
        with patch.object(backup,"resource_names",side_effect=lambda kind:{resources[kind]}),patch.object(backup.subprocess,"run",return_value=subprocess.CompletedProcess([],1)):
            self.assertFalse(backup.cleanup_owned(resources))
    def test_preexisting_resources_are_never_deleted_by_rehearsal(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);stage=root/"staging";stage.mkdir()
            with patch.object(backup,"KEY_ROOT",root/"keys"),patch.object(backup,"BACKUP_ROOT",root/"backups"), \
                 patch.object(backup,"STAGE_ROOT",stage),patch.object(backup,"ensure_resources_absent",side_effect=RuntimeError("existing")), \
                 patch.object(backup,"cleanup_owned") as cleanup,patch("sys.stdout",new_callable=io.StringIO):
                with self.assertRaises(SystemExit):backup.execute_rehearsal()
                cleanup.assert_not_called()
            self.assertEqual(list(stage.iterdir()),[])
    def test_schema_order_differs_without_losing_structural_checks(self):
        source={"tables":{},"sequences":"seq","constraints":"constraints","indexes":"indexes","revision":"revision",
            "raw_schema_order":{"constraints":"old-order","indexes":"old-order"}}
        restored=dict(source,raw_schema_order={"constraints":"new-order","indexes":"new-order"})
        self.assertEqual(backup.comparable_snapshot(source),backup.comparable_snapshot(restored))
        diagnostic=backup.snapshot_difference(source,restored)
        self.assertEqual(diagnostic["schema_order_only"],["constraints","indexes"])
        self.assertEqual(diagnostic["different_components"],[])
        changed=dict(restored,constraints="different-definition")
        self.assertNotEqual(backup.comparable_snapshot(source),backup.comparable_snapshot(changed))
        self.assertEqual(backup.snapshot_difference(source,changed)["different_components"],["constraints"])
    def test_reference_schema_preserves_data_and_every_definition_check(self):
        original={"tables":{"members":{"rows":2,"hmac":"rows"}},"sequences":"sequence",
            "revision":"revision","constraints":"old-rendering","indexes":"old-rendering",
            "columns":"columns","enums":"enums","views":"views","functions":"functions","triggers":"triggers"}
        reference={key:original[key] for key in ("constraints","indexes","columns","enums","views","functions","triggers")}
        reference.update(constraints="reparsed-full-constraint",indexes="reparsed-full-index")
        expected=backup.expected_restored_snapshot(original,reference)
        self.assertEqual(expected["tables"],original["tables"])
        self.assertEqual(expected["sequences"],original["sequences"])
        self.assertEqual(expected["revision"],original["revision"])
        for component in reference:
            changed=dict(expected,**{component:"different-definition"})
            self.assertNotEqual(backup.comparable_snapshot(changed),expected)
            self.assertIn(component,backup.snapshot_difference(expected,changed)["different_components"])
        with self.assertRaises(ValueError):backup.expected_restored_snapshot(original,{"unknown":"value"})
        with self.assertRaises(ValueError):backup.expected_restored_snapshot(original,dict(reference,sequences="wrong"))
        with self.assertRaises(ValueError):backup.expected_restored_snapshot(original,{"constraints":"partial"})
    def test_reference_database_guard_rejects_unowned_target(self):
        with patch.object(backup,"run") as call:
            with self.assertRaises(ValueError):backup.sql(self.resources()["pg"],"SELECT 1",database="production")
            with self.assertRaises(ValueError):backup.restore_dump("enactspace_postgres",Path("unused"))
            call.assert_not_called()

    def test_reference_write_cannot_target_production(self):
        with patch.object(backup,"run") as call:
            for name in ("enactspace_postgres",backup.PREFIX+"pg_invalid",backup.PREFIX+"volume_20261008T092200Z_abcdef"):
                with self.assertRaises(ValueError):backup.reference_sql(name,"CREATE TABLE example(x int)")
            call.assert_not_called()
        with patch.object(backup,"run") as call:
            backup.reference_sql(self.resources()["pg"],"SELECT 1")
            self.assertIn("enactspace_pr2b_test_schema",call.call_args[0][0])
            self.assertNotIn("enactspace_pr2b_test_restore",call.call_args[0][0])
    def test_revision_guard_is_checked_before_files_or_commands(self):
        with patch.object(backup,"run") as call:
            with self.assertRaises(ValueError):backup.execute_rehearsal("unexpected")
            call.assert_not_called()

if __name__=="__main__":unittest.main()
