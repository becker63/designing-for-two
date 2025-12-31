# lib/kcl_runtime/context.py

import shutil
from contextlib import contextmanager
from pathlib import Path
from threading import Lock
from typing import Any, Generator, Mapping, Optional

from google.protobuf.json_format import MessageToDict
from kcl_lib import api as bapi
from kcl_lib.api import ExecProgramResult, UpdateDependenciesArgs
from kcl_lib.api.spec_pb2 import OverrideFileResult

# -------------------------------------------------
# KCL root discovery
# -------------------------------------------------


def find_kcl_root(start: Path | None = None) -> Path:
    current = (start or Path(__file__)).resolve()
    if current.is_file():
        current = current.parent

    while True:
        if (current / "kcl.mod").exists():
            return current
        if current.parent == current:
            raise RuntimeError("Could not find KCL root (missing kcl.mod)")
        current = current.parent


KCL_ROOT: Path = find_kcl_root()


# -------------------------------------------------
# KCL Context Singleton
# -------------------------------------------------


class KCLContext:
    _instance: Optional["KCLContext"] = None
    _lock: Lock = Lock()

    def __init__(self) -> None:
        if getattr(self, "_initialized", False):
            return

        self.api: bapi.API = bapi.API()

        deps_args = UpdateDependenciesArgs(manifest_path=str(KCL_ROOT))
        deps_result = self.api.update_dependencies(deps_args)

        self.external_pkgs = deps_result.external_pkgs
        self._initialized = True

    @classmethod
    def instance(cls) -> "KCLContext":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance


# -------------------------------------------------
# Execution helpers
# -------------------------------------------------


def Exec(path: Path) -> ExecProgramResult:
    ctx = KCLContext.instance()
    exec_args = bapi.ExecProgramArgs(
        k_filename_list=[str(path.absolute())],
        external_pkgs=ctx.external_pkgs,
    )
    result = ctx.api.exec_program(exec_args)
    if result.err_message:
        raise RuntimeError(f"KCL execution failed:\n{result.err_message}")
    return result


def Override(path: Path, specs: list[str]) -> OverrideFileResult:
    ctx = KCLContext.instance()
    return ctx.api.override_file(
        bapi.OverrideFileArgs(
            file=str(path.absolute()),
            specs=specs,
        )
    )


@contextmanager
def Override_file_tmp_multi(
    overrides: Mapping[Path, list[str]],
) -> Generator[dict[Path, OverrideFileResult], None, None]:
    backups: dict[Path, Path] = {}

    for path in overrides:
        backup = path.with_suffix(path.suffix + ".bak")
        shutil.copy2(path, backup)
        backups[path] = backup

    try:
        results = {path: Override(path, specs) for path, specs in overrides.items()}
        yield results
    finally:
        for path, backup in backups.items():
            shutil.move(backup, path)


def ListVariables(path: Path) -> dict[str, Any]:
    ctx = KCLContext.instance()
    args = bapi.ListVariablesArgs(files=[str(path)])
    return MessageToDict(ctx.api.list_variables(args))
