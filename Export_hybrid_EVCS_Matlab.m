% viz_evcs_quickplots.m — SCRIPT vẽ nhanh & lưu hình inputs EVCS
% Chạy trực tiếp: chỉ cần evcs_data.mat (và hbipso_best.mat nếu có)

close all; clc; saveSvg = false;   % đổi thành true nếu muốn xuất SVG
outdir = "figs"; if ~exist(outdir,'dir'), mkdir(outdir); end

% ==== Load dữ liệu ====
D = load('evcs_data.mat');  H = [];
if exist('hbipso_best.mat','file'), H = load('hbipso_best.mat'); end

% ---- Lấy biến với fallback tên ----
POINTS     = getf(D, {'POINTS','points'});
STATIONS   = getf(D, {'STATIONS','stations'});
TYPES      = getf(D, {'TYPES','types'});
EVcount    = getf(D, {'EVcount'});
maxCharger = getf(D, {'maxCharger'});
SCF        = getf(D, {'SCF','scf'});
areaT      = getf(D, {'areaT','area'});
powerT     = getf(D, {'powerT','power'});
DIST_m     = getf(D, {'DIST','dist','Dist'});

% ---- Chuẩn hoá ----
if iscell(EVcount),    EVcount = cell2mat(EVcount); end
if iscell(maxCharger), maxCharger = cell2mat(maxCharger); end
if iscell(DIST_m),     DIST_m = cell2mat(DIST_m); end
if iscell(SCF),        SCF = cell2mat(SCF); end
if iscell(areaT),      areaT = cell2mat(areaT); end
if iscell(powerT),     powerT = cell2mat(powerT); end
SCF = SCF(:)'; areaT = areaT(:)'; powerT = powerT(:)';

% km nếu giống mét
if mean(DIST_m(:),'omitnan')>20, DIST = DIST_m/1000; else, DIST = DIST_m; end

% ---- Chỉ số & bounds ----
J = numel(STATIONS); T = numel(TYPES);
idxBDX = find(strcmpi(STATIONS,'CC-BDX'),1);
if isfield(D,'s_lb'), s_lb = D.s_lb(:)'; else, s_lb = ones(1,J); end
if isfield(D,'s_ub'), s_ub = D.s_ub(:)'; else, s_ub = max(s_lb, s_lb+3); end

% ---- Kết quả HBIPSO (nếu có) ----
CSP = []; s = []; x = [];
if ~isempty(H)
    if isfield(H,'CSP'), CSP = H.CSP; end
    if isfield(H,'s'),   s   = H.s;   end
    if isfield(H,'x'),   x   = H.x;   end
end

%% (1) Bounds số trụ theo trạm
f1 = figure('Color','w');
bar(1:J, s_ub, 'FaceAlpha',0.25, 'EdgeColor','none'); hold on
bar(1:J, s_lb, 'FaceAlpha',0.55, 'EdgeColor','none');
if ~isempty(s), plot(1:J, s(:),'k.-','LineWidth',1.5,'MarkerSize',16); end
grid on; xlim([0.5 J+0.5]); xticks(1:J); xticklabels(STATIONS); xtickangle(30);
ylabel('Số trụ (stall)'); title('Giới hạn s\_lb / s\_ub (và s nếu có)');
legend({'s\_ub','s\_lb','s (HBIPSO)'},'Location','northwest');
exportgraphics(f1, fullfile(outdir,'01_stall_bounds.png'), 'Resolution',300);
if saveSvg, exportgraphics(f1, fullfile(outdir,'01_stall_bounds.svg'),'ContentType','vector'); end

% Heatmap xoay ngang (trục X dài = số POINTS)
f2 = figure('Color','w','Units','pixels','Position',[100 100 1400 600]);
imagesc(DIST'); axis image;  % chú ý: transpose
colorbar;
xlabel('POINTS'); ylabel('STATIONS'); title('Khoảng cách (km)');
xticks(1:numel(POINTS)); xticklabels(POINTS); xtickangle(0);  % hoặc 45
yticks(1:J); yticklabels(STATIONS);
exportgraphics(f2, fullfile(outdir,'02_distance_heatmap_transposed.png'), 'Resolution',300);


%% (3) Nhu cầu theo loại (stacked)
if numel(SCF)==T, demandT = sum(EVcount,1).*SCF; else, demandT = sum(EVcount,1); end
f3 = figure('Color','w');
bar(categorical(TYPES), demandT, 'stacked'); grid on
ylabel('Tổng nhu cầu (đã nhân SCF nếu có)'); title('Tổng nhu cầu theo loại');
exportgraphics(f3, fullfile(outdir,'03_demand_by_type.png'), 'Resolution',300);
if saveSvg, exportgraphics(f3, fullfile(outdir,'03_demand_by_type.svg'),'ContentType','vector'); end

%% (4) Công suất & diện tích theo loại
f4 = figure('Color','w'); tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; bar(categorical(TYPES), powerT); grid on; title('Công suất/loại (kW)'); ylabel('kW');
nexttile; bar(categorical(TYPES), areaT);  grid on; title('Diện tích/loại (m^2)'); ylabel('m^2 (tương đối)');
exportgraphics(f4, fullfile(outdir,'04_power_area_by_type.png'), 'Resolution',300);
if saveSvg, exportgraphics(f4, fullfile(outdir,'04_power_area_by_type.svg'),'ContentType','vector'); end

%% (5) Heatmap maxCharger (trạm x loại)
f5 = figure('Color','w');
imagesc(maxCharger); colorbar; axis tight
yticks(1:J); yticklabels(STATIONS); xticks(1:T); xticklabels(TYPES); xtickangle(45);
title('Giới hạn số sạc theo loại & trạm');
exportgraphics(f5, fullfile(outdir,'05_maxCharger_heatmap.png'), 'Resolution',300);
if saveSvg, exportgraphics(f5, fullfile(outdir,'05_maxCharger_heatmap.svg'),'ContentType','vector'); end

%% (6) Tuỳ chọn: trạng thái mở trạm & tổng trụ
if ~isempty(CSP) || ~isempty(s)
    f6 = figure('Color','w');
    yyaxis left
    if ~isempty(CSP), bar(1:J, double(CSP(:)>0.5)); ylabel('Mở trạm (0/1)'); end
    yyaxis right
    if ~isempty(s),  plot(1:J, s(:),'o-','LineWidth',1.5,'MarkerSize',6); end
    grid on; xlim([0.5 J+0.5]); xticks(1:J); xticklabels(STATIONS); xtickangle(30);
    title('Trạng thái mở trạm và tổng trụ (HBIPSO)');
    exportgraphics(f6, fullfile(outdir,'06_station_open_and_stalls.png'), 'Resolution',300);
    if saveSvg, exportgraphics(f6, fullfile(outdir,'06_station_open_and_stalls.svg'),'ContentType','vector'); end
end

disp('✅ Đã xuất hình vào thư mục ./figs');

% ==== helper nhỏ ====
function v = getf(S, names)
    v = []; for k=1:numel(names), if isfield(S,names{k}), v = S.(names{k}); return; end, end
    error("Thiếu biến: %s", strjoin(names,'/'));
end
