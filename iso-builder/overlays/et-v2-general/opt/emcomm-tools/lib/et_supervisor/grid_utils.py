"""
Grid square to lat/lon conversion for YAAC station position.

Replaces the grid-to-latlon logic previously in the et-yaac bash script.
Maidenhead grid squares: 4 or 6 character locators (e.g., FN35ht).
"""

import logging

log = logging.getLogger("et-supervisor.grid")


def grid_to_latlon(grid):
    """Convert Maidenhead grid square to (latitude, longitude).

    Supports 4-char (field+square) and 6-char (field+square+subsquare) locators.

    Args:
        grid: Maidenhead locator string (e.g., "FN35", "FN35ht").

    Returns:
        (lat, lon) tuple as floats, or None if grid is invalid.
    """
    grid = grid.strip().upper()

    if len(grid) < 4:
        log.warning("Grid too short: %s", grid)
        return None

    # Field (2 chars: A-R)
    if not ("A" <= grid[0] <= "R" and "A" <= grid[1] <= "R"):
        log.warning("Invalid grid field: %s", grid[:2])
        return None

    # Square (2 digits: 0-9)
    if not (grid[2].isdigit() and grid[3].isdigit()):
        log.warning("Invalid grid square: %s", grid[2:4])
        return None

    lon = (ord(grid[0]) - ord("A")) * 20 - 180
    lat = (ord(grid[1]) - ord("A")) * 10 - 90
    lon += int(grid[2]) * 2
    lat += int(grid[3]) * 1

    if len(grid) >= 6:
        # Subsquare (2 chars: a-x)
        sub_lon = grid[4].upper()
        sub_lat = grid[5].upper()
        if "A" <= sub_lon <= "X" and "A" <= sub_lat <= "X":
            lon += (ord(sub_lon) - ord("A")) * (2.0 / 24)
            lat += (ord(sub_lat) - ord("A")) * (1.0 / 24)
            # Center of subsquare
            lon += 1.0 / 24
            lat += 0.5 / 24
        else:
            # Center of square
            lon += 1
            lat += 0.5
    else:
        # Center of square
        lon += 1
        lat += 0.5

    return (round(lat, 6), round(lon, 6))
