function post_split_chargers_by_type()
% Hậu xử lý nghiệm HBIPSO-GR:
% - phân bổ số TRỤ theo loại (11/60/150 kW) từ kết quả tổng s(j)
% - quy ra số CHARGER theo số cổng/charger
% - chính sách: mở CC-BDX cho bus; tăng phân bổ cho CC-TT1, CC-TM2, CC-TLC
%
% Input:  evcs_data.mat (chứa EVcount, SCF, maxCharger, STATIONS, TYPES)
%         hbipso_best.mat (CSP, s, x)
% Output: chargers_by_type_per_station.csv + bảng in ra màn hình

clc;

%% ====== Tham số chính sách (bạn chỉnh ở đây) ======
% Cổng/charger
ports11  = 4;   % 11 kW: 4 cổng
ports60  = 2;   % 60 kW: 2 cổng
ports150 = 2;   % 150 kW: 2 cổng

% Yêu cầu mở bus tại CC-BDX
bdx_min_bus_chargers = 2;   % tối thiểu 2 charger 150kW tại CC-BDX
rebalance_to = {'CC-TT1','CC-TM2','CC-TLC'}; % tránh dồn: đảm bảo tối thiểu
min_total_stalls_each = 50; % mỗi trạm trên tối thiểu bấy nhiêu TRỤ (stalls)

%% ====== Nạp dữ liệu ======
S = load('evcs_data.mat');      % D, EVcount, SCF, maxCharger, STATIONS, TYPES, ...
R = load('hbipso_best.mat');    % CSP, s, x

types = string(S.TYPES(:));
stations = string(S.STATIONS(:));
nT = numel(types); m = numel(stations);

% Nhóm loại
grp11  = types=="xe_may";
grp60  = ismember(types,["oto5","oto7","taxi5","taxi7"]);
grp150 = types=="bus";

% Nhu cầu theo điểm x loại
D_it = S.EVcount .* S.SCF;    % [n x T]

% Tải tại trạm theo loại (dựa trên gán x của HBIPSO)
L_jt  = R.x' * D_it;          % [m x T]
L11   = sum(L_jt(:,grp11),2);
L60   = sum(L_jt(:,grp60),2);
L150  = sum(L_jt(:,grp150),2);
Lsum  = L11 + L60 + L150;
Lsum(Lsum==0) = 1;            % tránh chia 0

s_tot = R.s(:);               % tổng TRỤ (stalls) mỗi trạm
CSP   = R.CSP(:)>0;

% Giới hạn theo loại (từ maxCharger trong .mod)
max11  = S.maxCharger(:,grp11);            % [m x 1]
max60  = sum(S.maxCharger(:,grp60),2);     % [m x 1] 4 loại gộp
max150 = S.maxCharger(:,grp150);           % [m x 1]

%% ====== 1) Phân bổ TRỤ theo tỷ trọng tải ======
s11_raw  = s_tot .* (L11 ./ Lsum);
s60_raw  = s_tot .* (L60 ./ Lsum);
s150_raw = s_tot .* (L150 ./ Lsum);

% Làm tròn + giữ tổng bằng s_tot (largest remainder)
s11 = floor(s11_raw);  s60 = floor(s60_raw);  s150 = floor(s150_raw);
rem = s_tot - (s11+s60+s150);
if any(rem>0)
    frac = [s11_raw - s11, s60_raw - s60, s150_raw - s150];  % [m x 3]
    for j=1:m
        while rem(j)>0
            [~,ord] = sort(frac(j,:),'descend');
            for k=1:3
                idx = ord(k);
                if idx==1, s11(j)=s11(j)+1;
                elseif idx==2, s60(j)=s60(j)+1;
                else, s150(j)=s150(j)+1;
                end
                rem(j)=rem(j)-1;
                if rem(j)==0, break; end
            end
        end
    end
end

%% ====== 2) Chính sách: Bus chỉ ở CC-BDX + ép tối thiểu charger bus ======
jBDX = find(stations=="CC-BDX",1);
if isempty(jBDX), error('Không tìm thấy trạm "CC-BDX" trong STATIONS.'); end

% Bus chỉ ở BDX: cắt 150kW ở trạm khác
cut150 = sum(s150) - s150(jBDX);
s150(:) = 0; 
s150(jBDX) = min(max150(jBDX), cut150);

% Ép tối thiểu charger bus tại BDX
s150_min = ports150 * bdx_min_bus_chargers;        % đổi charger -> TRỤ
s150(jBDX) = max(s150(jBDX), s150_min);
s150(jBDX) = min(s150(jBDX), max150(jBDX));        % không vượt max

% Giữ tổng stalls mỗi trạm = s_tot
for j=1:m
    surplus = s11(j)+s60(j)+s150(j) - s_tot(j);
    if surplus>0
        % giảm từ nhóm lớn nhất trước (ưu tiên 60kW -> 11kW)
        while surplus>0
            [mx, idx] = max([s60(j) s11(j) s150(j)]);
            if mx<=0, break; end
            if idx==1, s60(j)=s60(j)-1;
            elseif idx==2, s11(j)=s11(j)-1;
            else, s150(j)=max(0,s150(j)-1);
            end
            surplus=surplus-1;
        end
    elseif surplus<0
        % thiếu -> bù vào nhóm còn room theo max (ưu tiên 60 -> 11)
        while surplus<0
            room = [max60(j)-s60(j), max11(j)-s11(j), max150(j)-s150(j)];
            [mx, idx] = max(room);
            if mx<=0, break; end
            if idx==1, s60(j)=s60(j)+1;
            elseif idx==2, s11(j)=s11(j)+1;
            else, s150(j)=s150(j)+1;
            end
            surplus=surplus+1;
        end
    end
end

%% ====== 3) Tránh dồn: đảm bảo CC-TT1, CC-TM2, CC-TLC có tối thiểu stalls ======
rebIdx = arrayfun(@(nm) find(stations==nm,1), string(rebalance_to));
rebIdx = rebIdx(~isnan(rebIdx));
for j = rebIdx(:).'
    need = max(0, min_total_stalls_each - (s11(j)+s60(j)+s150(j)));
    if need>0
        % rút bớt từ trạm đang có nhiều nhất (không rút BDX bus)
        donors = setdiff(1:m, [j jBDX]);
        [~,donorOrd] = sort(s11(donors)+s60(donors)+s150(donors), 'descend');
        for d = donors(donorOrd).'
            while need>0
                % rút theo nhóm còn nhiều + còn room max tại j
                roomJ = [max11(j)-s11(j), max60(j)-s60(j), max150(j)-s150(j)];
                takeD = [s11(d)>0, s60(d)>0, s150(d)>0];
                if ~any(takeD), break; end
                % ưu tiên chuyển 60kW -> 11kW -> 150kW
                orderGrp = [2 1 3]; % [60,11,150]
                moved = false;
                for g = orderGrp
                    if takeD(g) && roomJ(g)>0
                        if g==1, s11(d)=s11(d)-1; s11(j)=s11(j)+1;
                        elseif g==2, s60(d)=s60(d)-1; s60(j)=s60(j)+1;
                        else,       s150(d)=s150(d)-1; s150(j)=s150(j)+1;
                        end
                        need = need-1; moved = true; break;
                    end
                end
                if ~moved, break; end
            end
            if need==0, break; end
        end
    end
end

%% ====== 4) Cắt theo maxCharger & cân bằng lại tổng stalls ======
s11 = min(s11, max11);
s60 = min(s60, max60);
s150= min(s150,max150);

% nếu bị cắt -> dồn phần thừa sang nhóm còn room (ưu tiên 60 -> 11 -> 150)
for j=1:m
    deficit = s_tot(j) - (s11(j)+s60(j)+s150(j));
    while deficit>0
        room = [max60(j)-s60(j), max11(j)-s11(j), max150(j)-s150(j)];
        [mx, idx] = max(room);
        if mx<=0, break; end
        if idx==1, s60(j)=s60(j)+1;
        elseif idx==2, s11(j)=s11(j)+1;
        else,        s150(j)=s150(j)+1;
        end
        deficit=deficit-1;
    end
end

%% ====== 5) Quy đổi TRỤ -> CHARGER theo số cổng ======
c11  = ceil(s11  / ports11);
c60  = ceil(s60  / ports60);
c150 = ceil(s150 / ports150);

%% ====== 6) Xuất bảng ======
T = table( ...
    stations, CSP, s_tot, s11, s60, s150, c11, c60, c150, ...
    'VariableNames', {'Station','Open','Stalls_total','Stalls_11kW','Stalls_60kW','Stalls_150kW', ...
                      'Chargers_11kW','Chargers_60kW','Chargers_150kW'});

disp(T);
writetable(T, 'chargers_by_type_per_station.csv');
fprintf('\nSaved: chargers_by_type_per_station.csv\n');

% Thống kê nhanh
fprintf('\nTổng TRỤ: %d | 11kW=%d, 60kW=%d, 150kW=%d\n', sum(s_tot), sum(s11), sum(s60), sum(s150));
fprintf('Tổng CHARGER: 11kW=%d, 60kW=%d, 150kW=%d\n', sum(c11), sum(c60), sum(c150));
end
