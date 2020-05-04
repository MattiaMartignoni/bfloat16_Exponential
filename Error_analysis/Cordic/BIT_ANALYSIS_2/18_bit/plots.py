import numpy as np
import matplotlib.pyplot as plt
import csv

x = []
y = []
errore_medio_tot = 0
errore_da_4900 = 0
counter_tot = 0
counter_da_4900 = 0

x_16 = []
y_16 = []
errore_medio_tot_16 = 0
errore_da_4900_16 = 0
counter_tot_16 = 0
counter_da_4900_16 = 0

wrong_bits = []

data_in = []
data_o_20 = []
correct_result_20 = []
data_o_16 = []
correct_result_16 = []

wrong_data_number = 0


with open('C:/Users/matti/Desktop/TEST/BIT_ANALYSIS/18_bit/data_file.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter=',')
    for row in plots:
        #y.append(float(row[0]))
        data_in.append(row[0])
        data_o_20.append(row[1])
        correct_result_20.append(row[2])
        data_o_16.append(row[3])
        correct_result_16.append(row[4])

with open('C:/Users/matti/Desktop/TEST/BIT_ANALYSIS/18_bit/err_perc.csv','r') as csvfile:
    plots = csv.reader(csvfile, delimiter=',')
    for row in plots:
        #y.append(float(row[0]))
        y.append(abs(float(row[0])))
        y_16.append(abs(float(row[1])))


for i in range(0, len(y)):
    errore_medio_tot = errore_medio_tot + abs(y[i])
    counter_tot = counter_tot + 1
    if i > 100:
        errore_da_4900 = errore_da_4900 + abs(y[i])
        counter_da_4900 = counter_da_4900 + 1

errore_medio_tot = errore_medio_tot/counter_tot
errore_da_4900 = errore_da_4900/counter_da_4900

for i in range(0, len(y_16)):
    errore_medio_tot_16 = errore_medio_tot_16 + abs(y_16[i])
    counter_tot_16 = counter_tot_16 + 1
    if i > 100:
        errore_da_4900_16 = errore_da_4900_16 + abs(y[i])
        counter_da_4900_16 = counter_da_4900_16 + 1

errore_medio_tot_16 = errore_medio_tot_16/counter_tot_16
errore_da_4900_16 = errore_da_4900_16/counter_da_4900_16

print ('HIGH ERROR (for 16 bit approximation after 4900th iteration):')
print ('data_in\t\t\tdata_o_20\t\tcorrect_result_20\tdata_o_16\t\tcorrect_result_16\terrore_20bit\terrore_16bit')
for i in range(100, len(y)):
    if(y_16[i]) > 0:
        print (data_in[i], '\t', data_o_20[i], '\t', correct_result_20[i], '\t', data_o_16[i], '\t', correct_result_16[i], '\t', y[i], '\t', y_16[i])
        wrong_data_number = wrong_data_number + 1
print ('number of wrong data = '), wrong_data_number


print ('total mean error 20 bits = ', errore_medio_tot)
print ('mean error from 4900th iteration on for 20 bits = ', errore_da_4900)
print ('total mean error 16 bits = ', errore_medio_tot_16)
print ('mean error from 4900th iteration on for 16 bits = ', errore_da_4900_16)



for i in range(0, len(y), 247):
    x.append(data_in[i])

plt.figure(1)
#plt.plot(y_16)
#plt.plot(y_16, marker='', label='global mean error = 0.922240980816\nmean error after 100th iteration = 0.0577079442442')
plt.plot(y_16, label='percentage error vs. iteration (16 bits)')
plt.grid(True)

plt.xticks(np.arange(0, len(y), 247), x, rotation = 90)
plt.yticks(np.arange(0, 4, 0.2))
plt.xlabel('x (input value)')
plt.ylabel('y (absolute value of percentage error)')
#plt.title('percentage error vs. iteration (16 bits)')
plt.legend()
#plt.show()

plt.figure(2)
#plt.plot(x,y, marker='o')
#plt.plot(y)
#plt.plot(y, marker='', label='global mean error = 0.855159907429\nmean error after 100th iteration = 0.0577079442442')
plt.plot(y, label='percentage error vs. iteration (20 bits)')
plt.grid(True)

plt.xticks(np.arange(0, len(y), 247), x, rotation = 90)
plt.yticks(np.arange(0, 4, 0.2))
#plt.xlabel('x (cordic input)')
plt.xlabel('x (input value)')
plt.ylabel('y (absolute value of percentage error)')
#plt.title('percentage error vs. iteration (18 bits)')
plt.legend()
plt.show()
