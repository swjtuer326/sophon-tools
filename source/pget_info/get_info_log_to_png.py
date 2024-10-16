import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.ticker import AutoLocator, ScalarFormatter, MaxNLocator
import yaml
import argparse
import os
import math
from decimal import Decimal, getcontext

getcontext().prec = 50

colors=list(mcolors.TABLEAU_COLORS.keys())

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

def plan_square_frame(num_squares):
    if num_squares == 0:
        num_squares = 1
    # 计算接近正方形的行和列
    cols = int(num_squares ** 0.5)  # 计算列数
    rows = (num_squares + cols - 1) // cols  # 计算行数，确保总数不小于num_squares
    return cols, rows


rows = 0
cols = 0
cols, rows = plan_square_frame(len(configs["info"]))
print("rows:", rows)
print("cols:", cols)

if len(boot_time_data) <= 0:
    print("BOOT TIME is Empty!!!!")
    exit(-1)

basic_time=boot_time_data[0]
boot_time_data=[x - basic_time for x in boot_time_data]
reboot_flag=[x - basic_time for x in reboot_flag]

print("Start draw pic...")

plt.style.use("fast")
fig, axs = plt.subplots(rows,cols,figsize=(rows * 8, cols * 8))

for j in range(cols):
    for i in range(rows):
        if j*rows+i >= len(configs["info"]):
            break
        if(cols > 1):
            ax = axs[i, j]
        else:
            ax = axs[i]
        data_temp = infos_data[configs["info"][j*rows+i]["name"]]
        if len(data_temp) < len(boot_time_data):
            print("Warring: data num is: ", len(data_temp), "and boot time num is: ", len(boot_time_data))
            for ii in range(0, len(boot_time_data) - len(data_temp)):
                data=data_temp[-1]
                if configs["info"][j*rows+i].get("max") is not None:
                    data = min(data , configs["info"][j*rows+i]["max"])
                if configs["info"][j*rows+i].get("min") is not None:
                    data = max(data , configs["info"][j*rows+i]["min"])
                data_temp.append(data)
        ax.set_xlim(left=boot_time_data[0], right=boot_time_data[-1])
        ax.scatter(boot_time_data, data_temp, s=configs["point_size"], color=("green"), label=configs["info"][j*rows+i]["y_name"])
        if configs["info"][j*rows+i].get("min") is not None:
            ax.set_ylim(bottom = configs["info"][j*rows+i].get("min"))
        if configs["info"][j*rows+i].get("max") is not None:
            ax.set_ylim(top = configs["info"][j*rows+i].get("max"))
        ax.yaxis.set_major_locator(MaxNLocator(min(20, 40)))
        ax.xaxis.set_major_locator(AutoLocator())
        ax.xaxis.set_major_formatter(ScalarFormatter(useOffset=False))
        ax.yaxis.set_major_locator(AutoLocator())
        ax.yaxis.set_major_formatter(ScalarFormatter(useOffset=False))
        reboot_label_flag=0
        for root_flag in reboot_flag:
            if reboot_label_flag == 0:
                ax.axvline(x=root_flag, color='red', linestyle='--', linewidth=1, label=f'reboot flag')
            else:
                ax.axvline(x=root_flag, color='red', linestyle='--', linewidth=1)
        if configs["info"][j*rows+i].get("y_flag") is not None:
            y_flag_count=0
            for item in configs["info"][j*rows+i].get("y_flag"):
                ax.axhline(y=item, color=mcolors.TABLEAU_COLORS[colors[y_flag_count]], alpha=0.3, linewidth=3, label=f'{item:.1f}')
                y_flag_count=y_flag_count+1
        ax.spines['top'].set_visible(False)
        ax.spines['bottom'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.set_ylabel(configs["info"][j*rows+i]["y_name"])
        ax.set_title(configs["info"][j*rows+i]["y_name"])
        ax.set_xlabel("TIME(min)")
        ax.legend(loc='upper left', bbox_to_anchor=(1, 1))
        ax.autoscale_view()
        ax.grid(True)
fig.tight_layout()
print("write pic to file: ", args.log + ".png ...")
fig.savefig(args.log + ".png", dpi=200, transparent=False)
