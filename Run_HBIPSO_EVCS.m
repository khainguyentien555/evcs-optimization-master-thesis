function best = Run_HBIPSO_EVCS()
% HBIPSO-GR for EVCS siting & sizing (F1,F2,F3)
% - Binary logits for open/close (CSP)
% - Integer stalls per station (s)
% - Greedy Repair to build assignments
% - HARD CONSTRAINT: force-open some stations with minimum stalls
%
% Required data: evcs_data.mat (created by Input_data_HBIPSO.m)
% Output: hbipso_best.mat (CSP, s, x, gbest)

%% ===== Load & basic setup =====
clear; clc; rng(42);
S = load('evcs_data.mat');         % D, dist, Astall, Cmax, Q, Dmax, w1,w2,w3, rho*, lambda_pen, STATIONS
D = S.D; dist = S.dist; Astall = S.Astall; Cmax = S.Cmax;
Q = S.Q; Dmax = S.Dmax;
w1 = S.w1; w2 = S.w2; w3 = S.w3;   % bạn đã set = 1/3 trong file chuẩn hóa
rhoU = S.rhoU; rhoVcap = S.rhoVcap; rhoVdist = S.rhoVdist; rhoVlogic = S.rhoVlogic;
lambda_pen = S.lambda_pen;

[n,m] = size(dist);

%% ===== POLICY: force-open & minimum stalls (HARD) =====
% Danh sách trạm phải mở + số trụ tối thiểu tương ứng
forcedNames  = {'CC-TM1','CC-HH1','CC-HH2'};   % chỉnh tuỳ ý
smin_forced  = [20,        15,       15  ];    % ví dụ: tối thiểu trụ tại mỗi trạm
force_policy = true;                           % bật/tắt ép cứng

% Lập chỉ số & lower bound theo trạm
forcedIdx = zeros(0,1);
if force_policy
    forcedIdx = cellfun(@(nm) find(strcmp(S.STATIONS,nm),1,'first'), forcedNames);
    forcedIdx = forcedIdx(~cellfun(@isempty, num2cell(forcedIdx)));  %#ok<*NASGU>
end
lb_s = zeros(m,1);
if force_policy
    lb_s(forcedIdx) = smin_forced(:);
end
ub_s = Cmax;

%% ===== HBIPSO hyper-parameters =====
nPop    = 40;
maxIter = 300;
c1 = 1.8; c2 = 1.8;
w_in = 0.72;
sig_threshold = 0.5;    % binary ON threshold for CSP
beta_smooth  = 0.0;     % 0..1 smoothing for y (integers)

%% ===== Initialize swarm =====
pop = repmat(struct('z',[],'y',[],'vz',[],'vy',[],'fit',Inf,'aux',[],'pbest',[]), nPop, 1);

for p = 1:nPop
    pop(p).z  = atanh(2*rand(m,1)-1);             % logits (centered)
    y0        = lb_s + rand(m,1).*(ub_s-lb_s);    % respect lower-bound
    pop(p).y  = round(y0);

    pop(p).vz = zeros(m,1);
    pop(p).vy = zeros(m,1);

    [f,aux] = evaluate_solution(pop(p).z, pop(p).y, ...
               D, dist, Astall, lb_s, ub_s, Q, Dmax, ...
               w1,w2,w3, rhoU,rhoVcap,rhoVdist,rhoVlogic, lambda_pen, ...
               sig_threshold, beta_smooth, force_policy, forcedIdx);
    pop(p).fit = f; pop(p).aux = aux;
    pop(p).pbest = struct('z',pop(p).z,'y',pop(p).y,'fit',f);
end

[~,gix] = min([pop.fit]);
gbest = struct('z',pop(gix).z,'y',pop(gix).y,'fit',pop(gix).fit,'aux',pop(gix).aux);

fprintf('Iter    FT        Served     Penalty    Open  Stalls\n');
fprintf('----  --------  ----------  ---------   ----  ------\n');

%% ===== Main PSO loop =====
for it = 1:maxIter
    for p = 1:nPop
        r1 = rand(m,1); r2 = rand(m,1);

        % velocity
        pop(p).vz = w_in*pop(p).vz + c1*r1.*(pop(p).pbest.z - pop(p).z) + c2*r2.*(gbest.z - pop(p).z);
        pop(p).vy = w_in*pop(p).vy + c1*r1.*(pop(p).pbest.y - pop(p).y) + c2*r2.*(gbest.y - pop(p).y);

        % position
        pop(p).z = pop(p).z + pop(p).vz;

        y_new = pop(p).y + pop(p).vy;
        if beta_smooth>0
            y_new = (1-beta_smooth)*pop(p).y + beta_smooth*y_new;
        end
        % tôn trọng [lb_s, ub_s]
        y_new = max(y_new, lb_s);
        y_new = min(y_new, ub_s);

        [f,aux] = evaluate_solution(pop(p).z, y_new, ...
                    D, dist, Astall, lb_s, ub_s, Q, Dmax, ...
                    w1,w2,w3, rhoU,rhoVcap,rhoVdist,rhoVlogic, lambda_pen, ...
                    sig_threshold, beta_smooth, force_policy, forcedIdx);

        pop(p).y   = y_new;
        pop(p).fit = f; pop(p).aux = aux;

        if f < pop(p).pbest.fit
            pop(p).pbest = struct('z',pop(p).z,'y',pop(p).y,'fit',f);
        end
        if f < gbest.fit
            gbest = struct('z',pop(p).z,'y',pop(p).y,'fit',f,'aux',aux);
        end
    end

    if it==1 || mod(it,25)==0
        fprintf('%4d  %8.4f  %10.2f  %9.2f   %4d  %6d\n', ...
            it, gbest.fit, gbest.aux.served, gbest.aux.penalty, ...
            sum(gbest.aux.CSP), sum(gbest.aux.s));
    end
end

%% ===== Final report & save =====
CSP = gbest.aux.CSP; s = gbest.aux.s; x = gbest.aux.x;

fprintf('\n=== BEST SOLUTION ===\n');
fprintf('Served: %.2f / %.2f\n', gbest.aux.served, sum(D));
fprintf('Load std among open stations: %.4f\n', gbest.aux.load_std);
fprintf('Total stall area: %.2f\n', sum(s.*Astall));
fprintf('Penalty = %.3f  (U=%.1f, Vcap=%.1f, Vdist=%.1f, Vlogic=%.1f)\n', ...
    gbest.aux.penalty, gbest.aux.U, gbest.aux.Vcap, gbest.aux.Vdist, gbest.aux.Vlogic);
fprintf('Open stations: %d / %d | Total stalls: %d\n', sum(CSP), m, sum(s));

save hbipso_best.mat CSP s x gbest
end


%% ======================= Helper functions ================================

function [FT, aux] = evaluate_solution(z, y, D, dist, Astall, lb_s, ub_s, Q, Dmax, ...
    w1,w2,w3, rhoU,rhoVcap,rhoVdist,rhoVlogic, lambda_pen, ...
    sig_threshold, beta_smooth, force_policy, forcedIdx) %#ok<INUSD>

    m = numel(z);

    % Binary activation from logits
    p_on = 1./(1+exp(-z));
    CSP  = double(p_on > sig_threshold);

    % Integer stalls with bounds
    s = round(y);
    s = max(s, lb_s);
    s = min(s, ub_s);

    % HARD policy: force these stations open & ensure >= lb
    if force_policy && ~isempty(forcedIdx)
        CSP(forcedIdx) = 1;
        s(forcedIdx)   = max(s(forcedIdx), lb_s(forcedIdx));
    end

    % Closed site must not carry stalls/load
    s = s .* CSP;

    % Build feasible assignment via Greedy Repair
    [x, load, served, U, Vcap, Vdist, Vlogic] = greedy_assign(D, dist, CSP, s, Q, Dmax);

    % ---- Objectives (F1,F2,F3) ----
    totalD = sum(D);

    F1p = -(served / max(totalD,eps));     % maximize served -> minimize negative
    if any(CSP>0)
        F2 = std(load(CSP>0));             % std as balance measure
    else
        F2 = 0;
    end
    F3 = sum(s .* Astall);                 % total stall area

    Penalty = rhoU*U + rhoVcap*Vcap + rhoVdist*Vdist + rhoVlogic*Vlogic;

    FT = w1*F1p + w2*F2 + w3*F3 + lambda_pen*Penalty;

    aux = struct('CSP',CSP,'s',s,'x',x,'served',served, ...
                 'U',U,'Vcap',Vcap,'Vdist',Vdist,'Vlogic',Vlogic, ...
                 'load_std',F2,'penalty',Penalty);
end


function [x, load, served, U, Vcap, Vdist, Vlogic] = greedy_assign(D, dist, CSP, s, Q, Dmax)
% Greedy Repair:
% - sort demands desc
% - assign to nearest OPEN station with remaining capacity and within Dmax
% - if not found, assign to absolute nearest (may incur penalties — accounted by V*)

    n = numel(D); m = numel(CSP);
    cap  = s(:)*Q;                 % capacity per site
    load = zeros(m,1);             % used capacity
    x    = zeros(n,m);             % assignment (one-hot)

    [~,ord] = sort(D,'descend');

    for k = 1:n
        i = ord(k);
        [~,idx] = sort(dist(i,:),'ascend');

        placed = false;
        for jj = 1:m
            j = idx(jj);
            if CSP(j)==1 && dist(i,j) <= Dmax && load(j)+D(i) <= cap(j)+1e-9
                x(i,j) = 1; load(j) = load(j)+D(i); placed = true; break;
            end
        end

        if ~placed
            % fallback: nearest overall
            j = idx(1);
            x(i,j) = 1; load(j) = load(j)+D(i);
        end
    end

    % Served demand (capped by capacity)
    served = sum(min(load, cap));
    U      = max(0, sum(D) - served);          % unmet demand

    % Capacity violation magnitude
    over  = max(0, load - cap);
    Vcap  = sum(over);

    % Distance violation magnitude (excess beyond Dmax, weighted by D(i))
    excess = max(0, dist - Dmax);
    Vdist  = sum( (excess(:)) .* (repelem(D, size(dist,2))) .* (x(:)) );

    % Logic violation: any load/stalls at closed sites
    Vlogic = 0;
    for j = 1:m
        if CSP(j)==0
            if s(j)>0 || load(j)>0
                Vlogic = Vlogic + load(j) + s(j);
            end
        end
    end
end