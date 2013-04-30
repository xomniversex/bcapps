float life = 500.; // life of each particle, in time units
float num = 1.; // particles generated per time interval
float size_end = 0.02; // ending size of each particle
float size_start = 0.01; // starting size of each particle
VECTOR color_end = {1.,0.,0.}; // ending color of each particle
VECTOR color_start = {0.,0.,1.}; // starting color of each particle
VECTOR dir = {0.004,0.,0}; // direction in which particles are emitted
VECTOR emitter = {-1.,0,0}; // location of particle emitter
VECTOR gravity = {-0.00001,0,0}; // the force of gravity (or whatever)
VECTOR turb_dir = {0.001,0.002,0.00}; // randomness of direction