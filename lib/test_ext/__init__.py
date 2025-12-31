from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import (
    Any,
    Callable,
    Iterable,
    List,
    Optional,
    ParamSpec,
    Sequence,
    TypeAlias,
    TypeVar,
    cast,
)

from pydantic import BaseModel, ConfigDict


class KFile(BaseModel):
    path: Path
    model_config = ConfigDict(frozen=True)


KclFilterFn = Callable[[KFile], bool]

TestCase: TypeAlias = Any  # e.g. pytest.param(...)

F = TypeVar("F", bound=Callable[..., object])
P = ParamSpec("P")


# ----------------------------
# Decorator API (MUST remain stable)
# ----------------------------


def make_kcl_test(filter_fn: Callable[[KFile], bool]) -> Callable[[F], F]:
    """
    Decorate a test function to run once per KCL file that matches filter_fn.
    Conftest will look for attribute: _kcl_filter_fn
    """

    def decorator(test_func: F) -> F:
        test_func._kcl_filter_fn = filter_fn  # type: ignore[attr-defined]
        return test_func

    return decorator


def make_kcl_named_test(
    filenames: list[str],
    filter_fn: Callable[[KFile], bool],
) -> Callable[[F], F]:
    """
    Decorate a test function to run once with an explicit named group of files.
    Conftest will look for attributes:
      - _kcl_group_filenames
      - _kcl_group_filter
    """

    def decorator(func: F) -> F:
        setattr(func, "_kcl_group_filenames", filenames)
        setattr(func, "_kcl_group_filter", filter_fn)
        return func

    return decorator


# ----------------------------
# Project-root discovery (no static path constants)
# ----------------------------


def find_project_root(start: Path | None = None) -> Path:
    """
    Walk upward until we find flake.nix. This is *not* "configuration",
    it is just a sensible default anchor for stable relative ids.

    If you want explicit control, pass root=... into find_kcl_files().
    """
    current = (start or Path(__file__)).resolve()
    if current.is_file():
        current = current.parent

    while True:
        if (current / "flake.nix").exists():
            return current
        if current.parent == current:
            raise RuntimeError("Could not find project root (missing flake.nix)")
        current = current.parent


# ----------------------------
# File discovery (globbing stays)
# ----------------------------


def find_kcl_files(
    root: Path | None = None,
    filter_fn: Callable[[KFile], bool] = lambda kf: True,
    glob_pattern: str | None = None,
) -> list[KFile]:
    """
    Discover KCL files under root (default: repo root), returning KFile objects.

    Notes:
    - glob_pattern default is "*.k"
    - filter_fn is applied to KFile objects (so you can match by path, name, etc.)
    """
    if root is None:
        root = find_project_root()
    if glob_pattern is None:
        glob_pattern = "*.k"

    results: list[KFile] = []
    for file_path in root.rglob(glob_pattern):
        if not file_path.is_file():
            continue
        kf = KFile(path=file_path)
        if filter_fn(kf):
            results.append(kf)

    return results


def filter_kcl_files(
    kcl_files: list[KFile],
    filter_fn: Callable[[KFile], bool],
) -> list[tuple[KFile, KFile]]:
    """
    Preserved helper from your exploratory version.

    Returns all ordered pairs (pf, kf) where kf matches filter_fn.
    (Yes, it's quadratic; keep it only if you still use it somewhere.)
    """
    return [(pf, kf) for pf in kcl_files for kf in kcl_files if filter_fn(kf)]


# ----------------------------
# Metadata extraction (pytest-agnostic)
# ----------------------------


@dataclass(frozen=True)
class KclMetadata:
    """
    Read-only view of what a test function declared via decorators.
    """

    kcl_filter_fn: Optional[Callable[[KFile], bool]] = None
    kcl_group_filenames: Optional[list[str]] = None
    kcl_group_filter: Optional[Callable[[KFile], bool]] = None

    @property
    def use_single_file_tests(self) -> bool:
        return callable(self.kcl_filter_fn)

    @property
    def use_named_group_tests(self) -> bool:
        return (
            self.kcl_group_filenames is not None
            and len(self.kcl_group_filenames) > 0
            and callable(self.kcl_group_filter)
        )


def extract_kcl_metadata(test_func: Callable[..., object]) -> KclMetadata:
    """
    Pulls decorator-provided attributes off a test function.

    Conventions (preserved):
    - _kcl_filter_fn
    - _kcl_group_filenames
    - _kcl_group_filter
    """
    raw_filter_fn = getattr(test_func, "_kcl_filter_fn", None)
    raw_group_filenames = getattr(test_func, "_kcl_group_filenames", None)
    raw_group_filter = getattr(test_func, "_kcl_group_filter", None)

    if raw_filter_fn is not None and not callable(raw_filter_fn):
        raise ValueError("_kcl_filter_fn must be callable or None")

    if raw_group_filter is not None and not callable(raw_group_filter):
        raise ValueError("_kcl_group_filter must be callable or None")

    if raw_group_filenames is not None and not isinstance(raw_group_filenames, list):
        raise ValueError("_kcl_group_filenames must be a list[str] or None")

    kcl_filter_fn = cast(Optional[KclFilterFn], raw_filter_fn)
    kcl_group_filter = cast(Optional[KclFilterFn], raw_group_filter)

    return KclMetadata(
        kcl_filter_fn=kcl_filter_fn,
        kcl_group_filenames=raw_group_filenames,
        kcl_group_filter=kcl_group_filter,
    )


# ----------------------------
# Selection / matching helpers (pure)
# ----------------------------


def select_single_file_cases(
    all_files: Sequence[KFile],
    filter_fn: Callable[[KFile], bool],
) -> list[KFile]:
    matched = [kf for kf in all_files if filter_fn(kf)]
    return matched


def select_named_group_cases(
    all_files: Sequence[KFile],
    filenames: Sequence[str],
    group_filter: Callable[[KFile], bool],
) -> list[KFile]:
    """
    Apply group_filter first, then resolve each filename to a unique KFile by basename.
    """
    filtered = [kf for kf in all_files if group_filter(kf)]

    matched: list[KFile] = []
    for fname in filenames:
        hit = next((kf for kf in filtered if kf.path.name == fname), None)
        if not hit:
            raise ValueError(f"File '{fname}' not found in filtered files")
        matched.append(hit)

    return matched


def kfile_id(
    kf: KFile,
    *,
    project_root: Path | None = None,
) -> str:
    """
    Stable-ish id for pytest:
    - Prefer relative path to repo root
    - Fallback: full path string
    """
    try:
        root = project_root or find_project_root(kf.path.parent)
        return str(kf.path.relative_to(root))
    except Exception:
        return str(kf.path)


def kfile_ids(
    kfiles: Sequence[KFile],
    *,
    project_root: Path | None = None,
) -> list[str]:
    return [kfile_id(kf, project_root=project_root) for kf in kfiles]


def infer_group_argnames(
    test_func: Callable[..., object],
    fixturenames: Sequence[str],
    *,
    exclude: Iterable[str] = ("tmp_path",),
) -> list[str]:
    """
    Mirrors your prior behavior:
    - Look at function local varnames / signature ordering
    - Keep only names that are in fixturenames
    - Exclude tmp_path
    - Return the first N names (conftest will slice to len(matched))
    """
    # Use __code__.co_varnames to stay consistent with your old implementation.
    names = [
        name
        for name in test_func.__code__.co_varnames
        if name in fixturenames and name not in set(exclude)
    ]
    return names


def validate_group_arity(
    test_name: str,
    argnames: Sequence[str],
    matched_files: Sequence[KFile],
) -> None:
    """
    Ensures the test has enough fixture args to receive the matched files.
    (Same invariant as your old conftest.)
    """
    if len(argnames) != len(matched_files):
        raise ValueError(
            f"{test_name} expects {len(argnames)} args but {len(matched_files)} files were matched"
        )
