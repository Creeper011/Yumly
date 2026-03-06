# Task manager in CLI using Yumly

import os
from yumly import Yumly
from dataclasses import dataclass, asdict
from typing import Optional

CONFIG_PATH = "tasks.yumly"

@dataclass
class Task:
    name: str
    description: str
    completed: bool = False

class TaskManager:
    def __init__(self):
        self.yumly = Yumly()
        self.tasks: dict[str, Task] = self.load_index()

    def save_index(self) -> None:
        data = {name: asdict(task) for name, task in self.tasks.items()}
        with open(CONFIG_PATH, "w") as file:
            self.yumly.dump(data, file)

    def load_index(self) -> dict[str, Task]:
        if not os.path.exists(CONFIG_PATH):
            return {}
        
        raw: dict[str, dict] = self.yumly.load(CONFIG_PATH)
        return {name: Task(**task_data) for name, task_data in raw.items()}

    def add_task(self, task: Task) -> bool:
        if task.name in self.tasks:
            return False
        self.tasks[task.name] = task
        self.save_index()
        return True

    def remove_task(self, name: str) -> bool:
        if name not in self.tasks:
            return False
        del self.tasks[name]
        self.save_index()
        return True

    def list_tasks(self) -> list[Task]:
        return list(self.tasks.values())

    def mark_task(self, name: str, value: bool) -> bool:
        task = self.tasks.get(name)
        if not task:
            return False

        task.completed = value
        self.save_index()
        return True

    def get_task(self, name: str) -> Optional[Task]:
        return self.tasks.get(name)

class TaskManagerCLI:
    def __init__(self):
        self.manager = TaskManager()

    def run(self) -> None:
        while True:
            print("\nTask Manager CLI")
            print("1. Add Task")
            print("2. Remove Task")
            print("3. List Tasks")
            print("4. Mark Task")
            print("5. Exit")

            choice = input("Enter your choice: ")

            if choice == "1":
                name = input("Enter task name: ")
                description = input("Enter task description: ")

                ok = self.manager.add_task(Task(name, description))
                if not ok:
                    print("Task already exists.")

            elif choice == "2":
                name = input("Enter task name: ")
                ok = self.manager.remove_task(name)

                if not ok:
                    print("Task not found.")

            elif choice == "3":
                tasks = self.manager.list_tasks()

                if not tasks:
                    print("No tasks found.")
                else:
                    for task in tasks:
                        status = "✓" if task.completed else " "
                        print(f"[{status}] {task.name}: {task.description}")

            elif choice == "4":
                name = input("Enter task name: ")
                value_input = input("Mark as completed? (y/n): ").lower()
                value = value_input == "y"

                ok = self.manager.mark_task(name, value)
                if not ok:
                    print("Task not found.")

            elif choice == "5":
                break

if __name__ == "__main__":
    TaskManagerCLI().run()