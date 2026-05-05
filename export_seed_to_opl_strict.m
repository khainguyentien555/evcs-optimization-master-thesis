function export_seed_to_opl_strict(best, S, Delta, base, mustOpen, bdxName)
% Xuất 2 .dat (A: Polish; B: Prune) KÈM RÀNG BUỘC:
%  (i) Bus 150kW chỉ cho CC-BDX (mọi trạm khác bus=0)
% (ii) Các trạm mustOpen BẮT BUỘC mở & có ≥1 trụ (sLower>=1)

m = numel(S.stations);
n = numel(S.points);
tNames = string(S.types);           % ví dụ: ["xe_may","oto5","oto7","taxi5","taxi7","bus"]
jNames = string(S.stations);

% --- seed từ HBIPSO
CSP   = best.CSP(:);
sHB   = best.s(:);
xHB   = round(best.x);              % n×m (0/1)
% --- Mode A: bound theo Δ, nhưng vẫn đảm bảo mustOpen >= 1
sLowA = max(0, sHB - Delta);
sUppA = min(sHB + Delta, S.Cmax(:));

% --- mustOpen: ép tối thiểu 1 trụ
isMust = ismember(jNames, string(mustOpen));
sLowA(isMust) = max(sLowA(isMust), 1);  % Polish
% --- Mode B: không bound theo Δ, nhưng vẫn ép mustOpen >=1
sLowB = zeros(m,1);
sUppB = S.Cmax(:);
sLowB(isMust) = 1;

% --- Chỉ cho bus ở CC-BDX: sửa bản sao maxCharger để bus=0 tại các trạm khác
maxChFix = S.maxCharger;
idBus = find(strcmpi(tNames,'bus'));         % cột 'bus' trong TYPES
assert(~isempty(idBus), 'Không tìm thấy type "bus" trong TYPES!');
for j = 1:m
    if jNames(j) ~= string(bdxName)
        maxChFix(j, idBus) = 0;              % cấm bus ở mọi trạm ≠ CC-BDX
    end
end

% ==== Common header (khớp với EVmodel_full.mod của bạn) ====
fmtHeader = @(title) sprintf(['// %s\n',...
  'w1=%g; w2=%g; w3=%g;\nalpha=%g; beta=%g;\n',...
  'POINTS=%s;\nSTATIONS=%s;\nTYPES=%s;\n',...
  'EVcount=%s;\nSCF=%s;\narea=%s;\npower=%s;\n',...
  'DIST=%s;\nmaxCharger=%s;\n'], ...
  title, S.w1, S.w2, S.w3, S.alpha, S.beta, ...
  jset(S.points), jset(S.stations), jset(S.types), ...
  jmat_int(S.EVcount), jvec_real(S.SCF), jvec_real(S.areaT), jvec_real(S.powerT), ...
  jmat_int(S.DIST), jmat_int(maxChFix));     % dùng maxChFix đã khoá bus

% ---------------- MODE A: POLISH (fix mustOpen mở & có trụ; bound s= sHB±Δ) ---------------
fid = fopen([base '_A.dat'],'w');  assert(fid>0);
fprintf(fid, '%s', fmtHeader('SEED HBIPSO — MODE A (Polish, mustOpen>=1, bus@CC-BDX)'));
% Cho phép đóng các trạm không mustOpen (enforceOpen=0) nhưng ép sLower>=1 cho mustOpen
fprintf(fid, 'enforceOpen=0;\n');                  % không ép đóng/mở bằng nhị phân fixOpen
fprintf(fid, 'fixOpen=%s;\n', jvec_int(CSP));      % tham khảo nếu bạn muốn dùng
fprintf(fid, 'useSumBound=1;\n');                  % dùng bound dưới/trên cho tổng trụ
fprintf(fid, 'sLower=%s;\n', jvec_int(sLowA));     % đảm bảo mustOpen>=1
fprintf(fid, 'sUpper=%s;\n', jvec_int(sUppA));

% MIPStart (tuỳ chọn) – khởi tạo tổng trụ & gán
fprintf(fid, 'hasMIPStart=1;\n');
fprintf(fid, 'xStart_total=%s;\n', jvec_int(sHB));
fprintf(fid, 'yStart=%s;\n', jmat_int(xHB));
fclose(fid);

% ---------------- MODE B: PRUNE (free CSP; mustOpen>=1; có MIPStart) ----------------------
fid = fopen([base '_B.dat'],'w');  assert(fid>0);
fprintf(fid, '%s', fmtHeader('SEED HBIPSO — MODE B (Prune, mustOpen>=1, bus@CC-BDX)'));
fprintf(fid, 'enforceOpen=0;\n');                  % cho solver tự quyết mở/đóng, nhưng…
fprintf(fid, 'fixOpen=%s;\n', jvec_int(CSP));      % …vẫn truyền tham khảo
fprintf(fid, 'useSumBound=1;\n');                  % dùng bound dưới/trên để ép mustOpen>=1
fprintf(fid, 'sLower=%s;\n', jvec_int(sLowB));     % mustOpen >= 1; trạm khác >=0
fprintf(fid, 'sUpper=%s;\n', jvec_int(sUppB));

fprintf(fid, 'hasMIPStart=1;\n');
fprintf(fid, 'xStart_total=%s;\n', jvec_int(sHB));
fprintf(fid, 'yStart=%s;\n', jmat_int(xHB));
fclose(fid);
end

% ==== helpers (in-line OPL sets/arrays) ====
function s = jset(c), s = ['{' strjoin("""" + string(c) + """", ',') '}']; end
function s = jvec_int(v), v = v(:)'; s = ['[' sprintf('%d,', v(1:end-1)) sprintf('%d', v(end)) ']']; end
function s = jvec_real(v), v = v(:)'; s = ['[' sprintf('%.10g,', v(1:end-1)) sprintf('%.10g', v(end)) ']']; end
function s = jmat_int(M)
[r,c] = size(M); row = strings(r,1);
for i=1:r
  row(i) = "[" + sprintf('%d,', M(i,1:c-1)) + sprintf('%d', M(i,c)) + "]";
end
s = "[" + strjoin(row.', ',') + "]";
end
