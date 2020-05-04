import numpy as np
import matplotlib.pyplot as plt
import csv

x = []
data_in = []
data_in_float = []
data_o = []
data_o_float = []
correct_result_32_bit = []
correct_result_32_bit_float = []
err_perc = []

with open('C:/Coding_Projects/ES_project/REPOSITORY/Test_Projects/wrapper3.0/data_file.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter=',')
    for row in plots:
        data_in.append(row[0])
        data_in_float.append(row[1])
        data_o.append(row[2])
        data_o_float.append(row[3])
        correct_result_32_bit.append(row[4])
        correct_result_32_bit_float.append(row[5])
        err_perc.append(row[6])

for i in range(0, len(err_perc)):
    if(err_perc[i] == '-nan(ind)'):
        err_perc[i] = '200'
    if(err_perc[i] == 'nan'):
        err_perc[i] = '200'


for i in range(0, len(err_perc), 1000):
    x.append(data_in[i])

plt.figure(1)
plt.plot(err_perc)
plt.grid(True)
plt.xticks(np.arange(0, len(err_perc), 1000), x, rotation = 90)
#plt.yticks(np.arange(0, 4, 0.2))
plt.xlabel('data_in')
plt.ylabel('err_perc')
plt.show()
