%% Input data to HBIPSO-GR (embed distance matrix) — CLEAN
clear; clc;

%% A) Config
isDistanceInMeters = true;   % Khoảng cách là mét

%% B) Sets & parameters
POINTS = {'LK1','LK2','LK3','LK4','LK5','LK6','LK7','LK8','LK9','LK10', ...
  'LK11','LK12','LK13','LK14','LK15','LK16','LK17','LK18','LK19','LK20', ...
  'LK21','LK22','LK23','LK24','LK25','LK26','LK27','LK28','LK29', ...
  'BT1','BT2','BT3','BT4','CC-HH1','CC-HH2'}; 

STATIONS = {'CC-TM1','CC-HH1','CC-TT1','CC-TM2','CC-TM3','CC-BDX','CC-HH2','CC-TLC'};
TYPES = {'xe_may','oto5','oto7','taxi5','taxi7','bus'};

SCF    = [0.35, 0.35, 0.35, 0.34, 0.34, 0.44];
areaT  = [1.48, 12.5, 13.2, 12.5, 13.2, 40.0];
powerT = [3.5, 11, 22, 11, 22, 150]; 

% EVcount[POINTS][TYPES]
EVcount = [ ...
  35  5  2  0  0  0; 38  7  1  0  0  0; 40  6  3  0  0  0; 41  5  2  0  0  0; 39  6  1  0  0  0;
  36  6  2  0  0  0; 34  7  3  0  0  0; 37  6  2  0  0  0; 38  5  3  0  0  0; 36  6  2  0  0  0;
  35  5  2  0  0  0; 37  7  1  0  0  0; 39  6  3  0  0  0; 38  5  2  0  0  0; 36  6  1  0  0  0;
  37  5  3  0  0  0; 38  6  2  0  0  0; 40  5  1  0  0  0; 39  6  2  0  0  0; 37  5  3  0  0  0;
  35  7  1  0  0  0; 36  6  3  0  0  0; 38  5  2  0  0  0; 37  6  1  0  0  0; 39  5  3  0  0  0;
  40  6  2  0  0  0; 38  5  1  0  0  0; 36  6  2  0  0  0; 35  7  3  0  0  0;
  34  6  2  0  0  0; 36  5  3  0  0  0; 37  7  1  0  0  0; 39  6  2  0  0  0;
  120 40 20 82 82  0; 130 50 25 121 121 0];

% maxCharger[STATIONS][TYPES] (8x6)
maxCharger = [ ...
 100 50 50 30 30  0;
 100 50 50 30 30  0;
 100 50 50 30 30  0;
 100 50 50 30 30  0;
 100 50 50 30 30  0;
  50 30 30  0  0 10;
 100 50 50 30 30  0;
  80 40 40 20 20  0];

% Weights from .mod ()
w1_raw = 1/3; w2_raw = 0.33; w3_raw = 0.33; 

%% C) Distance matrix DIST[POINTS x STATIONS] — dán từ Excel (mét)
% Cột theo STATIONS: CC-TM1 | CC-HH1 | CC-TT1 | CC-TM2 | CC-TM3 | CC-BDX | CC-HH2 | CC-TLC
DIST = [ ...
   483  229  292  574 1117 1376 1467 1202;   % LK1
   585  359  172  642  996 1072 1178 1291;   % LK2
   312  160  132  322  907 1098 1207  987;   % LK3
   329  186  301  466  972 1142 1301 1186;   % LK4
   204  228  325  459 1236 1398 1438  996;   % LK5
   214  241  207  353 1088 1294 1305 1009;   % LK6
   680  633  211   70  733  869  849  521;   % LK7
  1002  879  496  434  346  469  484  238;   % LK8
  1193 1025  706  605  545  644  621  484;   % LK9
   605  423  239  382  629  799  790  578;   % LK10
  1111  763  581  371  241  617  917  739;   % LK11
   687  525  328  392  532 1007 1370  558;   % LK12
   862  613  352  329  599 1032 1370  772;   % LK13
   858  643  300  342  805 1041  844  739;   % LK14
   606  510  312  762  687  844 1091  605;   % LK15
   963  728  617  666  931  658  258  819;   % LK16
   903  689  515  542  336  518  617  451;   % LK17
  1105  830  615  665  258  627  549  304;   % LK18
  1140  951  660  725  150  369  382  430;   % LK19
   981  792  526  543  224  290  503  431;   % LK20
  1011  848  525  490  230  417  433  320;   % LK21
  1085  945  586  546  279  488  390  314;   % LK22
  1089  972  598  466  415  331  409  260;   % LK23
  1260 1120  705  672  498  495  391  123;   % LK24
  1342 1299  903  839  382  332  351  115;   % LK25
  1436 1255  930  730  817  332  101  123;   % LK26
  1366 1166  886  861   60  374   84  349;   % LK27
  1386 1190  934  931   95  810  244  283;   % LK28
  1228 1007  802  832  195  309  484  291;   % LK29
   784  707  408  171  699  689  675  413;   % BT1
   780  707  363  168  695  875  854  475;   % BT2
   980  901  514  410  512  597  522  342;   % BT3
   915  703  517  410  612  529  532  409;   % BT4
   265  205  428  615 1175 1371 1352  152;   % CC-HH1
  1674 1532 1190 1095  384  232  532 1290];  % CC-HH2

%% D) Unit conversion & sizes
if isDistanceInMeters
    dist = DIST/1000;  % m -> km
else
    dist = DIST;
end
[n,m] = size(dist);
assert(m==numel(STATIONS),'DIST: số cột (%d) phải bằng số trạm (%d).',m,numel(STATIONS));
assert(n==numel(POINTS),'DIST: số hàng (%d) phải bằng số điểm (%d).',n,numel(POINTS));

%% E) Build HBIPSO-GR inputs
D = EVcount * SCF(:);              % n x 1 (nhu cầu chuẩn hoá)
Cmax = sum(maxCharger,2);          % m x 1

demType = sum(EVcount,1).*SCF;
pt = demType ./ max(sum(demType),eps);
A_eff = sum(pt .* areaT);          % m^2/trụ hiệu dụng
Astall = A_eff * ones(m,1);

Q = 1;                             % 1 trụ phục vụ 1 đơn vị D
Dmax = max(dist(:));               

S = (w1_raw + w2_raw + w3_raw);
w1 = w1_raw/S; w2 = w2_raw/S; w3 = w3_raw/S;

rhoU=1.0; rhoVcap=1.0; rhoVdist=1.0; rhoVlogic=5.0; lambda_pen=10.0;

%% F) Save .mat
save('evcs_data.mat','D','dist','Astall','Cmax','Q','Dmax','w1','w2','w3', ...
     'rhoU','rhoVcap','rhoVdist','rhoVlogic','lambda_pen', ...
     'POINTS','STATIONS','TYPES','SCF','areaT','powerT','EVcount','maxCharger');

fprintf('✓ evcs_data.mat saved | n=%d, m=%d | Sum D=%.2f | A_eff=%.2f | Total Cmax=%d\n', ...
    n,m,sum(D),A_eff,sum(Cmax));
