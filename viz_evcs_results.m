function viz_evcs_results(saveSvg)
% VIZ_EVCS_RESULTS  Vẽ bộ hình cho kết quả HBIPSO-GR (và so với CPLEX nếu có số)
% Cách dùng:
%   viz_evcs_results          % xem & lưu PNG
%   viz_evcs_results(true)    % xem & lưu PNG + cố gắng lưu SVG
%
% Yêu cầu: 'evcs_data.mat' và 'hbipso_best.mat' trong thư mục hiện tại.

if nargin<1, saveSvg = false; end  % mặc định chỉ lưu PNG (tránh lỗi SVG trên vài cài đặt)
clc; close all; if ~exist('figs','dir'), mkdir('figs'); end

%% --------- Load data & solution ---------
S  = load('evcs_data.mat');     % D, dist, Astall, Cmax, Q, Dmax, w1..w3, STATIONS
HB = load('hbipso_best.mat');   % CSP, s, x, gbest

D      = S.D(:);
dist   = S.dist;
Astall = S.Astall(:);
Cmax   = S.Cmax(:);
Q      = S.Q;
namesJ = string(S.STATIONS(:));

x   = HB.x;                    % n x m one-hot
s   = HB.s(:);                 % m x 1
CSP = HB.CSP(:)>0;             % logical open sites

loadJ = x' * D;                % tải tại trạm
capJ  = s * Q;                 % công suất trạm
Lbar  = sum(D)/numel(loadJ);

alpha = 0.00036; beta = 0.00215;
F1_served = sum(min(loadJ,capJ));
F1_ratio  = F1_served / sum(D);
F2_L1     = alpha * sum(abs(loadJ - Lbar));
F3_beta   = beta * sum(s .* Astall);
Z    = S.w1*(-F1_ratio) + S.w2*F2_L1 + S.w3*F3_beta;

%% --------- (Tuỳ chọn) điền số CPLEX để so sánh ----------
% Nếu chưa có, để [] là được.
cplex.time_sec  = [];       % ví dụ: 12.34
cplex.F1_served = [];       % cùng đơn vị với D
cplex.F2_L1     = [];       % đã nhân alpha
cplex.F3_beta   = [];       % đã nhân beta
if ~isempty(cplex.F1_served)
    cplex.F1_ratio = cplex.F1_served / sum(D);
    cplex.Z   = S.w1*(-cplex.F1_ratio) + S.w2*cplex.F2_L1 + S.w3*cplex.F3_beta;
end

%% --------- Figure 1: HBIPSO vs CPLEX (các thước đo tổng hợp) ----------
metrics = ["F1 served","F2 (\alpha·L1)","F3 (\beta·area)","Z"];
hb_vals = [F1_served, F2_L1, F3_beta, Z];

fig1 = figure('Color','w');
if isempty(cplex.F1_served)
    bar(hb_vals); xticklabels(metrics); ylabel('Value'); title('HBIPSO-GR metrics');
    legend('HBIPSO-GR','Location','northeast'); grid on;
else
    M = [hb_vals; [cplex.F1_served, cplex.F2_L1, cplex.F3_beta, cplex.Z]];
    bar(M.'); xticklabels(metrics); ylabel('Value'); title('HBIPSO-GR vs CPLEX');
    legend({'HBIPSO-GR','CPLEX'},'Location','northeast'); grid on;
end
export_figs(fig1,'figs/01_compare',saveSvg);

%% --------- Figure 2: Load vs Capacity (đánh dấu open/closed) ----------
[~,order] = sort(CSP,'descend'); % sắp xếp: trạm mở trước
fig2 = figure('Color','w');
bar([loadJ(order), capJ(order)], 'grouped');
xlabel('Station (sorted: open \rightarrow closed)'); ylabel('Demand units');
title('Load vs Capacity per station');
xticklabels(namesJ(order)); xtickangle(45); grid on;
legend({'Load','Capacity'},'Location','northeast');
hold on; yMax = max(max([loadJ,capJ]))*1.08;
for k=1:numel(order)
    if CSP(order(k)), plot(k,yMax,'^','MarkerSize',6,'LineWidth',1);
    else,             plot(k,yMax,'v','MarkerSize',6,'LineWidth',1);
    end
end
text(0.5,yMax*1.01,'^ open   v closed');
export_figs(fig2,'figs/02_load_vs_cap',saveSvg);

%% --------- Figure 3: Số trụ theo trạm (bar ngang) ----------
fig3 = figure('Color','w');
[ss,ix] = sort(s,'descend');
barh(ss);
yticklabels(namesJ(ix)); xlabel('# Stalls'); title('Stalls allocation by station'); grid on;
export_figs(fig3,'figs/03_stalls',saveSvg);

%% --------- Figure 4: Heatmap ma trận gán x ----------
fig4 = figure('Color','w');
imagesc(x(:,order)); colormap(gray); colorbar; caxis([0 1]);
xlabel('Station (sorted)'); ylabel('Demand point'); title('Assignment matrix x (1=assigned)');
export_figs(fig4,'figs/04_heatmap_assign',saveSvg);

%% --------- Figure 5: Heatmap khoảng cách của gán ----------
Dchosen = nan(size(x)); Dchosen(x==1) = dist(x==1);
fig5 = figure('Color','w');
imagesc(Dchosen(:,order)); colorbar;
xlabel('Station (sorted)'); ylabel('Demand point');
title(sprintf('Distances of assignments (km)   D_{max}=%.2f km',S.Dmax));
export_figs(fig5,'figs/05_heatmap_dist',saveSvg);

%% --------- Figure 6: Bubble plot tải theo trạm ----------
fig6 = figure('Color','w');
scatter(1:numel(loadJ), loadJ, 10 + 80*(loadJ/max(loadJ)+eps), 'filled'); grid on;
xlabel('Station index'); ylabel('Load');
title('Station loads (bubble size \propto load)');
xticks(1:numel(loadJ)); xticklabels(namesJ); xtickangle(45);
export_figs(fig6,'figs/06_bubble_load',saveSvg);

%% --------- Console summary ----------
fprintf('\nHBIPSO-GR: Served=%.2f/%.2f | F2(α·L1)=%.4f | F3(β·area)=%.4f | Z=%.4f\n', ...
    F1_served, sum(D), F2_L1, F3_beta, Z);
if ~isempty(cplex.F1_served)
    fprintf('CPLEX    : Served=%.2f/%.2f | F2(α·L1)=%.4f | F3(β·area)=%.4f | Z=%.4f\n', ...
        cplex.F1_served, sum(D), cplex.F2_L1, cplex.F3_beta, cplex.Z);
end
disp('Saved PNG (và SVG nếu bật) vào thư mục ./figs');

end

% ---- helper: lưu ảnh PNG + (tuỳ chọn) SVG, có fallback để tránh lỗi ----
function export_figs(fig, base, saveSvg)
    % PNG luôn lưu
    exportgraphics(fig, [base '.png'], 'Resolution',300);

    % SVG: có hệ thống không hỗ trợ => try/catch + fallback 'print'
    if saveSvg
        ok = true;
        try
            exportgraphics(fig, [base '.svg']);   % cách 1
        catch
            ok = false;
        end
        if ~ok
            try
                print(fig, [base '.svg'], '-dsvg');  % cách 2
            catch
                warning('SVG chưa hỗ trợ ở cài đặt hiện tại. Đã lưu PNG.');
            end
        end
    end
end
