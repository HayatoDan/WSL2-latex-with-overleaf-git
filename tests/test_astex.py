"""Run with: python3 -m unittest discover -s tests -v"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class AstexTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="astex-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(REPO / "bin", self.root / "bin")
        self.projects = self.root / "projects"
        self.projects.mkdir()
        self.mocks = self.root / "mocks"
        self.mocks.mkdir()
        self.env = {**os.environ, "PATH": f"{self.mocks}:{os.environ['PATH']}"}

    def run_cli(self, *args, answer="", executable=None):
        return subprocess.run(
            [str(executable or self.root / "bin/astex"), *args],
            input=answer, text=True, capture_output=True, env=self.env,
            cwd=self.root, timeout=10,
        )

    def script(self, path, body):
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body + "\n")
        path.chmod(0o755)

    def project(self, name="paper-a"):
        path = self.projects / name
        (path / ".git").mkdir(parents=True)
        (path / "main.tex").write_text("local changes")
        return path

    def test_help(self):
        for args in [(), ("--help",), ("-h",), ("help",)] + [
            (command, "--help") for command in ("menu", "list", "newproj", "remove")
        ]:
            with self.subTest(args=args):
                result = self.run_cli(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Usage: astex", result.stdout)

    def test_invalid_arguments(self):
        project = self.project()
        for args in [("unknown",), ("list", "extra"), ("menu", "extra"),
                     ("newproj", "extra"), ("remove", "paper-a", "extra")]:
            with self.subTest(args=args):
                self.assertNotEqual(self.run_cli(*args, answer="y\n").returncode, 0)
                self.assertTrue(project.exists())

    def test_dispatch_and_symlink(self):
        link = self.root / "astex"
        link.symlink_to(self.root / "bin/astex")
        for command, script in [("menu", "latex-menu.sh"),
                                ("list", "latex-select.sh"),
                                ("newproj", "new-latex-project.sh")]:
            with self.subTest(command=command):
                self.script(self.root / "bin" / script, f"echo {command}; exit 7")
                result = self.run_cli(command, executable=link)
                self.assertEqual(result.returncode, 7)
                self.assertEqual(result.stdout.strip(), command)

    def test_remove_confirmed(self):
        for name in ["paper-a", "paper with spaces", "-paper", "論文"]:
            with self.subTest(name=name):
                project = self.project(name)
                other = self.projects / "keep"
                other.mkdir(exist_ok=True)
                result = self.run_cli("remove", name, answer="y\n")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(project.exists())
                self.assertTrue(other.exists())

    def test_remove_cancelled_or_eof(self):
        project = self.project()
        for answer in ["", "\n", "n\n", "yes\n"]:
            with self.subTest(answer=answer):
                result = self.run_cli("remove", "paper-a", answer=answer)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(project.exists())
                self.assertIn("Cancelled.", result.stdout)

    def test_reject_paths_and_missing_project(self):
        project = self.project()
        for name in ["", ".", "..", "../paper-a", str(project), "missing"]:
            with self.subTest(name=name):
                self.assertNotEqual(self.run_cli("remove", name, answer="y\n").returncode, 0)
                self.assertTrue(project.exists())

    def test_reject_symlinks(self):
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "keep").write_text("keep")
        link = self.projects / "linked"
        link.symlink_to(outside, target_is_directory=True)
        self.assertNotEqual(self.run_cli("remove", "linked", answer="y\n").returncode, 0)
        link.unlink()
        self.projects.rmdir()
        self.projects.symlink_to(outside, target_is_directory=True)
        self.assertNotEqual(self.run_cli("remove", "keep", answer="y\n").returncode, 0)
        self.assertTrue((outside / "keep").exists())

    def test_remove_selection_preserves_special_names(self):
        project = self.project("paper with\nnewline")
        self.script(self.mocks / "fzf", "cat")
        result = self.run_cli("remove", answer="y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(project.exists())

    def test_empty_projects_and_selection_cancel(self):
        self.assertEqual(self.run_cli("remove").returncode, 0)
        project = self.project()
        self.script(self.mocks / "fzf", "cat >/dev/null; exit 130")
        result = self.run_cli("remove", answer="y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(project.exists())

    def test_menu_remove(self):
        project = self.project()
        self.script(self.mocks / "fzf", '''
case "$*" in
    *--read0*) cat ;;
    *) cat >/dev/null; echo 'Remove local project' ;;
esac''')
        result = self.run_cli("menu", answer="y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(project.exists())


if __name__ == "__main__":
    unittest.main()
