% Export_Data_From_Matlab.m  (fix: alpha/beta/weights robust)
clear; clc;

%% ===== 1) LOAD DỮ LIỆU =====
D = load('evcs_data.mat');
H = load('hbipso_best.mat');

% --- SETS  ---
if     isfield(D,'POINTS'),   POINTS   = D.POINTS;
elseif isfield(D,'points'),   POINTS   = D.points;
else,  error('Thiếu POINTS trong evcs_data.mat'); end

if     isfield(D,'STATIONS'), STATIONS = D.STATIONS;
elseif isfield(D,'stations'), STATIONS = D.stations;
else,  error('Thiếu STATIONS trong evcs_data.mat'); end

if     isfield(D,'TYPES'),    TYPES    = D.TYPES;
elseif isfield(D,'types'),    TYPES    = D.types;
else,  error('Thiếu TYPES trong evcs_data.mat'); end

% --- THAM SỐ/MATRIX CHÍNH ---
if     isfield(D,'EVcount'),    EVcount    = D.EVcount;    else, error('Thiếu EVcount'); end
if     isfield(D,'maxCharger'), maxCharger = D.maxCharger; else, error('Thiếu maxCharger'); end

if     isfield(D,'DIST'),   DIST_m = D.DIST;
elseif isfield(D,'dist'),   DIST_m = D.dist;
elseif isfield(D,'Dist'),   DIST_m = D.Dist;
else,  error('Thiếu DIST/dist'); end

if     isfield(D,'SCF'),    SCF = D.SCF;
elseif isfield(D,'scf'),    SCF = D.scf; else, error('Thiếu SCF'); end

if     isfield(D,'areaT'),  areaT = D.areaT;
elseif isfield(D,'area'),   areaT = D.area;  else, error('Thiếu area/areaT'); end

if     isfield(D,'powerT'), powerT = D.powerT;
elseif isfield(D,'power'),  powerT = D.power; else, error('Thiếu power/powerT'); end

% --- alpha, beta, weights: LẤY LINH HOẠT + DEFAULT ---
alpha = getFieldOrDefault(D, {'alpha','ALPHA','a'}, 3.6e-4, 'alpha');
beta  = getFieldOrDefault(D, {'beta','BETA','b'},   2.15e-3, 'beta');

if isfield(D,'w') && numel(D.w)>=3
    wv = D.w(:)'; [w1,w2,w3] = deal(wv(1),wv(2),wv(3));
elseif isfield(D,'weights') && numel(D.weights)>=3
    wv = D.weights(:)'; [w1,w2,w3] = deal(wv(1),wv(2),wv(3));
elseif all(isfield(D,{'w1','w2','w3'}))
    w1 = D.w1; w2 = D.w2; w3 = D.w3;
else
    warning('Không tìm thấy bộ trọng số, dùng mặc định w1=w2=w3=1/3.');
    w1 = 1/3; w2 = 1/3; w3 = 1/3;
end

% --- KẾT QUẢ HBIPSO (nếu thiếu thì dùng mặc định hợp lý) ---
if isfield(H,'CSP'), CSP = H.CSP; else, CSP = []; end
if isfield(H,'s'),   sHB = H.s;   else, sHB = []; end

%% ===== 2) CHUẨN HÓA KIỂU DỮ LIỆU =====
if iscell(EVcount),    EVcount = cell2mat(EVcount); end
if iscell(maxCharger), maxCharger = cell2mat(maxCharger); end
if iscell(DIST_m),     DIST_m = cell2mat(DIST_m); end
if iscell(SCF),        SCF = cell2mat(SCF); end
if iscell(areaT),      areaT = cell2mat(areaT); end
if iscell(powerT),     powerT = cell2mat(powerT); end
if ~isempty(CSP) && iscell(CSP), CSP = cell2mat(CSP); end
if ~isempty(sHB) && iscell(sHB), sHB = cell2mat(sHB); end

if isstruct(SCF),    SCF = struct2array(SCF); end
if isstruct(areaT),  areaT = struct2array(areaT); end
if isstruct(powerT), powerT = struct2array(powerT); end

SCF   = SCF(:)'; 
areaT = areaT(:)'; 
powerT= powerT(:)'; 
if ~isempty(CSP), CSP = CSP(:)'; end
if ~isempty(sHB), sHB = sHB(:)'; end

if ~iscell(POINTS)   || ~all(cellfun(@ischar,POINTS)),   POINTS   = cellstr(POINTS);   end
if ~iscell(STATIONS) || ~all(cellfun(@ischar,STATIONS)), STATIONS = cellstr(STATIONS); end
if ~iscell(TYPES)    || ~all(cellfun(@ischar,TYPES)),    TYPES    = cellstr(TYPES);    end

%% ===== 3) SUY RA CHỈ SỐ/POLICY =====
J = numel(STATIONS); 
T = numel(TYPES);

idxBus = find(strcmpi(TYPES,'bus'), 1);
idxBDX = find(strcmpi(STATIONS,'CC-BDX'), 1);
if isempty(idxBus), error('Không tìm thấy TYPE "bus"'); end
if isempty(idxBDX), error('Không tìm thấy STATION "CC-BDX"'); end

% Đổi m -> km nếu có vẻ là mét
if mean(DIST_m(:),'omitnan') > 20
    DIST = DIST_m/1000;
else
    DIST = DIST_m;
end

% Bound tổng trụ từ HBIPSO (nếu không có sHB thì mặc định 2 trụ/trạm ±2)
if isempty(sHB), sHB = 2*ones(1,J); end
s_lb = max(1, round(sHB - 2));   % tất cả trạm phải có >=1 trụ
s_ub = max(s_lb, round(sHB + 2));

%% ===== 4) GHI FILE .dat =====
fn = 'evcs_hybrid.dat';
[fid,msg] = fopen(fn,'w');
if fid==-1, error('Không mở được %s: %s', fn, msg); end

% ---- sets ----
fprintf(fid, 'POINTS = {'); for i=1:numel(POINTS),   fprintf(fid,'"%s"%s',POINTS{i}, i<numel(POINTS),','); end; fprintf(fid,'};\n');
fprintf(fid, 'STATIONS = {');for i=1:numel(STATIONS), fprintf(fid,'"%s"%s',STATIONS{i},i<numel(STATIONS),',');end; fprintf(fid,'};\n');
fprintf(fid, 'TYPES = {');   for i=1:numel(TYPES),    fprintf(fid,'"%s"%s',TYPES{i},   i<numel(TYPES),',');   end; fprintf(fid,'};\n');

% ---- scalars ----
fprintf(fid,'alpha = %.12g;\n', alpha);
fprintf(fid,'beta  = %.12g;\n', beta);
fprintf(fid,'w1 = %.12g;\n', w1);
fprintf(fid,'w2 = %.12g;\n', w2);
fprintf(fid,'w3 = %.12g;\n', w3);
fprintf(fid,'idxBDX = %d;\n', idxBDX);
fprintf(fid,'idxBus = %d;\n', idxBus);

% ---- vectors ----
writeVec(fid,'SCF',   SCF);
writeVec(fid,'areaT', areaT);
writeVec(fid,'powerT',powerT);
writeVec(fid,'s_lb',  s_lb);
writeVec(fid,'s_ub',  s_ub);

% ---- matrices ----
writeMat(fid,'EVcount',    EVcount);
writeMat(fid,'maxCharger', maxCharger);
writeMat(fid,'DIST',       DIST);

fclose(fid);
fprintf('✔ Đã tạo %s\n', fn);

%% ===== 5) HÀM PHỤ =====
function val = getFieldOrDefault(S, names, defaultVal, label)
    for k=1:numel(names)
        if isfield(S, names{k})
            val = S.(names{k});
            return;
        end
    end
    warning('%s không có trong evcs_data.mat — dùng mặc định %.6g.', label, defaultVal);
    val = defaultVal;
end

function writeVec(fid, name, v)
    v = v(:)'; 
    fprintf(fid,'%s = [',name);
    for k=1:numel(v), fprintf(fid,'%.12g%s', v(k), k<numel(v),', '); end
    fprintf(fid,'];\n');
end

function writeMat(fid, name, M)
    fprintf(fid,'%s = [\n',name);
    for i=1:size(M,1)
        fprintf(fid,'  ');
        for j=1:size(M,2), fprintf(fid,'%.12g%s', M(i,j), j<size(M,2),', '); end
        fprintf(fid,'%s', i<size(M,1),';'); fprintf(fid,'\n');
    end
    fprintf(fid,'];\n');
end
