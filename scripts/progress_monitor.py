import sys
import time
from datetime import datetime, timedelta
import re

def display_progress_with_timer(progress_file, progress_info, total_tasks, id_value, log_file_path):
    # ANSI escape codes for terminal output
    green_color = "\033[92m"
    gray_color = "\033[90m"
    red_color = "\033[91m"
    yellow_color = "\033[93m"
    reset_color = "\033[0m"  # Reset to default terminal color
    bold_start = "\033[1m"
    bold_end = "\033[22m"
    clear_line = "\033[K"

    def format_timedelta(td):
        total_seconds = int(td.total_seconds())
        hours, remainder = divmod(total_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"[{hours:02d}:{minutes:02d}:{seconds:02d}]"

    def highlight_numbers(text):
        return re.sub(r'(\d+%?)', bold_start + r'\1' + bold_end, text)

    task_start_times = {}
    task_end_times = {}
    task_descriptions = {}
    task_info = {}  # ← new: store the per-task info string

    while True:
        try:
            with open(progress_file, "r") as file:
                lines = file.readlines()
        except FileNotFoundError:
            print(f"Error: The file {progress_file} was not found.")
            sys.exit(1)

        try:
            with open(progress_info, "r") as f:
                progress_info_content = f.read().strip()
        except FileNotFoundError:
            print(f"Error: The progress_info file {progress_info} was not found.")
            sys.exit(1)

        highlighted_info = gray_color + highlight_numbers(progress_info_content) + reset_color

        last_task_number = 0
        output_line = ""

        for line in lines:
            try:
                task_number_str, description = line.strip().split(",", 1)
                task_number = int(task_number_str)
                task_descriptions[task_number] = description
            except ValueError:
                continue

            if task_number not in task_start_times:
                task_start_times[task_number] = datetime.now()
            task_end_times[task_number] = datetime.now()
            # record the info string that was current when this task ran
            task_info[task_number] = progress_info_content

            last_task_number = task_number

            completed_bar = bold_start + green_color + "#" * last_task_number + reset_color
            remaining_bar = bold_start + red_color + "-" * (total_tasks - last_task_number) + reset_color
            time_elapsed = format_timedelta(datetime.now() - task_start_times[last_task_number])

            output_line = (
                f"{completed_bar}{remaining_bar} "
                f"{last_task_number}/{total_tasks} - {bold_start}{id_value}{bold_end}: "
                f"{yellow_color}{description}{reset_color} {highlighted_info} {time_elapsed}"
            )

        if output_line:
            sys.stdout.write(f"\r{clear_line}\r{output_line}")
            sys.stdout.flush()

        if last_task_number >= total_tasks:
            break

        time.sleep(0.5)

    # Final output after completion
    print(f"\n{green_color}Pipeline successfully completed:{reset_color}")
    with open(log_file_path, 'a') as log_file:
        log_file.write("Pipeline successfully completed:\n")
        for task_number in range(1, total_tasks + 1):
            description = task_descriptions.get(task_number, "Task description not found")
            info_for_task = task_info.get(task_number, "")
            highlighted = gray_color + highlight_numbers(info_for_task) + reset_color
            duration = format_timedelta(
                task_end_times.get(task_number, task_start_times.get(task_number, timedelta()))
                - task_start_times.get(task_number, timedelta())
            )
            print(f"{description} {highlighted} {duration}")
            log_file.write(f"{description} - {info_for_task} - {duration}\n")

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Usage: python3 progress_monitor.py <path_to_progress_file> <progress_info> <total_tasks> <id> <log_file_path>")
        sys.exit(1)

    progress_file_path, progress_info, total_tasks, id_value, log_file_path = sys.argv[1:6]
    display_progress_with_timer(
        progress_file_path,
        progress_info,
        int(total_tasks),
        id_value,
        log_file_path
    )

