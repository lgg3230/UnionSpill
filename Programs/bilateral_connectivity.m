%% Bilateral Connectivity Script
% Computes pairwise flows between all establishment pairs
% Output: CSV with bilateral connectivity measures for each pair (i,j)
clear; clc; close all;

%% Define the available years
start_year = 2007;
end_year   = 2011;

%% Note: Sample restrictions (lagos_sample_avg and in_balanced_panel)
%% are applied in the Stata script after importing this output

%% Initialize storage for bilateral flows across year pairs
bilateral_all = {};

%% Loop over consecutive year pairs
for y = start_year:(end_year-1)
    next_y = y + 1;

    fprintf('Processing year pair %d-%d...\n', y, next_y);

    % Load employers data for this year pair
    filename = sprintf('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv', y, next_y);
    employers = readtable(filename);

    % Extract establishment IDs
    estab_y = string(employers.(['identificad_' num2str(y)]));
    estab_next = string(employers.(['identificad_' num2str(next_y)]));

    % Build unique establishment mapping
    unique_estabs = unique([estab_y; estab_next]);
    n_estabs = length(unique_estabs);

    % Map each employer ID to its index
    [~, estab_y_idx] = ismember(estab_y, unique_estabs);
    [~, estab_next_idx] = ismember(estab_next, unique_estabs);

    % Remove invalid rows
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
    M_estabs(1:n_estabs+1:end) = 0;  % Remove self-loops

    % Extract non-zero entries as (i, j, flows_ij)
    [row_idx, col_idx, flows] = find(M_estabs);

    % For bilateral pairs, we want i < j (to avoid duplicates)
    % Compute symmetrized flows: flows_pair = M(i,j) + M(j,i)

    % Create a table for this year pair
    n_pairs = length(row_idx);

    % Initialize storage for bilateral measures
    estab_i_list = cell(n_pairs, 1);
    estab_j_list = cell(n_pairs, 1);
    flows_ij_list = zeros(n_pairs, 1);
    flows_ji_list = zeros(n_pairs, 1);
    avg_emp_i_list = zeros(n_pairs, 1);
    avg_emp_j_list = zeros(n_pairs, 1);

    for k = 1:n_pairs
        i = row_idx(k);
        j = col_idx(k);

        estab_i_list{k} = unique_estabs(i);
        estab_j_list{k} = unique_estabs(j);
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

    fprintf('Found %d directed pairs for year pair %d-%d.\n', n_pairs, y, next_y);
end

%% Merge all year pairs
% Start with first year pair
final_bilateral = bilateral_all{1};

for k = 2:length(bilateral_all)
    % Outer join on (estab_i, estab_j)
    final_bilateral = outerjoin(final_bilateral, bilateral_all{k}, ...
        'Keys', {'estab_i', 'estab_j'}, ...
        'MergeKeys', true, ...
        'Type', 'full');
end

%% Now we need to aggregate to unique pairs (i,j) where i < j
% This symmetrizes the data

fprintf('Aggregating to unique pairs...\n');

% Convert cell arrays to string for comparison
estab_i_str = string(final_bilateral.estab_i);
estab_j_str = string(final_bilateral.estab_j);

% Create canonical ordering: always put smaller ID first
pair_first = cell(height(final_bilateral), 1);
pair_second = cell(height(final_bilateral), 1);

for k = 1:height(final_bilateral)
    if estab_i_str(k) < estab_j_str(k)
        pair_first{k} = estab_i_str(k);
        pair_second{k} = estab_j_str(k);
    else
        pair_first{k} = estab_j_str(k);
        pair_second{k} = estab_i_str(k);
    end
end

final_bilateral.pair_first = pair_first;
final_bilateral.pair_second = pair_second;

% Group by (pair_first, pair_second) and sum flows, average ratios
% Using groupsummary or accumarray approach

% Create unique pair identifier
pair_key = strcat(string(pair_first), '_', string(pair_second));
[unique_pairs, ~, pair_idx] = unique(pair_key);
n_unique_pairs = length(unique_pairs);

fprintf('Number of unique pairs: %d\n', n_unique_pairs);

% Initialize output arrays
out_first = cell(n_unique_pairs, 1);
out_second = cell(n_unique_pairs, 1);
out_flows_total = zeros(n_unique_pairs, 1);
out_ratio_0708 = nan(n_unique_pairs, 1);
out_ratio_0809 = nan(n_unique_pairs, 1);
out_ratio_0910 = nan(n_unique_pairs, 1);
out_ratio_1011 = nan(n_unique_pairs, 1);
out_flows_0708 = zeros(n_unique_pairs, 1);
out_flows_0809 = zeros(n_unique_pairs, 1);
out_flows_0910 = zeros(n_unique_pairs, 1);
out_flows_1011 = zeros(n_unique_pairs, 1);

% Get column indices for year-specific variables
cols = final_bilateral.Properties.VariableNames;

for p = 1:n_unique_pairs
    mask = (pair_idx == p);
    subset = final_bilateral(mask, :);

    % Extract pair identifiers
    out_first{p} = subset.pair_first{1};
    out_second{p} = subset.pair_second{1};

    % For flows, take the max (they should be the same for both directions since
    % flows_bilateral = M(i,j) + M(j,i) is computed for each directed pair)
    % If both (i,j) and (j,i) exist, they have the same bilateral flow count
    if ismember('flows_bilateral_2007_2008', cols)
        vals = subset.flows_bilateral_2007_2008;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_0708(p) = max(vals);  % Take max, not sum
        end
    end
    if ismember('flows_bilateral_2008_2009', cols)
        vals = subset.flows_bilateral_2008_2009;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_0809(p) = max(vals);
        end
    end
    if ismember('flows_bilateral_2009_2010', cols)
        vals = subset.flows_bilateral_2009_2010;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_0910(p) = max(vals);
        end
    end
    if ismember('flows_bilateral_2010_2011', cols)
        vals = subset.flows_bilateral_2010_2011;
        vals = vals(~isnan(vals));
        if ~isempty(vals)
            out_flows_1011(p) = max(vals);
        end
    end

    % For ratios, take the one where the denominator is the "first" establishment
    % (i.e., keep ratio where estab_i == pair_first)
    % This ensures consistent normalization
    for row = 1:height(subset)
        orig_i = string(subset.estab_i{row});
        first_estab = string(subset.pair_first{row});

        if orig_i == first_estab
            % This row has the correct denominator (avg_emp of first estab)
            if ismember('ratio_2007_2008', cols) && ~isnan(subset.ratio_2007_2008(row))
                out_ratio_0708(p) = subset.ratio_2007_2008(row);
            end
            if ismember('ratio_2008_2009', cols) && ~isnan(subset.ratio_2008_2009(row))
                out_ratio_0809(p) = subset.ratio_2008_2009(row);
            end
            if ismember('ratio_2009_2010', cols) && ~isnan(subset.ratio_2009_2010(row))
                out_ratio_0910(p) = subset.ratio_2009_2010(row);
            end
            if ismember('ratio_2010_2011', cols) && ~isnan(subset.ratio_2010_2011(row))
                out_ratio_1011(p) = subset.ratio_2010_2011(row);
            end
            break;  % Found the correct row, no need to continue
        end
    end

    out_flows_total(p) = out_flows_0708(p) + out_flows_0809(p) + out_flows_0910(p) + out_flows_1011(p);
end

%% Compute average bilateral connectivity per worker across year pairs
% bilateral_conn_pw = average of (flows_ij + flows_ji) / avg_emp_i across t

% Count non-missing year pairs for each pair
n_years = ~isnan(out_ratio_0708) + ~isnan(out_ratio_0809) + ~isnan(out_ratio_0910) + ~isnan(out_ratio_1011);

% Replace NaN with 0 for summation
r0708 = out_ratio_0708; r0708(isnan(r0708)) = 0;
r0809 = out_ratio_0809; r0809(isnan(r0809)) = 0;
r0910 = out_ratio_0910; r0910(isnan(r0910)) = 0;
r1011 = out_ratio_1011; r1011(isnan(r1011)) = 0;

bilateral_conn_pw = (r0708 + r0809 + r0910 + r1011) ./ max(n_years, 1);
bilateral_conn_pw(n_years == 0) = NaN;

%% Create output table
output_table = table(out_first, out_second, bilateral_conn_pw, out_flows_total, ...
    out_flows_0708, out_flows_0809, out_flows_0910, out_flows_1011, ...
    out_ratio_0708, out_ratio_0809, out_ratio_0910, out_ratio_1011, ...
    'VariableNames', {'identificad_i', 'identificad_j', 'bilateral_conn_pw', 'flows_total', ...
    'flows_0708', 'flows_0809', 'flows_0910', 'flows_1011', ...
    'ratio_0708', 'ratio_0809', 'ratio_0910', 'ratio_1011'});

%% Save output
outputFile = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_connectivity_2007_2011.csv';
writetable(output_table, outputFile);

fprintf('Saved bilateral connectivity data to %s\n', outputFile);
fprintf('Total unique pairs: %d\n', height(output_table));
fprintf('Done!\n');
