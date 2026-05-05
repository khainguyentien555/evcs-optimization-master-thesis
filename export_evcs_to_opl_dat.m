function export_evcs_to_opl_dat()
% EXPORT_EVCS_TO_OPL_DAT  -> tạo 'evcs_hybrid.dat' cho OPL
% Yêu cầu: evcs_data.mat (bắt buộc), hbipso_best.mat (tùy chọn)
% Chính sách cứng: 
%   (1) Bus chỉ tại CC-BDX
%   (2) ForcedStations (nếu có) phải open & có >=1 trụ (để OPL xử lý)

clc;  % --- LOAD & NORMALIZE --- %
S = load('evcs_data.mat');

w1 = mgetf(S,'w1',0.33);
w2 = mgetf(S,'w2',0.33);
w3 = mgetf(S,'w3',0.34);
alpha = mgetf(S,'alpha',0.00036);
beta  = mgetf(S,'beta',0.00215);
lambda_pen = mgetf(S,'lambda_pen',50);

STATIONS = cellstr(mgetf(S,'STATIONS',mgetf(S,'stations',{})));
TYPES    = cellstr(mgetf(S,'TYPES',   mgetf(S,'types',   {})));
assert(~isempty(STATIONS) && ~isempty(TYPES), 'Thiếu STATIONS/TYPES trong evcs_data.mat');

EVcount = toDouble(mgetf(S,'EVcount',mgetf(S,'evcount',[])));
SCF     = toDouble(mgetf(S,'SCF',    mgetf(S,'scf',   [])));
DIST    = toDouble(mgetf(S,'DIST',   mgetf(S,'dist',  [])));
assert(~isempty(EVcount) && ~isempty(SCF) && ~isempty(DIST), 'Thiếu EVcount/SCF/DIST (dist).');

J = numel(STATIONS); T = numel(TYPES); I = size(EVcount,1);
assert(size(EVcount,2)==T, 'EVcount: số cột phải = |TYPES|.');
assert(all(size(DIST)==[I J]), 'DIST: kích thước phải = |POINTS| x |STATIONS|.');

maxCharger = toDouble(mgetf(S,'maxCharger',mgetf(S,'maxcharger',zeros(J,T))));
if any(size(maxCharger)~=[J T]), maxCharger = zeros(J,T); end

Astall = toDouble(mgetf(S,'Astall',mgetf(S,'astall',1)));
if isscalar(Astall), Astall = repmat(Astall,J,1); else, Astall = Astall(:); end
if numel(Astall)~=J, Astall = repmat(mean(Astall),J,1); end

Dmax = mgetf(S,'Dmax',max(DIST(:)));
allowed = double(DIST <= Dmax + 1e-9);

ForcedStations = mgetf(S,'ForcedStations',{});  % cellstr hoặc rỗng
forcedOpen = zeros(J,1);
if ~isempty(ForcedStations)
    forcedOpen(ismember(STATIONS,ForcedStations)) = 1;
end

% Bus chỉ tại CC-BDX
busAllowed = zeros(J,1);
idxBus = find(strcmp(TYPES,'bus'));
for j=1:J
    if strcmp(STATIONS{j},'CC-BDX'), busAllowed(j) = 1; end
end

% --- OPTIONAL WARM-START from HBIPSO ---
s0 = zeros(J,T);
if exist('hbipso_best.mat','file')
    B = load('hbipso_best.mat');
    if isfield(B,'x_by_type') && all(size(B.x_by_type)==[J T])
        s0 = toDouble(B.x_by_type);
    elseif isfield(B,'s')
        s_total = double(B.s(:)');
        if numel(s_total)==J
            D = EVcount .* SCF(:)';             % I x T
            wT = sum(D,1); wT = wT/max(sum(wT),eps);
            for j=1:J
                base = s_total(j)*wT; z = floor(base); r = base - z;
                s0(j,:) = z;
                need = s_total(j)-sum(z);
                if need>0
                    [~,ord]=sort(r,'descend'); s0(j,ord(1:need)) = s0(j,ord(1:need))+1;
                end
            end
        end
    end
end
% chặn bus ngoài CC-BDX & theo maxCharger
if ~isempty(idxBus)
    for j=1:J
        if ~busAllowed(j), s0(j,idxBus)=0; end
    end
end
s0 = max(0,min(s0,maxCharger));

% --- WRITE .DAT (robust OPL syntax) ---
fn = 'evcs_hybrid.dat';
fid = fopen(fn,'w'); assert(fid>0, 'Không ghi được evcs_hybrid.dat');

% Sets
fprintf(fid,'POINTS = {%s};\n', strjoin(compose('P%d',1:I),','));
fprintf(fid,'STATIONS = {%s};\n', joinQuoted(STATIONS));
fprintf(fid,'TYPES = {%s};\n\n', joinQuoted(TYPES));

% Matrices
fprintf(fid,'EVcount = [\n');   writemat(fid,EVcount); fprintf(fid,'];\n');
fprintf(fid,'SCF = [%s];\n', numrow(SCF));
fprintf(fid,'DIST = [\n');      writemat(fid,DIST);    fprintf(fid,'];\n');
fprintf(fid,'maxCharger = [\n');writemat(fid,maxCharger);fprintf(fid,'];\n');
fprintf(fid,'Astall = [%s];\n', numrow(Astall'));
fprintf(fid,'allowed = [\n');   writemat(fid,allowed); fprintf(fid,'];\n');
fprintf(fid,'busAllowed = [%s];\n', numrow(busAllowed'));
fprintf(fid,'forcedOpen = [%s];\n', numrow(forcedOpen'));

% Scalars
fprintf(fid,'w1=%g; w2=%g; w3=%g;\n', w1,w2,w3);
fprintf(fid,'alpha=%g; beta=%g; lambda_pen=%g;\n', alpha,beta,lambda_pen);

% Warm-start seed (optional param)
fprintf(fid,'s0 = [\n'); writemat(fid,s0); fprintf(fid,'];\n');

fclose(fid);
fprintf('OK -> tạo xong file: %s\n', fn);

% ===== local helpers =====
function v = mgetf(st, name, def)
    if isfield(st,name), v = st.(name); return; end
    lname = lower(name); if isfield(st,lname), v = st.(lname); return; end
    uname = upper(name); if isfield(st,uname), v = st.(uname); return; end
    v = def;
end
function a = toDouble(a), a = double(a); end
function s = joinQuoted(cells)
    q = cellfun(@(x)['"',x,'"'],cells,'uni',0);
    s = strjoin(q,',');
end
function writemat(fid,M)
    for r = 1:size(M,1)
        fprintf(fid,'  %s', numrow(M(r,:)));
        if r < size(M,1), fprintf(fid,'\n'); end
    end
end
function s = numrow(v)
    if isempty(v), s=''; return; end
    s = strtrim(sprintf('%.12g ', v));  % đủ chính xác
end
end
