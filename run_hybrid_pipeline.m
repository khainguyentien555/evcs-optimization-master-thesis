function run_hybrid_pipeline()
% RUN_HYBRID_PIPELINE — Chuỗi lai HBIPSO-GR ↔ Branch-and-Cut (CPLEX)

clc; rng(42);

%% 1) Chuẩn bị dữ liệu từ OPL (đã embed) -> evcs_data.mat
prep_evcs_from_cplex_embed;  % tạo evcs_data.mat

%% 2) Chạy HBIPSO-GR -> hbipso_best.mat
best = hbipso_gr_evcs(); %#ok<NASGU>

%% 3) Hậu xử lý phân bổ theo loại & xuất CSV
post_split_chargers_by_type();

%% 4) Vẽ & lưu hình (PNG; SVG tùy chọn)
viz_evcs_results(false);

%% 5) Xuất .dat cho OPL (2 chế độ)
make_opl_dat_from_hbipso('fixlb');  % Refine (đặt lower-bound theo HBIPSO)
make_opl_dat_from_hbipso('warm');   % Warm-start (x0,y0 từ HBIPSO)

fprintf('\n✓ DONE. Đã sinh:\n  - evcs_from_hbipso_fixlb.dat\n  - evcs_from_hbipso_warm.dat\n');
end
