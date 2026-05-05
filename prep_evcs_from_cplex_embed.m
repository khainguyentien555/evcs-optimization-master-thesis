%% prep_evcs_from_cplex_embed.m  — CORRECTED VERSION
%  Aligns F1/F2/F3 definitions with the CPLEX MOMIP formulation in the paper.
%  Key changes vs original:
%    - Computes F1_ref, F2_ref, F3_ref for normalization (saved to .mat)
%    - alpha/beta scaling retained as 1 (normalization handles scaling)
clear; clc;

%% A) Config
isDistanceInMeters = true;

%% B) Sets & parameters from .mod
POINTS = {'LK1','LK2','LK3','LK4','LK5','LK6','LK7','LK8','LK9','LK10', ...
  'LK11','LK12','LK13','LK14','LK15','LK16','LK17','LK18','LK19','LK20', ...
  'LK21','LK22','LK23','LK24','LK25','LK26','LK27','LK28','LK29', ...
  'BT1','BT2','BT3','BT4','CC-HH1','CC-HH2'};

STATIONS = {'CC-TM1','CC-HH1','CC-TT1','CC-TM2','CC-TM3','CC-BDX','CC-HH2','CC-TLC'};
TYPES    = {'xe_may','oto5','oto7','taxi5','taxi7','bus'};

SCF    = [0.35, 0.35, 0.35, 0.34, 0.34, 0.44];
areaT  = [1.48, 12.5, 13.2, 12.5, 13.2, 40.0];
powerT = [3.5, 11, 22, 11, 22, 150];

EVcount = [ ...
  35  5  2  0  0  0; 38  7  1  0  0  0; 40  6  3  0  0  0; 41  5  2  0  0  0; 39  6  1  0  0  0;
  36  6  2  0  0  0; 34  7  3  0  0  0; 37  6  2  0  0  0; 38  5  3  0  0  0; 36  6  2  0  0  0;
  35  5  2  0  0  0; 37  7  1  0  0  0; 39  6  3  0  0  0; 38  5  2  0  0  0; 36  6  1  0  0  0;
  37  5  3  0  0  0; 38  6  2  0  0  0; 40  5  1  0  0  0; 39  6  2  0  0  0; 37  5  3  0  0  0;
  35  7  1  0  0  0; 36  6  3  0  0  0; 38  5  2  0  0  0; 37  6  1  0  0  0; 39  5  3  0  0  0;
  40  6  2  0  0  0; 38  5  1  0  0  0; 36  6  2  0  0  0; 35  7  3  0  0  0;
  34  6  2  0  0  0; 36  5  3  0  0  0; 37  7  1  0  0  0; 39  6  2  0  0  0;
  120 40 20 82 82  0; 130 50 25 121 121 0];

maxCharger = [ ...
 100 50 50 30 30  0;
 100 50 50 30 30  0;
 100 50 50 30 30  0;
 100 50 50 30 30  0;
 100 50 50 30 30  0;
  50 30 30  0  0 10;
 100 50 50 30 30  0;
  80 40 40 20 20  0];

w1_raw = 1/3; w2_raw = 1/3; w3_raw = 1/3;   % balanced weights — same as B&C

%% C) Distance matrix [POINTS x STATIONS] in metres
DIST = [ ...
   483  229  292  574 1117 1376 1467 1202;
   585  359  172  642  996 1072 1178 1291;
   312  160  132  322  907 1098 1207  987;
   329  186  301  466  972 1142 1301 1186;
   204  228  325  459 1236 1398 1438  996;
   214  241  207  353 1088 1294 1305 1009;
   680  633  211   70  733  869  849  521;
  1002  879  496  434  346  469  484  238;
  1193 1025  706  605  545  644  621  484;
   605  423  239  382  629  799  790  578;
  1111  763  581  371  241  617  917  739;
   687  525  328  392  532 1007 1370  558;
   862  613  352  329  599 1032 1370  772;
   858  643  300  342  805 1041  844  739;
   606  510  312  762  687  844 1091  605;
   963  728  617  666  931  658  258  819;
   903  689  515  542  336  518  617  451;
  1105  830  615  665  258  627  549  304;
  1140  951  660  725  150  369  382  430;
   981  792  526  543  224  290  503  431;
  1011  848  525  490  230  417  433  320;
  1085  945  586  546  279  488  390  314;
  1089  972  598  466  415  331  409  260;
  1260 1120  705  672  498  495  391  123;
  1342 1299  903  839  382  332  351  115;
  1436 1255  930  730  817  332  101  123;
  1366 1166  886  861   60  374   84  349;
  1386 1190  934  931   95  810  244  283;
  1228 1007  802  832  195  309  484  291;
   784  707  408  171  699  689  675  413;
   780  707  363  168  695  875  854  475;
   980  901  514  410  512  597  522  342;
   915  703  517  410  612  529  532  409;
   265  205  428  615 1175 1371 1352  152;
  1674 1532 1190 1095  384  232  532 1290];

%% D) Unit conversion & sizes
dist = DIST / 1000;   % metres -> km
[n, m] = size(dist);
assert(m == numel(STATIONS), 'Column mismatch: DIST vs STATIONS.');
assert(n == numel(POINTS),   'Row mismatch: DIST vs POINTS.');

%% E) Build core inputs
D     = EVcount * SCF(:);        % [n x 1] effective simultaneous demand
Cmax  = sum(maxCharger, 2);      % [m x 1] total charger upper bound per station

demType  = sum(EVcount, 1) .* SCF;
pt       = demType / max(sum(demType), eps);
A_eff    = sum(pt .* areaT);     % effective m² per stall (weighted average)
Astall   = A_eff * ones(m, 1);

Q    = 1;                        % 1 stall serves 1 demand unit
Dmax = max(dist(:));             % use actual max distance as fallback

S_w  = w1_raw + w2_raw + w3_raw;
w1   = w1_raw / S_w;
w2   = w2_raw / S_w;
w3   = w3_raw / S_w;

%% F) Normalization reference values  <-- NEW: required to match B&C formulation
%
%  F1_ref = total demand (F̂1 = served / F1_ref → in [0,1])
%  F2_ref = worst-case pairwise deviation:
%           C(m,2) * total_demand (all demand in one station, rest zero)
%  F3_ref = maximum land use (all stations open at Cmax)
%
F1_ref = sum(D);                          % = 793.94
F2_ref = (m*(m-1)/2) * sum(D);           % = 28 * 793.94 = 22230.3
F3_ref = sum(Cmax .* Astall);            % max total stall area

fprintf('--- Normalization reference values ---\n');
fprintf('  F1_ref (total demand)     = %.4f\n', F1_ref);
fprintf('  F2_ref (max pairwise dev) = %.4f\n', F2_ref);
fprintf('  F3_ref (max land use)     = %.4f\n', F3_ref);

%% G) Penalty coefficients (unchanged)
rhoU = 1.0; rhoVcap = 1.0; rhoVdist = 1.0; rhoVlogic = 5.0; lambda_pen = 10.0;

%% H) Save
save('evcs_data.mat', ...
     'D', 'dist', 'Astall', 'Cmax', 'Q', 'Dmax', ...
     'w1', 'w2', 'w3', ...
     'F1_ref', 'F2_ref', 'F3_ref', ...        % <-- NEW
     'rhoU', 'rhoVcap', 'rhoVdist', 'rhoVlogic', 'lambda_pen', ...
     'POINTS', 'STATIONS', 'TYPES', 'SCF', 'areaT', 'powerT', 'EVcount', 'maxCharger');

fprintf('\n[OK] evcs_data.mat saved | n=%d, m=%d | sum(D)=%.4f | A_eff=%.4f m2/stall\n', ...
    n, m, sum(D), A_eff);
% --- Start timing ---
tStart = tic;

best = hbipso_gr_evcs();

runtime_sec = toc(tStart);

fprintf('\nBIPSO-GR runtime: %.4f seconds\n', runtime_sec);