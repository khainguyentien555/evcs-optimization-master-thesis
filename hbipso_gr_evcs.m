function best = hbipso_gr_evcs()
% HBIPSO-GR for EVCS siting & sizing — CORRECTED OBJECTIVE VERSION
%
% Changes from original:
%   [1] F2: changed from std(load) to pairwise sum |L_j - L_k| (j<k)
%           — matches Eq.(7) and Eq.(13) in the paper (Σu_jk formulation)
%   [2] F1, F2, F3: all normalized to [0,1] before weighted sum
%           — matches Eq.(14) normalized weighted-sum reformulation
%   [3] Sign convention: min Z = -w1*F̂1 + w2*F̂2 + w3*F̂3
%           — identical to CPLEX MOMIP formulation
%   [4] Final report prints F̂1, F̂2, F̂3, Z_pure directly comparable to B&C
%
% Required: evcs_data.mat (run corrected prep_evcs_from_cplex_embed.m first)

%% ===== Load & setup =====
clear; clc; rng(42);
S = load('evcs_data.mat');
D = S.D; dist = S.dist; Astall = S.Astall; Cmax = S.Cmax;
Q = S.Q; Dmax = S.Dmax;
w1 = S.w1; w2 = S.w2; w3 = S.w3;
rhoU = S.rhoU; rhoVcap = S.rhoVcap; rhoVdist = S.rhoVdist; rhoVlogic = S.rhoVlogic;
lambda_pen = S.lambda_pen;

% Normalization references — loaded from prep file
F1_ref = S.F1_ref;   % total demand
F2_ref = S.F2_ref;   % max pairwise deviation
F3_ref = S.F3_ref;   % max land use

[n, m] = size(dist);

fprintf('Problem: n=%d demand points, m=%d stations\n', n, m);
fprintf('Weights: w1=%.4f, w2=%.4f, w3=%.4f\n', w1, w2, w3);
fprintf('F_ref:   F1=%.2f, F2=%.2f, F3=%.2f\n\n', F1_ref, F2_ref, F3_ref);

%% ===== Force-open policy =====
forcedNames = {'CC-TM1','CC-HH1','CC-HH2'};
smin_forced = [20, 15, 15];
force_policy = true;

forcedIdx = zeros(0,1);
if force_policy
    forcedIdx = cellfun(@(nm) find(strcmp(S.STATIONS, nm), 1, 'first'), forcedNames);
    forcedIdx = forcedIdx(~cellfun(@isempty, num2cell(forcedIdx)));
end
lb_s = zeros(m, 1);
if force_policy
    lb_s(forcedIdx) = smin_forced(:);
end
ub_s = Cmax;

%% ===== HBIPSO hyper-parameters (unchanged) =====
nPop    = 40;
maxIter = 300;
c1 = 1.8; c2 = 1.8;
w_in = 0.72;
sig_threshold = 0.5;
beta_smooth   = 0.0;

%% ===== Initialize swarm =====
pop = repmat(struct('z',[],'y',[],'vz',[],'vy',[],'fit',Inf,'aux',[],'pbest',[]), nPop, 1);

for p = 1:nPop
    pop(p).z  = atanh(2*rand(m,1) - 1);
    y0        = lb_s + rand(m,1) .* (ub_s - lb_s);
    pop(p).y  = round(y0);
    pop(p).vz = zeros(m,1);
    pop(p).vy = zeros(m,1);

    [f, aux] = evaluate_solution(pop(p).z, pop(p).y, ...
        D, dist, Astall, lb_s, ub_s, Q, Dmax, w1, w2, w3, ...
        rhoU, rhoVcap, rhoVdist, rhoVlogic, lambda_pen, ...
        sig_threshold, beta_smooth, force_policy, forcedIdx, ...
        F1_ref, F2_ref, F3_ref);

    pop(p).fit = f; pop(p).aux = aux;
    pop(p).pbest = struct('z', pop(p).z, 'y', pop(p).y, 'fit', f);
end

[~, gix] = min([pop.fit]);
gbest = struct('z', pop(gix).z, 'y', pop(gix).y, 'fit', pop(gix).fit, 'aux', pop(gix).aux);

fprintf('Iter    Z_pure     F1_hat    F2_hat    F3_hat   Penalty   Open  Stalls\n');
fprintf('----  ---------  --------  --------  --------  --------   ----  ------\n');

%% ===== Main PSO loop =====
for it = 1:maxIter
    for p = 1:nPop
        r1 = rand(m,1); r2 = rand(m,1);

        pop(p).vz = w_in*pop(p).vz + c1*r1.*(pop(p).pbest.z - pop(p).z) + c2*r2.*(gbest.z - pop(p).z);
        pop(p).vy = w_in*pop(p).vy + c1*r1.*(pop(p).pbest.y - pop(p).y) + c2*r2.*(gbest.y - pop(p).y);

        pop(p).z = pop(p).z + pop(p).vz;
        y_new    = pop(p).y + pop(p).vy;
        y_new    = max(y_new, lb_s);
        y_new    = min(y_new, ub_s);

        [f, aux] = evaluate_solution(pop(p).z, y_new, ...
            D, dist, Astall, lb_s, ub_s, Q, Dmax, w1, w2, w3, ...
            rhoU, rhoVcap, rhoVdist, rhoVlogic, lambda_pen, ...
            sig_threshold, beta_smooth, force_policy, forcedIdx, ...
            F1_ref, F2_ref, F3_ref);

        pop(p).y   = y_new;
        pop(p).fit = f;
        pop(p).aux = aux;

        if f < pop(p).pbest.fit
            pop(p).pbest = struct('z', pop(p).z, 'y', pop(p).y, 'fit', f);
        end
        if f < gbest.fit
            gbest = struct('z', pop(p).z, 'y', pop(p).y, 'fit', f, 'aux', aux);
        end
    end

    if it == 1 || mod(it, 25) == 0
        a = gbest.aux;
        fprintf('%4d  %9.6f  %8.6f  %8.6f  %8.6f  %8.3f   %4d  %6d\n', ...
            it, a.Z_pure, a.F1_hat, a.F2_hat, a.F3_hat, a.penalty, ...
            sum(a.CSP), sum(a.s));
    end
end

%% ===== Final report =====
a = gbest.aux;
CSP = a.CSP; s_vec = a.s; x = a.x;

fprintf('\n======= BIPSO-GR BEST SOLUTION =======\n');
fprintf('Coverage ratio  F1_hat = %.6f  (served=%.4f / total=%.4f)\n', a.F1_hat, a.served, F1_ref);
fprintf('Load balance    F2_hat = %.6f  (raw F2=%.4f)\n',               a.F2_hat, a.F2_raw);
fprintf('Land use        F3_hat = %.6f  (raw F3=%.4f m2)\n',            a.F3_hat, a.F3_raw);
fprintf('Weighted Z_pure        = %.6f\n',                              a.Z_pure);
fprintf('Penalty                = %.4f\n',                              a.penalty);
fprintf('Total fitness FT       = %.6f\n',                              gbest.fit);
fprintf('Open stations: %d / %d  |  Total stalls: %d\n', sum(CSP), m, sum(s_vec));
fprintf('Runtime: 300 iterations (seed=42)\n');

% Station-level load for B&C comparison
openIdx = find(CSP > 0);
fprintf('\nStation loads (open stations only):\n');
for j = openIdx(:).'
    fprintf('  %s: L=%.4f, stalls=%d\n', S.STATIONS{j}, a.load(j), s_vec(j));
end

% -----------------------------------------------------------
% COMPARISON TABLE (fill manually with B&C values from CPLEX)
% -----------------------------------------------------------
fprintf('\n======= COMPARABLE METRICS FOR TABLE =======\n');
fprintf('%-30s  %-12s  %-12s\n', 'Metric', 'B&C', 'BIPSO-GR');
fprintf('%-30s  %-12s  %-12.6f\n', 'F1_hat (coverage)',   '1.000000',  a.F1_hat);
fprintf('%-30s  %-12s  %-12.6f\n', 'F2_hat (load balance)','[B&C val]', a.F2_hat);
fprintf('%-30s  %-12s  %-12.6f\n', 'F3_hat (land use)',   '[B&C val]', a.F3_hat);
fprintf('%-30s  %-12s  %-12.6f\n', 'Z_pure',              '[B&C val]', a.Z_pure);
fprintf('%-30s  %-12s  %-12s\n',   'Runtime',             '0.11 s',    '300 iter');
fprintf('%-30s  %-12s  %-12s\n',   'Optimality gap',      '<=0.01%%',  '—');
fprintf('%-30s  %-12s  %-12d\n',   'Active stations',     '8',         sum(CSP));
fprintf('%-30s  %-12s  %-12d\n',   'Total chargers (post)','188',      sum(s_vec));

best = gbest;
save hbipso_best.mat CSP s_vec x gbest
end


%% ===================================================================
%%  CORRECTED evaluate_solution
%%  KEY CHANGE: F2 = Σ|L_j - L_k| for j<k  (pairwise, not std)
%%              All three objectives normalized to [0,1] before weighting
%%              Sign convention: min Z = -w1*F̂1 + w2*F̂2 + w3*F̂3
%% ===================================================================
function [FT, aux] = evaluate_solution(z, y, D, dist, Astall, lb_s, ub_s, Q, Dmax, ...
    w1, w2, w3, rhoU, rhoVcap, rhoVdist, rhoVlogic, lambda_pen, ...
    sig_threshold, beta_smooth, force_policy, forcedIdx, ...
    F1_ref, F2_ref, F3_ref)  %#ok<INUSD>

    m = numel(z);

    % --- Binary activation ---
    p_on = 1 ./ (1 + exp(-z));
    CSP  = double(p_on > sig_threshold);

    % --- Integer stalls with bounds ---
    s = round(y);
    s = max(s, lb_s);
    s = min(s, ub_s);

    % --- Hard force-open policy ---
    if force_policy && ~isempty(forcedIdx)
        CSP(forcedIdx) = 1;
        s(forcedIdx)   = max(s(forcedIdx), lb_s(forcedIdx));
    end
    s = s .* CSP;   % closed sites carry no stalls

    % --- Greedy Repair assignment ---
    [x, load, served, U, Vcap, Vdist, Vlogic] = greedy_assign(D, dist, CSP, s, Q, Dmax);

    % -------------------------------------------------------
    % F1: Service coverage — maximize served demand
    %     F̂1 = served / F1_ref  ∈ [0, 1]
    % -------------------------------------------------------
    F1_hat = served / max(F1_ref, eps);

    % -------------------------------------------------------
    % F2: Load balance — pairwise absolute load deviation
    %     F2_raw = Σ_{j<k} |L_j - L_k|   (open stations only)
    %     This is Σ u_jk in the MILP (Eq.7 and Eq.13 of paper)
    %     F̂2 = F2_raw / F2_ref  ∈ [0, 1]
    % -------------------------------------------------------
    openIdx = find(CSP > 0);
    F2_raw  = 0;
    if numel(openIdx) >= 2
        L_open = load(openIdx);
        for jj = 1:numel(openIdx)
            for kk = jj+1:numel(openIdx)
                F2_raw = F2_raw + abs(L_open(jj) - L_open(kk));
            end
        end
    end
    F2_hat = F2_raw / max(F2_ref, eps);

    % -------------------------------------------------------
    % F3: Land use — total stall area
    %     F3_raw = Σ A_stall * s_j   (Eq.8 of paper)
    %     F̂3 = F3_raw / F3_ref  ∈ [0, 1]
    % -------------------------------------------------------
    F3_raw = sum(s .* Astall);
    F3_hat = F3_raw / max(F3_ref, eps);

    % -------------------------------------------------------
    % Weighted-sum objective — same as paper Eq.(14):
    %   min Z = -w1*F̂1 + w2*F̂2 + w3*F̂3
    % -------------------------------------------------------
    Z_pure = -w1*F1_hat + w2*F2_hat + w3*F3_hat;

    % Penalty (infeasibility)
    Penalty = rhoU*U + rhoVcap*Vcap + rhoVdist*Vdist + rhoVlogic*Vlogic;

    % Total fitness (optimization target)
    FT = Z_pure + lambda_pen * Penalty;

    aux = struct( ...
        'CSP',    CSP, ...
        's',      s, ...
        'x',      x, ...
        'load',   load, ...
        'served', served, ...
        'F1_hat', F1_hat, ...
        'F2_raw', F2_raw, ...
        'F2_hat', F2_hat, ...
        'F3_raw', F3_raw, ...
        'F3_hat', F3_hat, ...
        'Z_pure', Z_pure, ...
        'U',      U, ...
        'Vcap',   Vcap, ...
        'Vdist',  Vdist, ...
        'Vlogic', Vlogic, ...
        'penalty', Penalty);
end


%% ===================================================================
%%  greedy_assign — unchanged from original
%% ===================================================================
function [x, load, served, U, Vcap, Vdist, Vlogic] = greedy_assign(D, dist, CSP, s, Q, Dmax)
    n = numel(D); m = numel(CSP);
    cap  = s(:) * Q;
    load = zeros(m, 1);
    x    = zeros(n, m);

    [~, ord] = sort(D, 'descend');

    for k = 1:n
        i = ord(k);
        [~, idx] = sort(dist(i,:), 'ascend');
        placed = false;

        for jj = 1:m
            j = idx(jj);
            if CSP(j)==1 && dist(i,j) <= Dmax && load(j)+D(i) <= cap(j)+1e-9
                x(i,j) = 1; load(j) = load(j) + D(i); placed = true; break;
            end
        end

        if ~placed
            j = idx(1);   % fallback: nearest regardless of constraints
            x(i,j) = 1; load(j) = load(j) + D(i);
        end
    end

    served = sum(min(load, cap));
    U      = max(0, sum(D) - served);
    over   = max(0, load - cap);
    Vcap   = sum(over);
    excess = max(0, dist - Dmax);
    Vdist  = sum(excess(:) .* repelem(D, size(dist,2)) .* x(:));
    Vlogic = 0;
    for j = 1:m
        if CSP(j) == 0 && (s(j) > 0 || load(j) > 0)
            Vlogic = Vlogic + load(j) + s(j);
        end
    end
end
% ----- B&C-scale objective calculation for BIPSO-GR -----
alpha = 0.00036;
beta  = 0.00215;

w1 = 0.33557046799799;
w2 = 0.33322147645101;
w3 = 0.33221147651010;

% y: nDemand x nStations assignment matrix
% EVcount: nDemand x nTypes
% SCF: 1 x nTypes
% powerT: 1 x nTypes
% sTot: 1 x nStations or nStations x 1
% Astall: effective land area per stall

[n, m] = size(y);
K = length(SCF);

P_EVCS = zeros(1,m);

for j = 1:m
    for i = 1:n
        if y(i,j) > 0.5
            for k = 1:K
                P_EVCS(j) = P_EVCS(j) + EVcount(i,k) * SCF(k) * powerT(k);
            end
        end
    end
end

F1_BCscale = -sum(P_EVCS);

Pbar = sum(P_EVCS) / m;
F2_BCscale = alpha * sum(abs(P_EVCS - Pbar));

A_land = sum(sTot(:)) * Astall;
F3_BCscale = beta * A_land;

Z_BCscale = w1*F1_BCscale + w2*F2_BCscale + w3*F3_BCscale;

fprintf('\n===== BIPSO-GR in B&C metric scale =====\n');
fprintf('P_EVCS per station (kW):\n');
disp(P_EVCS);

fprintf('F1_BCscale = %.6f\n', F1_BCscale);
fprintf('F2_BCscale = %.6f\n', F2_BCscale);
fprintf('F3_BCscale = %.6f\n', F3_BCscale);
fprintf('Z_BCscale  = %.6f\n', Z_BCscale);