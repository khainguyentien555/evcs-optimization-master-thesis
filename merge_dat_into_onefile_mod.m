% merge_dat_into_onefile_mod.m
% Gộp toàn bộ dữ liệu từ evcs_hybrid.dat vào 1 file OPL .mod duy nhất.

clear; clc;

datFile = 'evcs_hybrid.dat';
modOut  = 'EVCS_Hybrid_ONEFILE.mod';

if ~isfile(datFile)
    error('Không tìm thấy %s trong thư mục hiện tại.', datFile);
end

% Đọc nguyên văn file .dat
txt = fileread(datFile);

% Helper: lấy RHS sau 'name =' đến dấu ';' (giữ nguyên format, kể cả xuống dòng)
getRHS = @(name) regexp(txt, [name '\s*=\s*(.*?);'], 'tokens', 'once', 'dotexceptnewline');

names = {'POINTS','STATIONS','TYPES','alpha','beta','w1','w2','w3','idxBDX','idxBus', ...
         'SCF','areaT','powerT','s_lb','s_ub','EVcount','maxCharger','DIST'};

rhs = struct();
for k = 1:numel(names)
    tk = getRHS(names{k});
    if isempty(tk)
        error('Không tìm thấy "%s" trong %s', names{k}, datFile);
    end
    rhs.(names{k}) = strtrim(tk{1});  % giữ nguyên block []/{}
end

% Bắt đầu ghi file .mod
[fid,msg] = fopen(modOut,'w');
if fid==-1, error('Không mở được %s: %s', modOut, msg); end

% Header + DATA (ghi nguyên văn RHS vào các khai báo OPL hợp lệ)
fprintf(fid, '/******************************************************\n');
fprintf(fid, ' * EVCS_Hybrid_ONEFILE.mod — sinh tự động từ %s\n', datFile);
fprintf(fid, ' * 1 file duy nhất (không cần .dat). Dữ liệu giữ nguyên định dạng.\n');
fprintf(fid, ' ******************************************************/\n\n');

fprintf(fid, '// ===== Data pasted from evcs_hybrid.dat (auto-generated) =====\n');

fprintf(fid, '{string} POINTS   = %s;\n', rhs.POINTS);
fprintf(fid, '{string} STATIONS = %s;\n', rhs.STATIONS);
fprintf(fid, '{string} TYPES    = %s;\n\n', rhs.TYPES);

fprintf(fid, 'range P = 1..card(POINTS);\n');
fprintf(fid, 'range S = 1..card(STATIONS);\n');
fprintf(fid, 'range T = 1..card(TYPES);\n\n');

fprintf(fid, 'float alpha = %s;\n',  rhs.alpha);
fprintf(fid, 'float beta  = %s;\n',  rhs.beta);
fprintf(fid, 'float w1    = %s;\n',  rhs.w1);
fprintf(fid, 'float w2    = %s;\n',  rhs.w2);
fprintf(fid, 'float w3    = %s;\n',  rhs.w3);
fprintf(fid, 'int   idxBDX = %s;\n', rhs.idxBDX);
fprintf(fid, 'int   idxBus = %s;\n\n', rhs.idxBus);

fprintf(fid, 'float SCF[t in T]    = %s;\n',    rhs.SCF);
fprintf(fid, 'float areaT[t in T]  = %s;\n',    rhs.areaT);
fprintf(fid, 'float powerT[t in T] = %s;\n\n',  rhs.powerT);

fprintf(fid, 'int s_lb[s in S] = %s;\n', rhs.s_lb);
fprintf(fid, 'int s_ub[s in S] = %s;\n\n', rhs.s_ub);

fprintf(fid, 'int   EVcount[p in P][t in T]    = %s;\n', rhs.EVcount);
fprintf(fid, 'int   maxCharger[s in S][t in T] = %s;\n', rhs.maxCharger);
fprintf(fid, 'float DIST[p in P][s in S]       = %s;\n\n', rhs.DIST);

fprintf(fid, 'float Dmax = 1e9; // km (đặt 3.0 nếu muốn giới hạn khoảng cách)\n\n');

% ==== Model phần còn lại (in từng dòng, dùng dấu " trong OPL thoải mái) ====
fprintf(fid, '// ===== Decision variables =====\n');
fprintf(fid, 'dvar boolean y[p in P][s in S];\n');
fprintf(fid, 'dvar int     x[s in S][t in T] >= 0;\n');
fprintf(fid, 'dvar int     sTot[s in S];\n');
fprintf(fid, 'dvar float+  L[s in S];\n');
fprintf(fid, 'dvar float+  u[s in S];\n');
fprintf(fid, 'dvar float+  v[s in S];\n');
fprintf(fid, 'dexpr float Lbar = (sum(s in S) L[s]) / card(S);\n\n');

fprintf(fid, '// ===== Constraints =====\n');
fprintf(fid, 'constraints {\n');
fprintf(fid, '  // tổng bộ sạc theo loại = tổng trụ\n');
fprintf(fid, '  forall(s in S)\n');
fprintf(fid, '    sum(t in T) x[s][t] == sTot[s];\n\n');

fprintf(fid, '  // mọi trạm mở theo bound\n');
fprintf(fid, '  forall(s in S)\n');
fprintf(fid, '    s_lb[s] <= sTot[s] <= s_ub[s];\n\n');

fprintf(fid, '  // tải phục vụ tại s (proxy: EVcount*SCF*power)\n');
fprintf(fid, '  forall(s in S)\n');
fprintf(fid, '    L[s] == sum(p in P, t in T) ( EVcount[p][t] * SCF[t] * powerT[t] * y[p][s] );\n\n');

fprintf(fid, '  // công suất lắp đặt đủ đáp ứng tải\n');
fprintf(fid, '  forall(s in S)\n');
fprintf(fid, '    L[s] <= sum(t in T) ( x[s][t] * powerT[t] );\n\n');

fprintf(fid, '  // mỗi điểm gán tối đa 1 trạm\n');
fprintf(fid, '  forall(p in P)\n');
fprintf(fid, '    sum(s in S) y[p][s] <= 1;\n\n');

fprintf(fid, '  // giới hạn số trụ theo loại\n');
fprintf(fid, '  forall(s in S, t in T)\n');
fprintf(fid, '    0 <= x[s][t] <= maxCharger[s][t];\n\n');

fprintf(fid, '  // BUS chỉ ở CC-BDX\n');
fprintf(fid, '  forall(s in S : s != idxBDX)\n');
fprintf(fid, '    x[s][idxBus] == 0;\n\n');

fprintf(fid, '  // |L[s] - Lbar|\n');
fprintf(fid, '  forall(s in S) {\n');
fprintf(fid, '    u[s] >=  L[s] - Lbar;\n');
fprintf(fid, '    v[s] >=  Lbar - L[s];\n');
fprintf(fid, '  }\n\n');

fprintf(fid, '  // cấm gán nếu vượt Dmax (để DIST thực sự được dùng)\n');
fprintf(fid, '  forall(p in P, s in S : DIST[p][s] > Dmax)\n');
fprintf(fid, '    y[p][s] == 0;\n');
fprintf(fid, '}\n\n');

fprintf(fid, '// ===== Objectives =====\n');
fprintf(fid, 'dexpr float F1 = - sum(s in S) L[s];\n');
fprintf(fid, 'dexpr float F2 =   alpha * sum(s in S) (u[s] + v[s]);\n');
fprintf(fid, 'dexpr float F3 =   beta  * sum(s in S, t in T) (x[s][t] * areaT[t]);\n');
fprintf(fid, 'minimize z = w1*F1 + w2*F2 + w3*F3;\n\n');

fprintf(fid, '// ===== Report =====\n');
fprintf(fid, 'execute {\n');
fprintf(fid, '  writeln("F1 = ", F1);\n');
fprintf(fid, '  writeln("F2 = ", F2);\n');
fprintf(fid, '  writeln("F3 = ", F3);\n');
fprintf(fid, '  writeln("z  = ", z);\n');
fprintf(fid, '  writeln("---- Station summary ----");\n');
fprintf(fid, '  for (var s in S) {\n');
fprintf(fid, '    var ns = Opl.item(STATIONS, s);\n');
fprintf(fid, '    write(ns, " | sTot=", sTot[s], " | L=", L[s], " | x=[");\n');
fprintf(fid, '    for (var t in T) { write(x[s][t]); if (t<card(T)) write(", "); }\n');
fprintf(fid, '    writeln("]");\n');
fprintf(fid, '  }\n');
fprintf(fid, '}\n');

fclose(fid);
fprintf('✔ Đã tạo file 1-mình: %s\n', modOut);
