"""Parser module for climate model I/O analysis."""

from .base_parser import ModelParser, IOMetrics
from .ifs_nemo_parser import IFSNEMOParser
from .ifs_fesom_parser import IFSFESOMParser

__all__ = ["ModelParser", "IOMetrics", "IFSNEMOParser", "IFSFESOMParser"]
