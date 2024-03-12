import sys
import time
from datetime import datetime, timedelta

def display_progress_with_timer(progress_file, total_tasks, id_value, log_file_path):
    # ANSI escape codes for terminal output
    green_color = "\033[92m"
    gray_color = "\033[90m"
    red_color = "\033[91m"
    reset_color = "\033[0m"  # Reset to default terminal color
    bold_start = "\033[1m"
    bold_end = "\033[22m"
    clear_line = "\033[K"

    def format_timedelta(td):
        total_seconds = int(td.total_seconds())
        hours, remainder = divmod(total_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"[{hours:02d}:{minutes:02d}:{seconds:02d}]"

    task_start_times = {}
    task_end_times = {}
    task_descriptions = {}
    last_update_completed = False

    while True:
        try:
            with open(progress_file, "r") as file:
                lines = file.readlines()
        except FileNotFoundError:
            print(f"Error: The file {progress_file} was not found.")
            sys.exit(1)

        last_task_number = 0
        for line in lines:
            task_number, description = line.strip().split(",", 1)
            task_number = int(task_number)
            task_descriptions[task_number] = description
            if task_number not in task_start_times:
                task_start_times[task_number] = datetime.now()
            task_end_times[task_number] = datetime.now()
            last_task_number = max(last_task_number, task_number)

        # Check for completion and ensure one last update if last task is detected
        if last_task_number >= total_tasks:
            if last_update_completed:
                break
            else:
                last_update_completed = True

        completed_bar = bold_start + green_color + '#' * last_task_number + reset_color
        remaining_bar = bold_start + red_color + '-' * (total_tasks - last_task_number) + reset_color
        print(f"\r{clear_line}{completed_bar}{remaining_bar} {last_task_number}/{total_tasks} - {bold_start}{id_value}{bold_end}: {gray_color}{task_descriptions.get(last_task_number, 'Processing...')}{reset_color} {reset_color}{format_timedelta(datetime.now() - task_start_times[last_task_number])}", end="")
        time.sleep(0.5)

    print(f"\n{green_color}Pipe successfully completed:{reset_color}")
    with open(log_file_path, 'a') as log_file:
        log_file.write("Pipe successfully completed:\n")
        for task_number in range(1, total_tasks + 1):
            description = task_descriptions.get(task_number, "Task description not found")
            task_duration = format_timedelta(task_end_times[task_number] - task_start_times[task_number]) if task_number in task_start_times else "[00:00:00]"
            output = f"{task_duration} {gray_color}{description}{reset_color}"
            print(output)  # Terminal output
            log_file.write(f"{task_duration} - {description}\n")  # Log file output without color formatting

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python3 progress_monitor.py <path_to_progress_file> <total_tasks> <id> <log_file_path>")
        sys.exit(1)
    
    progress_file_path, total_tasks, id_value, log_file_path = sys.argv[1:5]
    display_progress_with_timer(progress_file_path, int(total_tasks), id_value, log_file_path)



