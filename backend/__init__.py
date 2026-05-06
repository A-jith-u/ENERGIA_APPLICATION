"""Backend package marker for ENERGIA backend modules.

This package exposes a top-level `config` alias so legacy modules that still
use `import config` continue to work when the backend is started as
`backend.app_main`.
"""

from __future__ import annotations

import sys

from . import config as _config

sys.modules.setdefault("config", _config)
