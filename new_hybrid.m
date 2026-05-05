% HYBRID_HBIPSO_BC (one-click)
% Yêu cầu: evcs_data.mat, hbipso_best.mat (từ HBIPSO-GR đã chạy)
% Python 3.11 + DOcplex + CPLEX 22.1 sẵn trong PATH (cplex/bin vào PATH)
% Tác vụ: (1) nạp dữ liệu & nghiệm PSO; (2) ép chính sách; (3) xuất warm-start;
%        (4) gọi B&C (DOcplex) để refine cục bộ; (5) nạp kết quả cuối.

clear; clc;

%% 1) Nạp dữ liệu & nghiệm PSO
S = load('evcs_data.mat');                 % EVcount, SCF, DIST, STATIONS, TYPES, ...
B = load('hbipso_best.mat');               % CSP (logical), s (int), x (assign), gbest, ...

STATIONS = S.STATIONS(:)';                 % cellstr 1xJ
TYPES    = S.TYPES(:)';                    % {'xe_may','oto5','oto7','taxi5','taxi7','bus'}
J = numel(STATIONS); T = numel(TYPES);

% Bảo vệ field name:
assert(isfield(B,'CSP') && isfield(B,'s'), 'hbipso_best.mat thiếu CSP/s');

CSP = logical(B.CSP(:)');
s   = double(B.s(:)');                      % stalls total (or vector nếu đã tách theo type)
if ismatrix(B.s) && size(B.s,1)~=1, s = s(:)'; end

% Nếu đã có phân bổ theo type, tính tổng stalls tại mỗi trạm:
if isfield(B,'x_by_type')
    % x_by_type: J x T (số trụ theo type); nếu không có thì bỏ qua
    s_type = double(B.x_by_type);
else
    % Chưa có by-type -> giả lập theo tỷ lệ tải để warm-start DOcplex
    % Tạo s_type bằng largest remainder theo tải quy đổi D*SCF
    EV = double(S.EVcount);         % (I x T)
    D  = EV .* S.SCF(:)';           % (I x T)
    LjT = sum(D,1);                 % nhu cầu tổng theo type (1 x T)
    wT = LjT / max(sum(LjT), eps);  % trọng số type
    s_type = zeros(J,T);
    for j=1:J
        if CSP(j)==1
            base = s(j) * wT;
            s_floor = floor(base);
            r = base - s_floor;
            s_type(j,:) = s_floor;
            need = s(j) - sum(s_floor);
            if need>0
                [~,ord] = sort(r,'descend');
                s_type(j,ord(1:need)) = s_type(j,ord(1:need)) + 1;
            end
        end
    end
end

%% 2) Áp chính sách dự án
% 2.1 Bus chỉ ở CC-BDX
idxBus = find(strcmp(TYPES,'bus'));
if ~isempty(idxBus)
    for j = 1:J
        if ~strcmp(STATIONS{j},'CC-BDX')
            s_type(j,idxBus) = 0;
        end
    end
end

% 2.2 Các trạm đã đề xuất phải mở & có trụ (tối thiểu 1)
% (Sử dụng danh sách cứng hoặc S.ForcedStations nếu đã lưu trong data)
if isfield(S,'ForcedStations')
    forcedList = S.ForcedStations(:);
else
    % Ví dụ mặc định đã dùng trong luận án: TM1, HH1, HH2 (có thể sửa theo dataset bạn)
    forcedList = {'CC-TM1','CC-HH1','CC-HH2'}';
end
forcedIdx = find(ismember(STATIONS, forcedList));
CSP(forcedIdx) = true;
for k = forcedIdx'
    if sum(s_type(k,:))==0
        % Đặt 1 trụ loại "60kW" hoặc 11kW nếu không có 60kW trong TYPES
        pick = find(ismember(TYPES, {'oto5','oto7','taxi5','taxi7','xe_may'}),1,'first');
        if isempty(pick), pick = 1; end
        s_type(k,pick) = 1;
    end
end

% 2.3 Chặn bus tại các trạm khác về 0 (đảm bảo lần nữa)
if ~isempty(idxBus)
    for j=1:J
        if ~strcmp(STATIONS{j},'CC-BDX')
            s_type(j,idxBus) = 0;
        end
    end
end

% 2.4 Upper bound theo maxCharger
if isfield(S,'maxCharger')
    maxCharger = double(S.maxCharger); % J x T
    s_type = min(s_type, maxCharger);
end

%% 3) Xuất warm-start cho B&C (CSV + JSON)
outDir = "./hybrid_io";
if ~exist(outDir,'dir'), mkdir(outDir); end

% a) stations.csv
writetable(cell2table(STATIONS','VariableNames',{'Station'}), fullfile(outDir,'stations.csv'));

% b) types.csv
writetable(cell2table(TYPES','VariableNames',{'Type'}), fullfile(outDir,'types.csv'));

% c) s_type.csv (J x T)
T_s = array2table(s_type, 'VariableNames', matlab.lang.makeValidName(TYPES));
T_s.Station = STATIONS';
T_s = movevars(T_s, 'Station', 'Before', 1);
writetable(T_s, fullfile(outDir,'warmstart_s_type.csv'));

% d) policy.json
policy = struct();
policy.bus_only_station = 'CC-BDX';
policy.forced_open = forcedList(:)';
policy.delta_stalls_budget = 12;      % ngân sách tinh chỉnh tổng số trụ
policy.allow_station_flip = false;    % không cho đóng trạm đã mở bởi HBIPSO
policy.balance_radius = 6;            % ±6 trụ mỗi trạm
policy.weight = struct('w1', S.w1, 'w2', S.w2, 'w3', S.w3);
policy.alpha = S.alpha; policy.beta = S.beta;
policy.lambda_pen = S.lambda_pen;
policy_json = jsonencode(policy);
fid = fopen(fullfile(outDir,'policy.json'),'w'); fwrite(fid, policy_json); fclose(fid);

% e) data.mat (path shortcut cho Python đọc)
save(fullfile(outDir,'data_for_bc.mat'), 'S', 'STATIONS', 'TYPES');

%% 4) Gọi B&C (Python DOcplex)
%    File bc_local_refine.py phải nằm cùng thư mục script này
pycmd = sprintf('python "%s" --io "%s"', 'bc_local_refine.py', fullfile(pwd,'hybrid_io'));
status = system(pycmd);
assert(status==0, 'DOcplex B&C bị lỗi (status ~= 0).');

%% 5) Nạp kết quả cuối
resPath = fullfile(outDir,'bc_refined_solution.mat');
assert(isfile(resPath), 'Không thấy file kết quả bc_refined_solution.mat');
R = load(resPath);   % fields: s_type, obj, gaps, runtime, y_assign (optional)

fprintf('\n=== HYBRID DONE ===\n');
fprintf('Objective (refined): %.6f | Gap: %.4f%% | Time: %.1fs\n', R.obj, 100*R.gaps, R.runtime);

% Lưu hợp nhất
final = struct();
final.s_type = R.s_type;
final.STATIONS = STATIONS; final.TYPES = TYPES;
final.obj = R.obj; final.gap = R.gaps; final.runtime = R.runtime;
save('hybrid_final.mat','-struct','final');

fprintf('Saved: hybrid_final.mat\n');
