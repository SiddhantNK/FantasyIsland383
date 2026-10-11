# ReRoute backend (solver core)

    pip install ortools pytest
    pytest -q            # runs greedy + ortools engines when ortools is installed

Modules: models, travel (matrix + closures), solver (OR-Tools + greedy dev engine,
schedules, explanations, check_plan), replan (apply incident, freeze completed,
Kept/Moved/Broken), validation, demo_data.

Conventions: times are minutes since midnight; Plan stops with vehicle_id=None are
unassigned (BROKEN + reason); completed stops = departure <= incident time (or
arrival <= incident time for healthy vehicles); replanning never schedules before
the incident time; closures add (end_time - incident_time) minutes, else 60, to the
road in both directions, then shortest paths are recomputed.
