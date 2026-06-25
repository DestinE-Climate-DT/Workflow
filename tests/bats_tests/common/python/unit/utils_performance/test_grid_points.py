"""
Unit tests for calculate_number_of_grid_points.

Covers both grid families: IFS Gaussian/octahedral (tco/t + levels) and ICON
icosahedral (R<r>B<b> -> 20 * r^2 * 4^b horizontal cells).
"""

from runscripts.CPMIP.utils_performance import calculate_number_of_grid_points


class TestGridPointsICON:
    """ICON icosahedral grids: 20 * root^2 * 4^bisections horizontal cells."""

    def test_r2b8(self):
        # 20 * 2^2 * 4^8 = 5,242,880 (~10 km)
        assert calculate_number_of_grid_points("r2b8") == 5_242_880

    def test_r2b9(self):
        # 20 * 2^2 * 4^9 = 20,971,520 (~5 km)
        assert calculate_number_of_grid_points("r2b9") == 20_971_520

    def test_r2b4(self):
        # 20 * 2^2 * 4^4 = 20,480 (~160 km)
        assert calculate_number_of_grid_points("r2b4") == 20_480

    def test_case_insensitive(self):
        assert calculate_number_of_grid_points("R2B8") == 5_242_880


class TestGridPointsIFS:
    """IFS Gaussian/octahedral path must stay unchanged: (truncation * 8) * levels."""

    def test_tco79l137(self):
        assert calculate_number_of_grid_points("tco79l137") == 79 * 8 * 137

    def test_t255l123(self):
        assert calculate_number_of_grid_points("t255l123") == 255 * 8 * 123


class TestGridPointsUnknown:
    """Grids matching neither family (or empty) return 0."""

    def test_ocean_grid_no_match(self):
        # NEMO ocean grids must not be mistaken for an ICON r<n>b<n>.
        assert calculate_number_of_grid_points("eORCA1_Z75") == 0

    def test_empty(self):
        assert calculate_number_of_grid_points("") == 0
