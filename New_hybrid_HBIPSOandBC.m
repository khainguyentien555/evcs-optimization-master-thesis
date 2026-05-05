% EXPORT_AND_MAKE_DAT
% Tạo file dữ liệu OPL (.dat) tối giản từ evcs_data.mat (+ kết quả HBIPSO nếu có)
% Chạy file này trước, nó sẽ sinh 'evcs_hybrid.dat' trong cùng thư mục.
clear; clc;

%% Nạp dữ liệu dự án
S = load('evcs_data.mat');   % yêu cầu các biến: EVcount (I×T), SCF (1×T), DIST (I×J)
                             % STATIONS {1×J}, TYPES {1×T}, maxCharger (J×T),
                             % Astall (J×1 hoặc 1×J), Dmax (scalar, tùy chọn)
% Các trọng số/ hệ số (nếu thiếu thì dùng mặc định)
if ~isfield(S,'w1'), S.w1 = 0.33; end
if ~isfield(S,'w2'), S.w2 = 0.33; end
if ~isfield(S,'w3'), S.w3 = 0.34; end
if ~isfield(S,'alpha'), S.alpha = 0.00036; end
if ~isfield(S,'beta'),  S.beta  = 0.00215;  end
if ~isfield(S,'lambda_pen'), S.lambda_pen = 50; end
if ~isfield(S,'Dmax'), S.Dmax = max(S.DIST(:)); end

STATIONS = S.STATIONS(:)';   J = numel(STATIONS);
TYPES    = S.TYPES(:)';      T = numel(TYPES);
EVcount  = double(S.EVcount);
SCF      = double(S.SCF(:)');
DIST     = double(S.DIST);
maxCharger = double(S.maxCharger);
Astall   = double(S.Astall(:)); if numel(Astall)==1, Astall = repmat(Astall,J,1); end

% Bus chỉ tại CC-BDX
busAllowed = zeros(J,1);
idxBus = find(strcmp(TYPES,'bus'));
for j=1:J
    if strcmp(STATIONS{j},'CC-BDX'), busAllowed(j)=1; end
end

% Forced open (nếu có trong S; nếu không thì để rỗng)
forcedOpen = zeros(J,1);
if isfield(S,'ForcedStations') && ~isempty(S.ForcedStations)
    forcedOpen(ismember(STATIONS, S.ForcedStations)) = 1;
end

% Ma trận "allowed" theo khoảng cách (1 nếu <=Dmax)
allowed = double(DIST <= S.Dmax + 1e-9);

% (Tuỳ chọn) Warm-start từ HBIPSO nếu có
s0 = zeros(J,T);  % số trụ khởi tạo theo từng loại
if exist('hbipso_best.mat','file')
    B = load('hbipso_best.mat');            % có thể có B.x_by_type (J×T)
    if isfield(B,'x_by_type')
        s0 = double(B.x_by_type);
    elseif isfield(B,'s')                    % chỉ tổng trụ → chia theo tỷ lệ nhu cầu
        EV = double(S.EVcount);  D = EV .* SCF;
        wT = sum(D,1);  wT = wT / max(sum(wT),eps);
        for j=1:J
            base = B.s(j) * wT;
            z = floor(base); r = base - z; need = B.s(j) - sum(z);
            s0(j,:) = z;
            if need>0
                [~,ord]=sort(r,'descend'); s0(j,ord(1:need)) = s0(j,ord(1:need))+1;
            end
        end
    end
end
% Cắt theo maxCharger, chặn bus ngoài CC-BDX
if ~isempty(idxBus)
    for j=1:J
        if ~busAllowed(j), s0(j,idxBus)=0; end
    end
end
s0 = max(0, min(s0, maxCharger));

%% Ghi file .dat (OPL)
dat = fopen('evcs_hybrid.dat','w');

% Sets
fprintf(dat,'POINTS = {%s};\n', strjoin(compose('P%d',1:size(EVcount,1)),','));
fprintf(dat,'STATIONS = {%s};\n', strjoin(STATIONS,','));
fprintf(dat,'TYPES = {%s};\n\n', strjoin(TYPES,','));

% Parameters
% EVcount
fprintf(dat,'EVcount = [\n');
for i=1:size(EVcount,1)
    fprintf(dat,'  %s', sprintf('%g ', EVcount(i,:)));
    if i<size(EVcount,1), fprintf(dat,'\n'); end
end
fprintf(dat,'];\n');
% SCF
fprintf(dat,'SCF = %s;\n', ['[', sprintf('%g ', SCF), ']']);
% DIST
fprintf(dat,'DIST = [\n');
for i=1:size(DIST,1)
    fprintf(dat,'  %s', sprintf('%g ', DIST(i,:)));
    if i<size(DIST,1), fprintf(dat,'\n'); end
end
fprintf(dat,'];\n');
% maxCharger
fprintf(dat,'maxCharger = [\n');
for j=1:J
    fprintf(dat,'  %s', sprintf('%g ', maxCharger(j,:)));
    if j<J, fprintf(dat,'\n'); end
end
fprintf(dat,'];\n');
% Astall
fprintf(dat,'Astall = %s;\n', ['[', sprintf('%g ', Astall), ']']);
% allowed (distance mask)
fprintf(dat,'allowed = [\n');
for i=1:size(allowed,1)
    fprintf(dat,'  %s', sprintf('%d ', allowed(i,:)));
    if i<size(allowed,1), fprintf(dat,'\n'); end
end
fprintf(dat,'];\n');
% busAllowed & forcedOpen
fprintf(dat,'busAllowed = %s;\n', ['[', sprintf('%d ', busAllowed), ']']);
fprintf(dat,'forcedOpen = %s;\n', ['[', sprintf('%d ', forcedOpen), ']']);

% scalars
fprintf(dat,'w1 = %g; w2 = %g; w3 = %g;\n', S.w1, S.w2, S.w3);
fprintf(dat,'alpha = %g; beta = %g; lambda_pen = %g;\n', S.alpha, S.beta, S.lambda_pen);

% Warm start (không bắt buộc – OPL đọc làm tham số)
fprintf(dat,'s0 = [\n');
for j=1:J
    fprintf(dat,'  %s', sprintf('%g ', s0(j,:)));
    if j<J, fprintf(dat,'\n'); end
end
fprintf(dat,'];\n');

fclose(dat);
fprintf('Đã tạo file: evcs_hybrid.dat\n');
