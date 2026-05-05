% HBIPSO → CPLEX Hybrid Exporter (EVCS)


% Vectors per TYPE
writeVector(fid, 'SCF', TYPES, SCF);
writeVector(fid, 'power', TYPES, power_kW);
writeVector(fid, 'area', TYPES, area_stall);


% Matrices
writeMatrix(fid, 'EVcount', POINTS, TYPES, EVcount);
writeMatrix(fid, 'maxCharger', STATIONS, TYPES, maxChg);
writeMatrix(fid, 'DIST', POINTS, STATIONS, DIST_km);
writeMatrix(fid, 'ALLOW', POINTS, STATIONS, ALLOW);


% Additional masks
writeVector(fid, 'isBusType', TYPES, double(isBusType));
writeVector(fid, 'isBusAllowed', STATIONS, double(isBusAllowed));


% Forced openings & minimum stalls per station (≥1 for all)
writeVector(fid, 'sMin', STATIONS, sMin(:)');
writeVector(fid, 'FORCED_OPEN', STATIONS, ones(1,J)); % all ones per requirement (B)


fprintf(fid, '\n// End of data\n');


fprintf('Exported complete OPL data to %s\n', outfile);


% ---------- helpers ----------
function writeVector(fid, name, keys, vals)
fprintf(fid, '%s = [\n', name);
for k = 1:numel(keys)
if isstring(keys)
key = keys(k);
else
key = string(keys{k});
end
fprintf(fid, ' <"%s"> %.12g\n', key, vals(k));
end
fprintf(fid, '];\n\n');
end


function writeMatrix(fid, name, rows, cols, M)
[R,C] = size(M);
assert(R==numel(rows) && C==numel(cols), '%s size mismatch', name);
fprintf(fid, '%s = [\n', name);
for i = 1:numel(rows)
for j = 1:numel(cols)
r = rows(i); c = cols(j);
if isstring(r), rr = r; else, rr = string(r{1}); end
if isstring(c), cc = c; else, cc = string(c{1}); end
fprintf(fid, ' <"%s","%s"> %.12g\n', rr, cc, M(i,j));
end
end
fprintf(fid, '];\n\n');
end