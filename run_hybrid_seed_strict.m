% === RUN HBIPSO-GR & EXPORT SEED (VỚI RÀNG BUỘC BDX & MUST-OPEN) ===
clear; clc;

% 1) Load dữ liệu bạn đã chuẩn hoá (đang dùng file này rồi)
S = load('evcs_data.mat');  % có: D, dist, Astall, Cmax, Q, Dmax, w1,w2,w3, alpha,beta, EVcount, SCF, areaT, powerT, DIST, maxCharger, stations, points, types

% 2) Khai báo ràng buộc bài toán lai
bdxName  = 'CC-BDX';                                    % trạm bus duy nhất
mustOpen = {'CC-TT1','CC-TM2','CC-TLC','CC-BDX'};       % CÁC TRẠM ĐỀ XUẤT PHẢI MỞ (điều chỉnh theo bạn)

% 3) Chạy HBIPSO-GR (hàm hiện không có output -> chỉ gọi, rồi load file .mat)
hbipso_gr_evcs();                                       % hàm tự lưu 'hbipso_best.mat'
Sbest = load('hbipso_best.mat');                        % phải có biến 'best' trong file này
best  = Sbest.best;                                     % struct: best.CSP, best.s, best.x, ...

% 4) Xuất seed + .dat cho CPLEX với các ràng buộc bắt buộc
Delta = 15;                                             % biên tinh chỉnh số trụ trong Polish (A)
export_seed_to_opl_strict(best, S, Delta, 'seed_hbipso', mustOpen, bdxName);

fprintf('\n[OK] Đã xuất: seed_hbipso_A.dat (Polish) & seed_hbipso_B.dat (Prune) với ràng buộc:\n');
fprintf('  - Chỉ CC-BDX cho phép trụ 150kW (bus); các trạm khác bus=0\n');
fprintf('  - Các trạm MUST-OPEN: %s (bắt buộc có ≥ 1 trụ)\n', strjoin(mustOpen, ', '));
fprintf('\nGợi ý chạy CPLEX:\n  oplrun EVmodel_full.mod seed_hbipso_A.dat\n  oplrun EVmodel_full.mod seed_hbipso_B.dat\n');
