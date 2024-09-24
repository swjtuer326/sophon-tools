import matplotlib.pyplot as plt
from matplotlib.ticker import AutoLocator, ScalarFormatter, MaxNLocator
import yaml
import argparse
import os
import math
from decimal import Decimal, getcontext

getcontext().prec = 50

parser = argparse.ArgumentParser(description="get info log file to png")
parser.add_argument('--config', type=str, help='Path to the configuration file')
parser.add_argument('--log', type=str, help='Path to the log file')
args = parser.parse_args()

if not os.path.exists(args.config):
    print(f"Error: Configuration file '{args.config}' not found.")
    exit(1)
if not os.path.exists(args.log):
    print(f"Error: Log file '{args.log}' not found.")
    exit(1)

with open(args.config, 'r') as file:
    configs = yaml.safe_load(file)
if configs is None:
    exit(-1)
print("configs:", configs)

log_name = args.log
boot_time_data = []
boot_ost_time_data = []
x_value = []
reboot_flag = []
infos_data = {"" : []}
basic_time=0

with open(log_name,'r') as file:
    while True:
        line = file.readline()
        if not line: 
            break
        if line.find("BOOT_TIME(s)") >= 0:
            ost_time = int(line.split("|")[-2].split(".")[0])/60
            curr_time = ost_time+basic_time
            if len(boot_time_data) > 0:
                if ost_time < boot_ost_time_data[len(boot_ost_time_data)-1]:
                    basic_time=boot_time_data[len(boot_time_data)-1]
                    reboot_flag.append(basic_time)

            boot_ost_time_data.append(ost_time)
            boot_time_data.append(curr_time)
        for item in configs["info"]:
            if line.find(item["name"]) >= 0:
                if infos_data.get(item["name"]) is None:
                    infos_data[item["name"]] = []
                item_data=line.split("|")[-2].split(" ")[0 + item["sampling_index"][0]].split(",")[0 + item["sampling_index"][1]]
                if item_data == "":
                    data = Decimal(0)
                else:
                    data = Decimal(item_data)
                if item.get("max") is not None:
                    data = min(data , item["max"])
                if item.get("min") is not None:
                    data = max(data , item["min"])
                infos_data[item["name"]].append(data)

def find_flexible_layout(n):
    best_diff = float('inf')
    best_pair = (1, n)
    for total in range(n, n + 22):
        root = int(math.sqrt(total))
        for i in range(root, 0, -1):
            if total % i == 0:
                rows, cols = i, total // i
                if rows > cols:
                    rows, cols = cols, rows
                current_diff = total - n
                if current_diff < best_diff or (current_diff == best_diff and abs(rows - cols) < abs(best_pair[0] - best_pair[1])):
                    best_diff = current_diff
                    best_pair = (rows, cols)
    return best_pair

rows = 0
cols = 0
cols, rows = find_flexible_layout(len(configs["info"]))
print("rows:", rows)
print("cols:", cols)

if len(boot_time_data) <= 0:
    print("BOOT TIME is Empty!!!!")
    exit(-1)
    
print("Start draw pic...")

fig, axs = plt.subplots(rows,cols,figsize=(rows * 5, cols * 8))

for j in range(cols):
    for i in range(rows):
        if j*rows+i >= len(configs["info"]):
            break
        if(cols > 1):
            ax = axs[i, j]
        else:
            ax = axs[i]
        ax.set_ylabel(configs["info"][j*rows+i]["y_name"])
        ax.set_xlabel("TIME(min)")
        for root_flag in reboot_flag:
            ax.axvline(x=root_flag, color=(0,0,0.5), linestyle='--',linewidth=1)
        if configs["info"][j*rows+i].get("y_flag") is not None:
            for item in configs["info"][j*rows+i].get("y_flag"):
                ax.axhline(y=item, color='red', linestyle=':', linewidth=1)
                ax.text(0, item, f'{item:.1f}', color='red', fontsize=8, verticalalignment='top', horizontalalignment='left')
        ax.scatter(boot_time_data, infos_data[configs["info"][j*rows+i]["name"]], s=configs["point_size"], color=("green"))
        ax.xaxis.set_major_locator(AutoLocator())
        ax.xaxis.set_major_formatter(ScalarFormatter(useOffset=False))
        ax.yaxis.set_major_locator(AutoLocator())
        ax.yaxis.set_major_formatter(ScalarFormatter(useOffset=False))
        if configs["info"][j*rows+i].get("min") is not None:
            ax.set_ylim(bottom = configs["info"][j*rows+i].get("min"))
        if configs["info"][j*rows+i].get("max") is not None:
            ax.set_ylim(top = configs["info"][j*rows+i].get("max"))
        ax.yaxis.set_major_locator(MaxNLocator(min(20, 40)))
        ax.autoscale_view()
        ax.grid(True)
plt.tight_layout()
plt.savefig(args.log + ".png")
print("write pic to file: ", args.log + ".png")
