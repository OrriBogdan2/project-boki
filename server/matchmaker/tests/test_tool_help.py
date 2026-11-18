"""Every Python tool with a command line answers --help (tools/py_help_check.py)."""
import os
import subprocess
import sys
import unittest

CHECK = os.path.join(os.path.dirname(__file__), "..", "..", "..", "tools", "py_help_check.py")


class ToolHelpTest(unittest.TestCase):
    def test_every_tool_answers_help(self):
        r = subprocess.run([sys.executable, CHECK], capture_output=True, text=True, timeout=600)
        self.assertEqual(r.returncode, 0, r.stdout[-2000:])


if __name__ == "__main__":
    unittest.main()
