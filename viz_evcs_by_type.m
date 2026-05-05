function viz_evcs_by_type()
% Vẽ stacked bars theo loại trụ/charger từ bảng hậu xử lý.
% Yêu cầu: chargers_by_type_per_station.csv (tạo bởi post_split_chargers_by_type)

clc; close all;

csvFile = 'chargers_by_type_per_station.csv';
if ~exist(csvFile,'file')
    if exist('post_split_chargers_by_type.m','file')
        fprintf('Chưa thấy %s → chạy post_split_chargers_by_type...\n', csvFile);
        post_split_chargers_by_type;
    else
        error('Không có %s và cũng không có hàm post_split_chargers_by_type.m', csvFile);
    end
end

T = readtable(csvFile);

% Sắp xếp: trạm mở trước, trong mỗi nhóm sắp theo tổng trụ giảm dần
[~,ord] = sortrows([~T.Open, -T.Stalls_total], [1 2]);  % Open=true trước; rồi giảm dần tổng trụ
T = T(ord,:);

names = string(T.Station);
S11 = T.Stalls_11kW; S60 = T.Stalls_60kW; S150 = T.Stalls_150kW;
C11 = T.Chargers_11kW; C60 = T.Chargers_60kW; C150 = T.Chargers_150kW;

% ---- Figure A: Stalls by type (stacked) ----
figA = figure('Color','w'); 
bar([S11 S60 S150], 'stacked');
xticklabels(names); xtickangle(45);
ylabel('# Stalls'); title('Stalls per station by type (11/60/150 kW)');
legend({'11 kW','60 kW','150 kW'},'Location','northeast'); grid on;

% ---- Figure B: Chargers by type (stacked) ----
figB = figure('Color','w'); 
bar([C11 C60 C150], 'stacked');
xticklabels(names); xtickangle(45);
ylabel('# Chargers'); title('Chargers per station by type (11/60/150 kW)');
legend({'11 kW','60 kW','150 kW'},'Location','northeast'); grid on;

% Lưu ảnh
if ~exist('figs','dir'), mkdir('figs'); end
exportgraphics(figA,'figs/07_stalls_by_type.png','Resolution',300);
exportgraphics(figB,'figs/08_chargers_by_type.png','Resolution',300);

disp('Saved figs to ./figs (07,08).');
end
