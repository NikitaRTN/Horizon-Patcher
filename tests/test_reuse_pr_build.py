import hashlib
import tempfile
import json
import os
from unittest import mock
import reuse_pr_build as reuse_module
import unittest
from pathlib import Path
from reuse_pr_build import FIELDS, matches, trusted_pr, trusted_run


class ReuseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name)/'horizon-launcher.exe'
        self.path.write_bytes(b'MZtest')
        self.expected = dict(zip(FIELDS, ['owner/repo', 7, 'head', 123, 1, 'tree', 'upstream', 'official', '0.2.44', 'key']))
        self.manifest = self.expected | {'payload_sha256': hashlib.sha256(b'MZtest').hexdigest()}

    def tearDown(self): self.temp.cleanup()

    def test_matches_all_inputs_and_content(self):
        self.assertTrue(matches(self.manifest, self.expected, self.path))
        for field in FIELDS:
            with self.subTest(field=field):
                self.assertFalse(matches(self.manifest | {field: 'changed'}, self.expected, self.path))
        self.path.write_bytes(b'MZtampered')
        self.assertFalse(matches(self.manifest, self.expected, self.path))

    def test_rejects_missing_bad_and_non_executable_payloads(self):
        self.path.write_bytes(b'not executable')
        m = self.manifest | {'payload_sha256': hashlib.sha256(b'not executable').hexdigest()}
        self.assertFalse(matches(m, self.expected, self.path))
        self.path.unlink()
        self.assertFalse(matches(self.manifest, self.expected, self.path))
        self.assertFalse(matches({}, self.expected, self.path))

    def test_only_merged_same_repository_pr(self):
        pr={'state':'closed','merged_at':'date','merge_commit_sha':'merged', 'base':{'repo':{'full_name':'owner/repo'}},'head':{'sha':'head','repo':{'full_name':'owner/repo'}}}
        self.assertTrue(trusted_pr(pr,'owner/repo','merged'))
        self.assertFalse(trusted_pr(pr,'owner/repo','other'))
        self.assertFalse(trusted_pr(pr | {'merged_at':None},'owner/repo','merged'))
        self.assertFalse(trusted_pr(pr | {'head':{'sha':'head','repo':{'full_name':'fork/repo'}}},'owner/repo','merged'))
        self.assertFalse(trusted_pr(pr | {'head':{'sha':'head','repo':None}},'owner/repo','merged'))

    def test_only_successful_same_repository_expected_workflow(self):
        run={'event':'pull_request','status':'completed','conclusion':'success','head_sha':'head','head_repository':{'full_name':'owner/repo'},'repository':{'full_name':'owner/repo'},'path':'.github/workflows/build.yml','id':123,'run_attempt':1}
        self.assertTrue(trusted_run(run,'owner/repo','head'))
        for key, value in [('event','push'),('status','in_progress'),('conclusion','failure'),('head_sha','other'),('path','.github/workflows/evil.yml'),('head_repository',{'full_name':'fork/repo'}),('repository',{'full_name':'fork/repo'}),('id','123')]:
            with self.subTest(key=key): self.assertFalse(trusted_run(run | {key:value},'owner/repo','head'))


class EndToEndReuseTests(unittest.TestCase):
    def test_successful_pr_artifact_is_reused_and_mismatch_falls_back(self):
        pr = {'number':7,'state':'closed','merged_at':'date','merge_commit_sha':'merged',
              'base':{'repo':{'full_name':'owner/repo'}},'head':{'sha':'head','repo':{'full_name':'owner/repo'}}}
        run = {'event':'pull_request','status':'completed','conclusion':'success','head_sha':'head',
               'head_repository':{'full_name':'owner/repo'},'repository':{'full_name':'owner/repo'},
               'path':'.github/workflows/build.yml','id':123,'run_attempt':1}
        common = {'repository':'owner/repo','tree':'tree','upstream_commit':'upstream',
                  'official_sha256':'official','launcher_version':'0.2.44','launcher_key':'key'}
        info = common | {'pr_number':7,'pr_head':'head','run_id':123,'run_attempt':1,
                         'payload_sha256':hashlib.sha256(b'MZtest').hexdigest()}
        with tempfile.TemporaryDirectory() as root:
            old=os.getcwd(); os.chdir(root)
            try:
                def download(args, **kwargs):
                    dst=Path(args[args.index('--dir')+1]); (dst/'horizon-launcher.exe').write_bytes(b'MZtest')
                    (dst/'manifest.json').write_text(json.dumps(info),encoding='utf-8')
                    return mock.Mock(returncode=0)
                with mock.patch.dict(os.environ, {'GITHUB_REPOSITORY':'owner/repo','GITHUB_SHA':'merged'}), \
                     mock.patch.object(reuse_module,'api',side_effect=[[pr],{'workflow_runs':[run]}]), \
                     mock.patch.object(reuse_module,'common',return_value=common), \
                     mock.patch.object(reuse_module.subprocess,'run',side_effect=download):
                    self.assertTrue(reuse_module.reuse())
                    self.assertEqual(Path('cached-launcher/horizon-launcher.exe').read_bytes(),b'MZtest')
                Path('cached-launcher/horizon-launcher.exe').unlink()
                info['tree']='wrong'
                with mock.patch.dict(os.environ, {'GITHUB_REPOSITORY':'owner/repo','GITHUB_SHA':'merged'}), \
                     mock.patch.object(reuse_module,'api',side_effect=[[pr],{'workflow_runs':[run]}]), \
                     mock.patch.object(reuse_module,'common',return_value=common), \
                     mock.patch.object(reuse_module.subprocess,'run',side_effect=download):
                    self.assertFalse(reuse_module.reuse())
                    self.assertFalse(Path('cached-launcher/horizon-launcher.exe').exists())
            finally: os.chdir(old)

    def test_github_failure_fails_closed(self):
        with tempfile.TemporaryDirectory() as root:
            output=Path(root)/'output'
            with mock.patch.dict(os.environ, {'GITHUB_OUTPUT':str(output)}), \
                 mock.patch.object(reuse_module,'reuse',side_effect=OSError('offline')), \
                 mock.patch.object(reuse_module.sys,'argv',['reuse_pr_build.py','reuse']):
                reuse_module.main()
            self.assertEqual(output.read_text(encoding='utf-8'),'reused=false\n')

if __name__ == '__main__': unittest.main()
