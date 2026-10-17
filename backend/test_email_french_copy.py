"""Offline regression checks for French notification copy and email rendering."""
import ast
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).parent


def load_functions(relative, names):
    tree = ast.parse((ROOT / relative).read_text(encoding="utf-8"))
    nodes = [n for n in tree.body if isinstance(n, (ast.FunctionDef, ast.Import, ast.ImportFrom))
             and (not isinstance(n, ast.FunctionDef) or n.name in names)
             and not (isinstance(n, ast.ImportFrom) and (n.module or "").startswith("app"))]
    # Templates need only standard-library imports, their constants and functions.
    if relative.endswith("email_templates.py"):
        nodes = tree.body
    else:
        nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    namespace = {}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), relative, "exec"), namespace)
    return namespace


class FrenchEmailCopyTests(unittest.TestCase):
    def test_generated_notification_copy_has_no_known_unaccented_words(self):
        forbidden = re.compile(r"\b(ete|etre|reglement|appliquee|refuse|recu|liee|tache|ajoute|privee|reussi|confirme|annule|modifie|terminee|enregistre|assignee|bientot|echeance)\b")
        for path in (ROOT / "app").rglob("*.py"):
            tree = ast.parse(path.read_text(encoding="utf-8"))
            for node in ast.walk(tree):
                if not isinstance(node, ast.Call):
                    continue
                name = getattr(node.func, "id", "")
                if not ("notify" in name or "notification" in name or name == "enqueue_email_delivery"):
                    continue
                for keyword in node.keywords:
                    if keyword.arg not in {"title", "message", "body", "subject", "text_body"}:
                        continue
                    for literal in ast.walk(keyword.value):
                        if isinstance(literal, ast.Constant) and isinstance(literal.value, str):
                            self.assertIsNone(forbidden.search(literal.value), f"{path.name}:{node.lineno}: {literal.value}")

    def test_task_statuses_are_readable(self):
        label = load_functions("app/api/routes/tasks.py", {"task_status_label"})["task_status_label"]
        self.assertEqual(label("en_cours"), "en cours")
        self.assertEqual(label("bloque"), "bloquée")
        self.assertEqual(label("termine"), "terminée, en attente de validation")
        self.assertEqual(label("unknown_internal_status"), "mise à jour")

    def test_codes_preserve_digits_and_hide_generic_action(self):
        render = load_functions("app/services/email_templates.py", set())["render_email_html"]
        for code in ("123456", "01234567"):
            html = render("Activez votre accès", f"Votre code est {code}.")
            self.assertIn(code, html)
            self.assertIn("letter-spacing:7px", html)
            self.assertNotIn("Accéder à EnactSpace", html)

    def test_tracking_link_and_accents_are_preserved_and_html_is_escaped(self):
        render = load_functions("app/services/email_templates.py", set())["render_email_html"]
        html = render("Votre candidature est étudiée", "Réponse reçue : <script>é</script>")
        self.assertIn("/application-tracking", html)
        self.assertIn("Réponse reçue", html)
        self.assertIn("&lt;script&gt;é&lt;/script&gt;", html)
        self.assertNotIn("<script>", html)


if __name__ == "__main__":
    unittest.main()
