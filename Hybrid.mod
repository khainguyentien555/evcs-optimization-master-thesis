/******************************************************
 EVCS_Hybrid_ONEFILE.mod — one-file run (no .dat)
******************************************************/

// ---------- Sets ----------
{string} STATIONS = {
  "CC-TM1","CC-HH1","CC-TT1","CC-TM2","CC-TM3","CC-BDX","CC-HH2","CC-TLC"
};

{string} TYPES = { "xe_may","oto5","oto7","taxi5","taxi7","bus" };

{string} POINTS = {
"LK1","LK2","LK3","LK4","LK5","LK6","LK7","LK8","LK9","LK10","LK11","LK12","LK13","LK14","LK15","LK16","LK17","LK18","LK19","LK20","LK21","LK22","LK23","LK24","LK25","LK26","LK27","LK28","LK29","BT1","BT2","BT3","BT4","CC-HH1","CC-HH2"
};

// ---------- Constants ----------
float alpha = 0.00036;
float beta  = 0.00215;
float w1    = 0.33557046799799;
float w2    = 0.33322147645101;
float w3    = 0.33221147651010;

string BDX = "CC-BDX";  // station for bus chargers
string BUS = "bus";     // bus type key

// Vectors by type
float SCF[TYPES]    = [0.35, 0.35, 0.35, 0.34, 0.34, 0.44];
float areaT[TYPES]  = [1.48, 12.5, 13.2, 12.5, 13.2, 40];
float powerT[TYPES] = [3.5, 11, 22, 11, 22, 150];

// Bounds by station
int s_lb[STATIONS] = [258, 13, 1, 172, 1, 94, 248, 1];
int s_ub[STATIONS] = [262, 17, 2, 176, 2, 98, 252, 2];

// EV count (|POINTS| x |TYPES|)
int EVcount[POINTS][TYPES] = [
  [35, 5, 2, 0, 0, 0],
  [38, 7, 1, 0, 0, 0],
  [40, 6, 3, 0, 0, 0],
  [41, 5, 2, 0, 0, 0],
  [39, 6, 1, 0, 0, 0],
  [36, 6, 2, 0, 0, 0],
  [34, 7, 3, 0, 0, 0],
  [37, 6, 2, 0, 0, 0],
  [38, 5, 3, 0, 0, 0],
  [36, 6, 2, 0, 0, 0],
  [35, 5, 2, 0, 0, 0],
  [37, 7, 1, 0, 0, 0],
  [39, 6, 3, 0, 0, 0],
  [38, 5, 2, 0, 0, 0],
  [36, 6, 1, 0, 0, 0],
  [37, 5, 3, 0, 0, 0],
  [38, 6, 2, 0, 0, 0],
  [40, 5, 1, 0, 0, 0],
  [39, 6, 2, 0, 0, 0],
  [37, 5, 3, 0, 0, 0],
  [35, 7, 1, 0, 0, 0],
  [36, 6, 3, 0, 0, 0],
  [38, 5, 2, 0, 0, 0],
  [37, 6, 1, 0, 0, 0],
  [39, 5, 3, 0, 0, 0],
  [40, 6, 2, 0, 0, 0],
  [38, 5, 1, 0, 0, 0],
  [36, 6, 2, 0, 0, 0],
  [35, 7, 3, 0, 0, 0],
  [34, 6, 2, 0, 0, 0],
  [36, 5, 3, 0, 0, 0],
  [37, 7, 1, 0, 0, 0],
  [39, 6, 2, 0, 0, 0],
  [120, 40, 20, 82, 82, 0],
  [130, 50, 25, 121, 121, 0]
];

// ---------- Max chargers per station & type (|STATIONS| x |TYPES|) ----------
int maxCharger[STATIONS][TYPES] = [
  [100, 50, 50, 30, 30, 0],
  [100, 50, 50, 30, 30, 0],
  [100, 50, 50, 30, 30, 0],
  [100, 50, 50, 30, 30, 0],
  [100, 50, 50, 30, 30, 0],
  [ 50, 30, 30,  0,  0, 10],
  [100, 50, 50, 30, 30, 0],
  [ 80, 40, 40, 20, 20, 0]
];

// ---------- Distance matrix (|POINTS| x |STATIONS|) ----------
float DIST[POINTS][STATIONS] = [
  [0.483, 0.229, 0.292, 0.574, 1.117, 1.376, 1.467, 1.202],
  [0.585, 0.359, 0.172, 0.642, 0.996, 1.072, 1.178, 1.291],
  [0.312, 0.160, 0.132, 0.322, 0.907, 1.098, 1.207, 0.987],
  [0.329, 0.186, 0.301, 0.466, 0.972, 1.142, 1.301, 1.186],
  [0.204, 0.228, 0.325, 0.459, 1.236, 1.398, 1.438, 0.996],
  [0.214, 0.241, 0.207, 0.353, 1.088, 1.294, 1.305, 1.009],
  [0.680, 0.633, 0.211, 0.070, 0.733, 0.869, 0.849, 0.521],
  [1.002, 0.879, 0.496, 0.434, 0.346, 0.469, 0.484, 0.238],
  [1.193, 1.025, 0.706, 0.605, 0.545, 0.644, 0.621, 0.484],
  [0.605, 0.423, 0.239, 0.382, 0.629, 0.799, 0.790, 0.578],
  [1.111, 0.763, 0.581, 0.371, 0.241, 0.617, 0.917, 0.739],
  [0.687, 0.525, 0.328, 0.392, 0.532, 1.007, 1.370, 0.558],
  [0.862, 0.613, 0.352, 0.329, 0.599, 1.032, 1.370, 0.772],
  [0.858, 0.643, 0.300, 0.342, 0.805, 1.041, 0.844, 0.739],
  [0.606, 0.510, 0.312, 0.762, 0.687, 0.844, 1.091, 0.605],
  [0.963, 0.728, 0.617, 0.666, 0.931, 0.658, 0.258, 0.819],
  [0.903, 0.689, 0.515, 0.542, 0.336, 0.518, 0.617, 0.451],
  [1.105, 0.830, 0.615, 0.665, 0.258, 0.627, 0.549, 0.304],
  [1.140, 0.951, 0.660, 0.725, 0.150, 0.369, 0.382, 0.430],
  [0.981, 0.792, 0.526, 0.543, 0.224, 0.290, 0.503, 0.431],
  [1.011, 0.848, 0.525, 0.490, 0.230, 0.417, 0.433, 0.320],
  [1.085, 0.945, 0.586, 0.546, 0.279, 0.488, 0.390, 0.314],
  [1.089, 0.972, 0.598, 0.466, 0.415, 0.331, 0.409, 0.260],
  [1.260, 1.120, 0.705, 0.672, 0.498, 0.495, 0.391, 0.123],
  [1.342, 1.299, 0.903, 0.839, 0.382, 0.332, 0.351, 0.115],
  [1.436, 1.255, 0.930, 0.730, 0.817, 0.332, 0.101, 0.123],
  [1.366, 1.166, 0.886, 0.861, 0.060, 0.374, 0.084, 0.349],
  [1.386, 1.190, 0.934, 0.931, 0.095, 0.810, 0.244, 0.283],
  [1.228, 1.007, 0.802, 0.832, 0.195, 0.309, 0.484, 0.291],
  [0.784, 0.707, 0.408, 0.171, 0.699, 0.689, 0.675, 0.413],
  [0.780, 0.707, 0.363, 0.168, 0.695, 0.875, 0.854, 0.475],
  [0.980, 0.901, 0.514, 0.410, 0.512, 0.597, 0.522, 0.342],
  [0.915, 0.703, 0.517, 0.410, 0.612, 0.529, 0.532, 0.409],
  [0.265, 0.205, 0.428, 0.615, 1.175, 1.371, 1.352, 0.152],
  [1.674, 1.532, 1.190, 1.095, 0.384, 0.232, 0.532, 1.290]
];

float Dmax = 1e9;

// ---------- Decision variables ----------
dvar boolean y[p in POINTS][s in STATIONS];   // assignment (≤1 station per point)
dvar int+    x[s in STATIONS][t in TYPES];    // charger count per type
dvar int+    sTot[s in STATIONS];             // total stalls per station
dvar float+  L[s in STATIONS];                // load served at station
dvar float+  u[s in STATIONS];
dvar float+  v[s in STATIONS];

dexpr float Lbar = (sum(s in STATIONS) L[s]) / card(STATIONS);

// ---------- Objective ----------
dexpr float F1 = - sum(s in STATIONS) L[s];
dexpr float F2 =   alpha * sum(s in STATIONS) (u[s] + v[s]);
dexpr float F3 =   beta  * sum(s in STATIONS, t in TYPES) (x[s][t] * areaT[t]);

dexpr float OBJ = w1*F1 + w2*F2 + w3*F3;
minimize OBJ;

// ---------- Constraints ----------
subject to {

  // stall aggregation
  forall(s in STATIONS)
    sum(t in TYPES) x[s][t] == sTot[s];

  // station stall bounds
  forall(s in STATIONS)
    s_lb[s] <= sTot[s] <= s_ub[s];

  // station load from assigned demand
  forall(s in STATIONS)
    L[s] == sum(p in POINTS, t in TYPES) ( EVcount[p][t] * SCF[t] * powerT[t] * y[p][s] );

  // capacity by installed chargers
  forall(s in STATIONS)
    L[s] <= sum(t in TYPES) ( x[s][t] * powerT[t] );

  // each demand point to at most one station
  forall(p in POINTS)
    sum(s in STATIONS) y[p][s] <= 1;

  // charger upper bounds
  forall(s in STATIONS, t in TYPES)
    0 <= x[s][t] <= maxCharger[s][t];

  // policy: bus chargers only at CC-BDX
  forall(s in STATIONS : s != BDX)
    x[s][BUS] == 0;

  // load-balance auxiliaries
  forall(s in STATIONS) {
    u[s] >=  L[s] - Lbar;
    v[s] >=  Lbar - L[s];
  }

  // distance cap (disable infeasible assignments)
  forall(p in POINTS, s in STATIONS : DIST[p][s] > Dmax)
    y[p][s] == 0;
}

// ---------- Report ----------
// ---------- Report ----------
execute {
  writeln("F1 = ", F1);
  writeln("F2 = ", F2);
  writeln("F3 = ", F3);
  writeln("OBJ = ", OBJ);
  writeln("---- Station summary ----");

  for (var s in STATIONS) {
    write(s, " | sTot=", sTot[s], " | L=", L[s], " | x=[");
    var first = 1;
    for (var t in TYPES) {
      if (!first) write(", ");
      write(x[s][t]);
      first = 0;
    }
    writeln("]");
  }
}

execute {
  writeln("---- x[s][t] (chargers by type) ----");
  for (var s in STATIONS) {
    var first = 1; write(s, ": [");
    for (var t in TYPES) { if (!first) write(", "); write(t, "=", x[s][t]); first=0; }
    writeln("]  | sTot=", sTot[s]);
  }
}

execute {
  writeln("Bus chargers check (must be 0 except CC-BDX):");
  for (var s in STATIONS) writeln(s, " -> ", x[s]["bus"]);
}
