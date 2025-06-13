import argparse
import json
from datetime import datetime, timedelta
from pathlib import Path

CONFIG_FILE = Path("config.json")
DATA_FILE = Path("data.json")

DEFAULT_CONFIG = {
    "reminder_time": "09:00",
    "daily_goal": 2000,  # milliliters
    "cycles": 8
}

def load_config():
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            return json.load(f)
    return DEFAULT_CONFIG.copy()

def save_config(cfg):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)

def load_data():
    if DATA_FILE.exists():
        with open(DATA_FILE) as f:
            return json.load(f)
    return {}

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)


def cmd_settings(args):
    cfg = load_config()
    if args.reminder_time:
        cfg["reminder_time"] = args.reminder_time
    if args.daily_goal is not None:
        cfg["daily_goal"] = args.daily_goal
    if args.cycles is not None:
        cfg["cycles"] = args.cycles
    save_config(cfg)
    print("Settings updated:")
    print(json.dumps(cfg, indent=2))


def cmd_log(args):
    data = load_data()
    today = datetime.now().date().isoformat()
    entries = data.get(today, [])
    entry = {
        "time": datetime.now().isoformat(timespec='minutes'),
        "amount": args.amount
    }
    entries.append(entry)
    data[today] = entries
    save_data(data)
    print(f"Logged {args.amount} ml at {entry['time']}")


def summarize(data, start_date, end_date, daily_goal):
    summary = []
    current = start_date
    while current <= end_date:
        day = current.isoformat()
        entries = data.get(day, [])
        total = sum(e["amount"] for e in entries)
        summary.append({"date": day, "total": total, "remaining": max(daily_goal - total, 0)})
        current += timedelta(days=1)
    return summary


def cmd_stats(args):
    cfg = load_config()
    data = load_data()
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=args.days - 1)
    summary = summarize(data, start_date, end_date, cfg["daily_goal"])
    for day in summary:
        print(f"{day['date']}: {day['total']} ml consumed, {day['remaining']} ml remaining")
    if args.graph:
        try:
            import matplotlib.pyplot as plt
        except ImportError:
            print("matplotlib not installed. Cannot display graph.")
            return
        dates = [s['date'] for s in summary]
        totals = [s['total'] for s in summary]
        remaining = [s['remaining'] for s in summary]
        x = range(len(summary))
        plt.bar(x, totals, label='Consumed')
        plt.bar(x, remaining, bottom=totals, label='Remaining')
        plt.xticks(x, dates, rotation=45)
        plt.ylabel('ml')
        plt.legend()
        plt.tight_layout()
        plt.show()


def main():
    parser = argparse.ArgumentParser(description="Simple water tracker")
    sub = parser.add_subparsers(dest="command")

    p_settings = sub.add_parser("settings", help="Update settings")
    p_settings.add_argument("--reminder-time")
    p_settings.add_argument("--daily-goal", type=int)
    p_settings.add_argument("--cycles", type=int)
    p_settings.set_defaults(func=cmd_settings)

    p_log = sub.add_parser("log", help="Log water consumption")
    p_log.add_argument("--amount", type=int, required=True, help="amount in ml")
    p_log.set_defaults(func=cmd_log)

    p_stats = sub.add_parser("stats", help="Show statistics")
    p_stats.add_argument("--days", type=int, default=7, help="Period length in days")
    p_stats.add_argument("--graph", action="store_true", help="Display chart")
    p_stats.set_defaults(func=cmd_stats)

    args = parser.parse_args()
    if hasattr(args, 'func'):
        args.func(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
