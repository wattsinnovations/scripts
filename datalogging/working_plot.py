import matplotlib.pyplot as plt
import numpy as np
import datetime as dt
from matplotlib.animation import FuncAnimation

# Set up the plot
fig, ax = plt.subplots()
x_data, y_data = [], []
ln, = plt.plot([], [], 'ro')

def init():
    ax.set_xlim(dt.datetime.now(), dt.datetime.now() + dt.timedelta(seconds=10))
    ax.set_ylim(0, 100)
    return ln,

def update(frame):
    x_data.append(dt.datetime.now())
    y_data.append(np.random.randint(1, 101))
    ln.set_data(x_data, y_data)

    window_size = dt.timedelta(seconds=10)
 
    print("X:" + str(x_data[-1]) + "\t\tY: "+ str(y_data[-1])) 
    ax.set_xlim(dt.datetime.now() - window_size, dt.datetime.now() + dt.timedelta(seconds=1))

    # for some reason it needs this otherwise it doesnt show datapoints on graph
    plt.pause(.01)
   
    return ln,

while True:
    try:
        ani = FuncAnimation(fig, update, init_func=init, blit=True, interval=200, cache_frame_data=False)
           
        plt.show()
    except KeyboardInterrupt:
        print("Finished")
        break
  