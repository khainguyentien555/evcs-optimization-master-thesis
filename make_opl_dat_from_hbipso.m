function make_opl_dat_from_hbipso(mode)
% MAKE_OPL_DAT_FROM_HBIPSO  Xuất .dat cho OPL từ kết quả HBIPSO
% mode = 'fixlb' (đặt lower bounds x theo loại) 
%     hoặc 'warm' (đưa MIP start x0,y0)
S = load('evcs_data.mat');      % gồm: POINTS, STATIONS, TYPES, EVcount, DIST, maxCharger, ...
R = load('hbipso_best.mat');    % CSP, s, x, gbest
T = readtable('chargers_by_type_per_station.csv'); % từ hậu xử lý

points  = string(S.POINTS(:));
stations= string(S.STATIONS(:));
types   = string(S.TYPES(:));

% Map chỉ số loại:
t11  = find(types=="xe_may");
t60a = find(types=="oto5");
t60b = find(types=="oto7");
t60c = find(types=="taxi5");
t60d = find(types=="taxi7");
t150 = find(types=="bus");

% Đọc phân bổ theo loại (TRỤ -> CHARGER không cần cho OPL; OPL dùng x = số trụ)
s11  = T.Stalls_11kW;
s60  = T.Stalls_60kW;
s150 = T.Stalls_150kW;

% Xây ma trận x_lb (m x |TYPES|)
m = numel(stations); k = numel(types);
x_lb = zeros(m,k);
x_lb(:,t11)  = s11;
x_lb(:,t60a) = floor(s60.*0.25);  % chia đều 4 nhóm 60kW (có thể thay đổi chính sách)
x_lb(:,t60b) = ceil(s60.*0.25);
x_lb(:,t60c) = floor(s60.*0.25);
x_lb(:,t60d) = s60 - (x_lb(:,t60a)+x_lb(:,t60b)+x_lb(:,t60c));
x_lb(:,t150) = s150;

% Warm start từ HBIPSO:
x0 = zeros(m,k);
x0(:,t11)  = x_lb(:,t11);
x0(:,t60a) = x_lb(:,t60a);
x0(:,t60b) = x_lb(:,t60b);
x0(:,t60c) = x_lb(:,t60c);
x0(:,t60d) = x_lb(:,t60d);
x0(:,t150) = x_lb(:,t150);

% y0 từ ma trận gán R.x (n x m) one-hot
y0 = R.x>0;  % logic -> 0/1

% Ghi .dat cho OPL
switch lower(mode)
    case 'fixlb'
        datfile = 'evcs_from_hbipso_fixlb.dat';
        write_opl_dat(datfile, points, stations, types, S.EVcount, S.DIST, S.maxCharger, ...
            'alpha', 0.00036, 'beta', 0.00215, 'w1', 0.33, 'w2', 0.33, 'w3', 0.33, ...
            'lb_x', x_lb, 'mipstart_x', [], 'mipstart_y', []);
    case 'warm'
        datfile = 'evcs_from_hbipso_warm.dat';
        write_opl_dat(datfile, points, stations, types, S.EVcount, S.DIST, S.maxCharger, ...
            'alpha', 0.00036, 'beta', 0.00215, 'w1', 0.33, 'w2', 0.33, 'w3', 0.33, ...
            'lb_x', zeros(m,k), 'mipstart_x', x0, 'mipstart_y', y0);
    otherwise
        error('mode phải là fixlb hoặc warm');
end
fprintf('→ Wrote %s\n', datfile);
end
