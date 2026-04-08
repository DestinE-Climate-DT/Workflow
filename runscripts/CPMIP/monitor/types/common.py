"""Common type definitions used across the monitoring system."""

from typing import Literal

# Basic typed aliases
IoDirection = Literal["Read", "Write"]
TresDirection = Literal["In", "Out"]
MemType = Literal["VM", "RSS"]
