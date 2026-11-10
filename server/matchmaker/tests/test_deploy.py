"""The deploy scripts without a box: syntax, argument checks and what a dry run says it would do."""
import os
import pwd
import subprocess
import unittest

from helpers import MM_DIR

DEPLOY = os.path.join(os.path.dirname(MM_DIR), "deploy")
INSTALL = os.path.join(DEPLOY, "install.sh")
PUSH = os.path.join(DEPLOY, "push.sh")


def sh(*args, env=None):
    done = subprocess.run(["bash", *args], capture_output=True, text=True, check=False, env=env)
    return done.returncode, done.stdout + done.stderr


class InstallTest(unittest.TestCase):
    def test_syntax(self):
        self.assertEqual(sh("-n", INSTALL)[0], 0)
        self.assertEqual(sh("-n", PUSH)[0], 0)

    def test_refuses_without_root_unless_dry(self):
        if os.geteuid() == 0:
            self.skipTest("running as root")
        code, out = sh(INSTALL, "--src", "/nonexistent")
        self.assertEqual(code, 1)
        self.assertIn("run as root", out)

    def test_dry_run_describes_the_whole_install(self):
        code, out = sh(INSTALL, "--dry-run", "--region", "us", "--public-host", "203.0.113.9", "--src", "/nonexistent")
        self.assertEqual(code, 0, out)
        useradd = "useradd --system --create-home --home-dir /opt/boki --shell /usr/sbin/nologin boki"
        try:
            pwd.getpwnam("boki")
            self.assertNotIn(useradd, out)   # already there (this dev box): a re-run keeps the user
        except KeyError:
            self.assertIn(useradd, out)
        for expected in (
            "mkdir -p /opt/boki/server /opt/boki/matchmaker /etc/boki",
            "apt-get install -y -qq python3",
            "write /etc/boki/matchmaker.env (mode 640)",
            "set /etc/boki/matchmaker.env: REGION=us",
            "set /etc/boki/matchmaker.env: PUBLIC_HOST=203.0.113.9",
            "write /etc/systemd/system/boki-matchmaker.service",
            "User=boki",
            "Restart=always",
            "EnvironmentFile=/etc/boki/matchmaker.env",
            "ExecStart=/usr/bin/python3 /opt/boki/matchmaker/matchmaker.py",
            "StandardOutput=journal",
            "ufw allow 22/tcp",
            "ufw allow 8080/tcp",
            "ufw allow 7777:7799/udp",
            "ufw --force enable",
            "systemctl enable boki-matchmaker.service",
            "systemctl restart boki-matchmaker.service",
        ):
            self.assertIn(expected, out, expected)

    def test_dry_run_copies_the_uploaded_files(self):
        src = os.path.dirname(MM_DIR)   # server/: has a matchmaker/ dir, no server/ build dir
        code, out = sh(INSTALL, "--dry-run", "--src", src)
        self.assertEqual(code, 0, out)
        self.assertIn(f"rsync -a --delete --exclude __pycache__ {src}/matchmaker/ /opt/boki/matchmaker/", out)
        self.assertIn("keeping the installed game server build", out)
        self.assertIn("SERVER_CMD left as is", out)

    def test_unknown_argument_fails(self):
        self.assertEqual(sh(INSTALL, "--dry-run", "--bogus")[0], 2)


class PushTest(unittest.TestCase):
    def test_usage_errors(self):
        self.assertEqual(sh(PUSH)[0], 2)
        self.assertEqual(sh(PUSH, "203.0.113.9")[0], 2)
        self.assertEqual(sh(PUSH, "203.0.113.9", "asia", "--dry-run")[0], 2)
        self.assertEqual(sh(PUSH, "203.0.113.9", "eu", "/nonexistent-build", "--dry-run")[0], 2)

    def test_dry_run_uses_the_deploy_key_and_installs_remotely(self):
        env = dict(os.environ, HOME="/home/tester")
        code, out = sh(PUSH, "203.0.113.9", "eu", DEPLOY, "--dry-run", env=env)
        self.assertEqual(code, 0, out)
        self.assertIn("ssh -i /home/tester/.ssh/boki_s2_deploy", out)
        self.assertIn("root@203.0.113.9 mkdir -p /opt/boki/upload", out)
        self.assertIn("matchmaker/ root@203.0.113.9:/opt/boki/upload/matchmaker/", out)
        self.assertIn(f"{DEPLOY}/ root@203.0.113.9:/opt/boki/upload/server/", out)
        self.assertIn("bash /opt/boki/upload/install.sh --region eu --public-host 203.0.113.9", out)
        self.assertIn("curl -fsS --max-time 10 http://203.0.113.9:8080/health", out)
        self.assertNotIn("upload/server/", sh(PUSH, "203.0.113.9", "eu", "--dry-run", env=env)[1])


if __name__ == "__main__":
    unittest.main()
