import sys
import unittest

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from commit_email_guard import problem


class EmailGuard(unittest.TestCase):
    def test_allowed(self):
        for e in (
            "noreply@anthropic.com",
            "noreply@github.com",
            "orribogdan@gmail.com",
            "OrriBogdan2@users.noreply.github.com",
            "12345+OrriBogdan2@users.noreply.github.com",
            "regate-bot@localhost",
            "merge-autoresolve@local",
            "orri@projectboki.com",
        ):
            self.assertEqual(problem(e), "", e)

    def test_rejected(self):
        for e in (
            "coord@users.noreply.github.com",
            "99+coord@users.noreply.github.com",
            "x@gmail.com",
            "corybogdan@gmail.com",
            "orri@vaelabs.com",
            "a@outlook.com",
            "a@evilusers.noreply.github.com.com",
        ):
            self.assertNotEqual(problem(e), "", e)


if __name__ == "__main__":
    unittest.main()
