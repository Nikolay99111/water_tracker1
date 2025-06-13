import threading
import datetime
import time

class WaterTracker:
    def __init__(self, daily_goal_ml=2000, start_time="08:00"):
        self.daily_goal_ml = daily_goal_ml
        self.start_time = start_time
        self.consumed_ml = 0
        self.timer = None
        self.finished = False

    def start(self):
        """Schedule the first morning reminder."""
        now = datetime.datetime.now()
        target_time = datetime.datetime.strptime(self.start_time, "%H:%M").time()
        start_dt = datetime.datetime.combine(now.date(), target_time)
        if start_dt <= now:
            start_dt += datetime.timedelta(days=1)
        delay = (start_dt - now).total_seconds()
        self.timer = threading.Timer(delay, self.morning_reminder)
        self.timer.start()

    def morning_reminder(self):
        print("Доброе утро! Ты выпил воды?")
        self.schedule_next()

    def schedule_next(self):
        if self.consumed_ml >= self.daily_goal_ml:
            self.finished = True
            print("Дневная норма достигнута. Напоминания остановлены.")
            return
        self.timer = threading.Timer(2 * 60 * 60, self.regular_reminder)
        self.timer.start()

    def regular_reminder(self):
        if self.consumed_ml < self.daily_goal_ml:
            print("Напоминание: пора выпить воды.")
            self.schedule_next()

    def record_drink(self, amount_ml):
        if self.finished:
            print("Норма уже достигнута.")
            return
        self.consumed_ml += amount_ml
        print(f"Принято {amount_ml} мл. Всего {self.consumed_ml} мл из {self.daily_goal_ml} мл.")
        if self.consumed_ml >= self.daily_goal_ml:
            self.finished = True
            if self.timer:
                self.timer.cancel()
            print("Дневная норма достигнута. Напоминания остановлены.")
        else:
            if self.timer:
                self.timer.cancel()
            self.schedule_next()

def main():
    tracker = WaterTracker()
    tracker.start()
    try:
        while not tracker.finished:
            cmd = input("Введите количество воды в мл (или 'exit'): ")
            if cmd.lower() == 'exit':
                break
            try:
                amount = int(cmd)
            except ValueError:
                print("Введите число")
                continue
            tracker.record_drink(amount)
    finally:
        if tracker.timer:
            tracker.timer.cancel()

if __name__ == "__main__":
    main()
