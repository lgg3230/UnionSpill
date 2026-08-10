%% Bilateral Connectivity Script - Post-Treatment Period (2011-2016)
% Computes pairwise flows between all establishment pairs
% Uses the SAME sample as pre-period (lagos_sample_avg==1 & in_balanced_panel==1)
% Output: CSV with bilateral connectivity measures for each pair (i,j)

clear; clc; close all;

%% Define the post-treatment years
start_year = 2011;
end_year   = 2016;

%% Load sample establishments (same sample as pre-period)
% This file contains establishments with lagos_sample_avg==1 & in_balanced_panel==1
fprintf('Loading sample establishment IDs...\n');
sample_file = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/sample_establishments.csv';
sample_estabs = readtable(sample_file, 'VariableNamingRule', 'preserve');
sample_ids = string(sample_estabs.identificad);
n_sample = length(sample_ids);
fprintf('Loaded %d sample establishments.\n', n_sample);

%% Initialize storage for bilateral flows across year pairs
bilateral_all = {};

%% Loop over consecutive year pairs
for y = start_year:(end_year-1)
    next_y = y + 1;

    fprintf('Processing year pair %d-%d...\n', y, next_y);

    % Load employers data for this year pair
    filename = sprintf('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv', y, next_y);
    employers = readtable(filename, 'VariableNamingRule', 'preserve');

    % Extract establishment IDs
    estab_y = string(employers.(['identificad_' num2str(y)]));
    estab_next = string(employers.(['identificad_' num2str(next_y)]));

    % FILTER: Keep only rows where BOTH establishments are in sample
    in_sample_y = ismember(estab_y, sample_ids);
    in_sample_next = ismember(estab_next, sample_ids);
    valid_sample = in_sample_y & in_sample_next;

    fprintf('  Rows before sample filter: %d\n', length(estab_y));
    fprintf('  Rows after sample filter: %d\n', sum(valid_sample));

    % Apply filter
    estab_y = estab_y(valid_sample);
    estab_next = estab_next(valid_sample);
    employers = employers(valid_sample, :);

    % Build unique establishment mapping (only from filtered data)
    unique_estabs = unique([estab_y; estab_next]);
    n_estabs = length(unique_estabs);
    fprintf('  Unique establishments in this year pair: %d\n', n_estabs);

    % Map each employer ID to its index
    [~, estab_y_idx] = ismember(estab_y, unique_estabs);
    [~, estab_next_idx] = ismember(estab_next, unique_estabs);

    % Remove invalid rows (should be none after filtering, but keep for safety)
    valid_idx = (estab_y_idx > 0) & (estab_next_idx > 0);
    estab_y_idx = estab_y_idx(valid_idx);
    estab_next_idx = estab_next_idx(valid_idx);

    % Load employment data
    emp_y    = employers.(['firm_emp_' num2str(y)]);
    emp_next = employers.(['firm_emp_' num2str(next_y)]);

    % Map employment to unique establishments
    emp_y_mapped    = zeros(n_estabs, 1);
    emp_next_mapped = zeros(n_estabs, 1);

    [found_y, idx_y] = ismember(estab_y, unique_estabs);
    emp_y_mapped(idx_y(found_y)) = emp_y(found_y);

    [found_next, idx_next] = ismember(estab_next, unique_estabs);
    emp_next_mapped(idx_next(found_next)) = emp_next(found_next);

    % Compute average employment
    avg_emp = (emp_y_mapped + emp_next_mapped) / 2;
    avg_emp(avg_emp == 0) = NaN;

    % Construct adjacency matrix (zeros on main diagonal)
    M_estabs = sparse(estab_y_idx, estab_next_idx, 1, n_estabs, n_estabs);
    M_estabs(1:n_estabs+1:end) = 0;

    % Extract non-zero entries as (i, j, flows_ij)
    [row_idx, col_idx, flows] = find(M_estabs);

    % Create a table for this year pair
    n_pairs = length(row_idx);
    fprintf('  Found %d directed pairs for year pair %d-%d.\n', n_pairs, y, next_y);

    % Initialize storage for bilateral measures
    estab_i_list = strings(n_pairs, 1);
    estab_j_list = strings(n_pairs, 1);
    flows_ij_list = zeros(n_pairs, 1);
    flows_ji_list = zeros(n_pairs, 1);
    avg_emp_i_list = zeros(n_pairs, 1);
    avg_emp_j_list = zeros(n_pairs, 1);

    for k = 1:n_pairs
        i = row_idx(k);
        j = col_idx(k);

        estab_i_list(k) = unique_estabs(i);
        estab_j_list(k) = unique_estabs(j);
        flows_ij_list(k) = full(M_estabs(i, j));
        flows_ji_list(k) = full(M_estabs(j, i));
        avg_emp_i_list(k) = avg_emp(i);
        avg_emp_j_list(k) = avg_emp(j);
    end

    % Create table for this year pair
    T_bilateral = table(estab_i_list, estab_j_list, flows_ij_list, flows_ji_list, ...
        avg_emp_i_list, avg_emp_j_list, ...
        'VariableNames', {'estab_i', 'estab_j', 'flows_ij', 'flows_ji', 'avg_emp_i', 'avg_emp_j'});

    % Compute bilateral flow (symmetrized)
    T_bilateral.flows_bilateral = T_bilateral.flows_ij + T_bilateral.flows_ji;

    % Compute ratio normalized by avg_emp_i
    T_bilateral.ratio_t = T_bilateral.flows_bilateral ./ T_bilateral.avg_emp_i;

    % Rename ratio column with year suffix
    ratioVarName = sprintf('ratio_%d_%d', y, next_y);
    flowsVarName = sprintf('flows_bilateral_%d_%d', y, next_y);

    T_bilateral.Properties.VariableNames{'ratio_t'} = ratioVarName;
    T_bilateral.Properties.VariableNames{'flows_bilateral'} = flowsVarName;

    % Keep only essential columns for merging
    T_bilateral_slim = T_bilateral(:, {'estab_i', 'estab_j', ratioVarName, flowsVarName});

    bilateral_all{end+1} = T_bilateral_slim;
end

%% Merge all year pairs
fprintf('\nMerging all year pairs...\n');
final_bilateral = bilateral_all{1};

for k = 2:length(bilateral_all)
    % Outer join on (estab_i, estab_j)
    final_bilateral = outerjoin(final_bilateral, bilateral_all{k}, ...
        'Keys', {'estab_i', 'estab_j'}, ...
        'MergeKeys', true, ...
        'Type', 'full');
end

%% Aggregate to unique pairs (i,j) where i < j
fprintf('Aggregating to unique pairs...\n');

% Convert to string for comparison
estab_i_str = string(final_bilateral.estab_i);
estab_j_str = string(final_bilateral.estab_j);

% Create canonical ordering: always put smaller ID first
pair_first = strings(height(final_bilateral), 1);
pair_second = strings(height(final_bilateral), 1);

for k = 1:height(final_bilateral)
    if estab_i_str(k) < estab_j_str(k)
        pair_first(k) = estab_i_str(k);
        pair_second(k) = estab_j_str(k);
    else
        pair_first(k) = estab_j_str(k);
        pair_second(k) = estab_i_str(k);
    end
end

final_bilateral.pair_first = pair_first;
final_bilateral.pair_second = pair_second;

% Create unique pair identifier
pair_key = strcat(pair_first, '_', pair_second);
[unique_pairs, ~, pair_idx] = unique(pair_key);
n_unique_pairs = length(unique_pairs);

fprintf('Number of unique pairs: %d\n', n_unique_pairs);

% Initialize output arrays for post-treatment year pairs
out_first = strings(n_unique_pairs, 1);
out_second = strings(n_unique_pairs, 1);
out_flows_total = zeros(n_unique_pairs, 1);

% Year pairs: 2011-2012, 2012-2013, 2013-2014, 2014-2015, 2015-2016
out_ratio_1112 = nan(n_unique_pairs, 1);
out_ratio_1213 = nan(n_unique_pairs, 1);
out_ratio_1314 = nan(n_unique_pairs, 1);
out_ratio_1415 = nan(n_unique_pairs, 1);
out_ratio_1516 = nan(n_unique_pairs, 1);

out_flows_1112 = zeros(n_unique_pairs, 1);
out_flows_1213 = zeros(n_unique_pairs, 1);
out_flows_1314 = zeros(n_unique_pairs, 1);
out_flows_1415 = zeros(n_unique_pairs, 1);
out_flows_1516 = zeros(n_unique_pairs, 1);

% Get column indices for year-specific variables
cols = final_bilateral.Properties.VariableNames;

fprintf('Processing unique pairs...\n');
for p = 1:n_unique_pairs
    if mod(p, 100000) == 0
        fprintf('  Processed %d / %d pairs...\n', p, n_unique_pairs);
    end

    mask = (pair_idx == p);
    subset = final_bilateral(mask, :);

    % Extract pair identifiers
    out_first(p) = subset.pair_first(1);
    out_second(p) = subset.pair_second(1);

    % For flows, take the max (they should be the same for both directions)
    if ismember('flows_bilateral_2011_2012', cols)
        vals = subset.flows_bilateral_2011_2012;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_1112(p) = max(vals);
        end
    end
    if ismember('flows_bilateral_2012_2013', cols)
        vals = subset.flows_bilateral_2012_2013;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_1213(p) = max(vals);
        end
    end
    if ismember('flows_bilateral_2013_2014', cols)
        vals = subset.flows_bilateral_2013_2014;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_1314(p) = max(vals);
        end
    end
    if ismember('flows_bilateral_2014_2015', cols)
        vals = subset.flows_bilateral_2014_2015;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_1415(p) = max(vals);
        end
    end
    if ismember('flows_bilateral_2015_2016', cols)
        vals = subset.flows_bilateral_2015_2016;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_1516(p) = max(vals);
        end
    end

    % For ratios, take the one where the denominator is the "first" establishment
    for row = 1:height(subset)
        orig_i = subset.estab_i(row);
        first_estab = subset.pair_first(row);

        if orig_i == first_estab
            if ismember('ratio_2011_2012', cols) && ~isnan(subset.ratio_2011_2012(row))
                out_ratio_1112(p) = subset.ratio_2011_2012(row);
            end
            if ismember('ratio_2012_2013', cols) && ~isnan(subset.ratio_2012_2013(row))
                out_ratio_1213(p) = subset.ratio_2012_2013(row);
            end
            if ismember('ratio_2013_2014', cols) && ~isnan(subset.ratio_2013_2014(row))
                out_ratio_1314(p) = subset.ratio_2013_2014(row);
            end
            if ismember('ratio_2014_2015', cols) && ~isnan(subset.ratio_2014_2015(row))
                out_ratio_1415(p) = subset.ratio_2014_2015(row);
            end
            if ismember('ratio_2015_2016', cols) && ~isnan(subset.ratio_2015_2016(row))
                out_ratio_1516(p) = subset.ratio_2015_2016(row);
            end
            break;
        end
    end

    out_flows_total(p) = out_flows_1112(p) + out_flows_1213(p) + out_flows_1314(p) + ...
                         out_flows_1415(p) + out_flows_1516(p);
end

%% Compute average bilateral connectivity per worker across year pairs
fprintf('Computing average bilateral connectivity...\n');

% Count non-missing year pairs for each pair
n_years = ~isnan(out_ratio_1112) + ~isnan(out_ratio_1213) + ~isnan(out_ratio_1314) + ...
          ~isnan(out_ratio_1415) + ~isnan(out_ratio_1516);

% Replace NaN with 0 for summation
r1112 = out_ratio_1112; r1112(isnan(r1112)) = 0;
r1213 = out_ratio_1213; r1213(isnan(r1213)) = 0;
r1314 = out_ratio_1314; r1314(isnan(r1314)) = 0;
r1415 = out_ratio_1415; r1415(isnan(r1415)) = 0;
r1516 = out_ratio_1516; r1516(isnan(r1516)) = 0;

bilateral_conn_pw = (r1112 + r1213 + r1314 + r1415 + r1516) ./ max(n_years, 1);
bilateral_conn_pw(n_years == 0) = NaN;

%% Create output table
output_table = table(out_first, out_second, bilateral_conn_pw, out_flows_total, ...
    out_flows_1112, out_flows_1213, out_flows_1314, out_flows_1415, out_flows_1516, ...
    out_ratio_1112, out_ratio_1213, out_ratio_1314, out_ratio_1415, out_ratio_1516, ...
    'VariableNames', {'identificad_i', 'identificad_j', 'bilateral_conn_pw', 'flows_total', ...
    'flows_1112', 'flows_1213', 'flows_1314', 'flows_1415', 'flows_1516', ...
    'ratio_1112', 'ratio_1213', 'ratio_1314', 'ratio_1415', 'ratio_1516'});

%% Save output
outputFile = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_connectivity_2011_2016.csv';
writetable(output_table, outputFile);

fprintf('\nSaved bilateral connectivity data (2011-2016) to %s\n', outputFile);
fprintf('Total unique pairs: %d\n', height(output_table));
fprintf('Done!\n');
