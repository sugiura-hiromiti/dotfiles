import os
from pathlib import Path
import subprocess
import tempfile
import sys
import unittest

SCRIPT = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).parents[2] / 'modules/nixos/features/impermanence/root-device.sh'


class RootDeviceTest(unittest.TestCase):
    def test_requires_exactly_one_matching_device(self):
        with tempfile.TemporaryDirectory() as directory:
            blkid = Path(directory) / 'blkid'
            blkid.write_text('#!/bin/sh\n[ "$*" = "-c /dev/null -t PARTLABEL=dotfiles-system -o device" ] || exit 9\nprintf "%s" "$DEVICES"\nexit "$STATUS"\n')
            blkid.chmod(0o755)
            for devices, status, expected in [('', '2', None), ('/dev/vda2\n', '0', '/dev/vda2\n'), ('/dev/vda2\n/dev/vdb2\n', '0', None), ('', '4', None)]:
                with self.subTest(devices=devices, status=status):
                    result = subprocess.run(['bash', str(SCRIPT), 'dotfiles-system'], env=os.environ | {'PATH': directory + ':' + os.environ['PATH'], 'DEVICES': devices, 'STATUS': status}, text=True, capture_output=True)
                    if expected is None:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertEqual(result.stdout, '')
                    else:
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stdout, expected)


if __name__ == '__main__':
    unittest.main()
