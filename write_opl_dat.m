function write_opl_dat(fname, POINTS, STATIONS, TYPES, EVcount, DIST, maxCharger, varargin)
% WRITE_OPL_DAT  Ghi file .dat cho OPL từ ma trận MATLAB
p = inputParser;
addParameter(p,'alpha',0.00036); addParameter(p,'beta',0.00215);
addParameter(p,'w1',0.33); addParameter(p,'w2',0.33); addParameter(p,'w3',0.33);
addParameter(p,'lb_x',[]);           % lower bound cho x[j][t]
addParameter(p,'mipstart_x',[]);     % nghiệm khởi tạo x0
addParameter(p,'mipstart_y',[]);     % nghiệm khởi tạo y0
parse(p,varargin{:});
P = p.Results;

fid = fopen(fname,'w');

% Sets
fprintf(fid,'POINTS = { %s };\n\n', join("""" + POINTS + """", ", "));
fprintf(fid,'STATIONS = { %s };\n\n', join("""" + STATIONS + """", ", "));
fprintf(fid,'TYPES = { %s };\n\n', join("""" + TYPES + """", ", "));

% Scalars
fprintf(fid,'alpha = %.8g;\n', P.alpha);
fprintf(fid,'beta  = %.8g;\n', P.beta);
fprintf(fid,'w1 = %.8g; w2 = %.8g; w3 = %.8g;\n\n', P.w1,P.w2,P.w3);

% EVcount
fprintf(fid,'EVcount = [\n');
for i=1:size(EVcount,1)
    fprintf(fid,'  %s;\n', strjoin(string(EVcount(i,:)), ' '));
end
fprintf(fid,'];\n\n');

% DIST (m)
fprintf(fid,'DIST = [\n');
for i=1:size(DIST,1)
    fprintf(fid,'  %s;\n', strjoin(string(DIST(i,:)), ' '));
end
fprintf(fid,'];\n\n');

% maxCharger
fprintf(fid,'maxCharger = [\n');
for j=1:size(maxCharger,1)
    fprintf(fid,'  %s;\n', strjoin(string(maxCharger(j,:)), ' '));
end
fprintf(fid,'];\n\n');

% Lower bounds x (tuỳ chọn)
if ~isempty(P.lb_x)
    fprintf(fid,'lb_x = [\n');
    for j=1:size(P.lb_x,1)
        fprintf(fid,'  %s;\n', strjoin(string(P.lb_x(j,:)), ' '));
    end
    fprintf(fid,'];\n\n');
end

% MIP start (tuỳ chọn)
if ~isempty(P.mipstart_x)
    fprintf(fid,'x_mipstart = [\n');
    for j=1:size(P.mipstart_x,1)
        fprintf(fid,'  %s;\n', strjoin(string(P.mipstart_x(j,:)), ' '));
    end
    fprintf(fid,'];\n\n');
end
if ~isempty(P.mipstart_y)
    fprintf(fid,'y_mipstart = [\n');
    for i=1:size(P.mipstart_y,1)
        fprintf(fid,'  %s;\n', strjoin(string(double(P.mipstart_y(i,:))), ' '));
    end
    fprintf(fid,'];\n\n');
end

fclose(fid);
end
