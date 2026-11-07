"""Public media hosting excludes the authenticated stored-file directory."""
from pathlib import Path
from fastapi.staticfiles import StaticFiles

class PublicUploadsStaticFiles(StaticFiles):
    def lookup_path(self, path: str):
        full_path, stat_result = super().lookup_path(path)
        if stat_result is None:
            return full_path, stat_result
        resolved = Path(full_path).resolve()
        for directory in self.all_directories:
            private_root = (Path(directory) / "files").resolve()
            if resolved == private_root or private_root in resolved.parents:
                return "", None
        return full_path, stat_result
