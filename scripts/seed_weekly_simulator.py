#!/usr/bin/env python3
"""Seed a dedicated DrinkWater-Weekly simulator, never a physical device."""

import argparse
import datetime as dt
import json
from pathlib import Path
import subprocess
import uuid
from zoneinfo import ZoneInfo


def simctl(*arguments):
    return subprocess.check_output(["xcrun", "simctl", *arguments], text=True).strip()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("device", help="UDID of an installed, booted DrinkWater-Weekly test simulator")
args = parser.parse_args()
devices = json.loads(simctl("list", "devices", "--json"))["devices"]
device = next((item for items in devices.values() for item in items if item["udid"] == args.device), None)
if not device or not device["name"].startswith("DrinkWater-Weekly") or device["state"] != "Booted":
    parser.error("Use a booted dedicated simulator whose name starts with DrinkWater-Weekly.")

bundle = "com.hxz.drinkwater.ios"
container = Path(simctl("get_app_container", args.device, bundle, "data"))
subprocess.run(["xcrun", "simctl", "terminate", args.device, bundle],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
today = dt.datetime.now(ZoneInfo("Asia/Shanghai")).date()
monday = today - dt.timedelta(days=today.weekday())
goal = {"value": 2, "unit": "cups"}
days = []


def add_day(day, count):
    timestamp = dt.datetime.combine(day, dt.time(10), ZoneInfo("Asia/Shanghai"))
    days.append({
        "dayKey": day.isoformat(), "goal": goal, "goalCupCapacityML": 250,
        "drinks": [{"id": str(uuid.uuid4()), "volumeML": 250,
                    "timestamp": (timestamp + dt.timedelta(minutes=i)).isoformat()}
                   for i in range(count)],
    })


add_day(today, 2)
for index, count in enumerate([1, 2, 3, 0, 4, 0, 2]):
    if count:
        add_day(monday - dt.timedelta(days=7) + dt.timedelta(days=index), count)
# Keep a completely empty intervening week; it must not hide the oldest week.
add_day(monday - dt.timedelta(days=21), 1)
add_day(monday - dt.timedelta(days=19), 2)
document = {
    "version": 1,
    "settings": {"cupCapacityML": 250, "displayUnit": "cups", "dailyGoal": goal},
    "days": days,
}
path = container / "Library/Application Support/DrinkWater/hydration.json"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(document, indent=2), encoding="utf-8")
print(f"Seeded {len(days)} recorded days over four calendar weeks in {device['name']}.")
