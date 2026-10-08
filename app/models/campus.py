"""
Static campus topology used by the simulator and the API.
"""

CAMPUS_LAYOUT = {
    "Library-A": {
        "rooms": ["A101", "A102", "A203", "A204"],
        "capacity": {"A101": 40, "A102": 30, "A203": 60, "A204": 60},
    },
    "Engineering-B": {
        "rooms": ["B101", "B102", "B201"],
        "capacity": {"B101": 80, "B102": 80, "B201": 120},
    },
    "Science-C": {
        "rooms": ["C101", "C102", "C103"],
        "capacity": {"C101": 50, "C102": 50, "C103": 100},
    },
    "Student-Center": {
        "rooms": ["SC01", "SC02"],
        "capacity": {"SC01": 200, "SC02": 150},
    },
}

# Thresholds used by the alert engine (Task 6)
THRESHOLDS = {
    "occupancy_pct_warning": 0.80,    # >=80% full => warning
    "occupancy_pct_critical": 1.00,   # over capacity  => critical
    "temperature_c_warning": 28.0,
    "temperature_c_critical": 32.0,
    "humidity_pct_warning": 70.0,
    "energy_kwh_warning": 50.0,       # per reading
    "energy_kwh_critical": 80.0,
}


def all_rooms():
    """Return list of (building, room, capacity) tuples."""
    for b, meta in CAMPUS_LAYOUT.items():
        for r in meta["rooms"]:
            yield b, r, meta["capacity"][r]