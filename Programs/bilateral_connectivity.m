%% Bilateral Connectivity Script
% Computes pairwise flows between all establishment pairs
% Output: CSV with bilateral connectivity measures for each pair (i,j)
clear; clc; close all;                                                          % Clear workspace, command window, and close all figures

%% Define the available years
start_year = 2007;                                                              % Set starting year for analysis period
end_year   = 2011;                                                              % Set ending year for analysis period

%% Note: Sample restrictions (lagos_sample_avg and in_balanced_panel)
%% are applied in the Stata script after importing this output

%% Initialize storage for bilateral flows across year pairs
bilateral_all = {};                                                             % Initialize empty cell array to store bilateral flow tables from each year pair

%% Loop over consecutive year pairs
for y = start_year:(end_year-1)                                                 % Loop through years 2007 to 2010 (last year before end_year)
    next_y = y + 1;                                                             % Set next year as current year plus one

    fprintf('Processing year pair %d-%d...\n', y, next_y);                      % Print progress message showing current year pair being processed

    % Load employers data for this year pair
    filename = sprintf('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv', y, next_y); % Construct file path for employers CSV file
    employers = readtable(filename);                                            % Read employers data from CSV into a table

    % Extract establishment IDs
    estab_y = string(employers.(['identificad_' num2str(y)]));                  % Extract establishment IDs for current year as string array
    estab_next = string(employers.(['identificad_' num2str(next_y)]));          % Extract establishment IDs for next year as string array

    % Build unique establishment mapping
    unique_estabs = unique([estab_y; estab_next]);                              % Combine and get unique establishment IDs across both years
    n_estabs = length(unique_estabs);                                           % Count total number of unique establishments

    % Map each employer ID to its index
    [~, estab_y_idx] = ismember(estab_y, unique_estabs);                        % Get index positions of current year establishments in unique list
    [~, estab_next_idx] = ismember(estab_next, unique_estabs);                  % Get index positions of next year establishments in unique list

    % Remove invalid rows
    valid_idx = (estab_y_idx > 0) & (estab_next_idx > 0);                       % Create logical mask for rows where both establishments are valid
    estab_y_idx = estab_y_idx(valid_idx);                                       % Keep only valid current year indices
    estab_next_idx = estab_next_idx(valid_idx);                                 % Keep only valid next year indices

    % Load employment data
    emp_y    = employers.(['firm_emp_' num2str(y)]);                            % Extract firm employment for current year
    emp_next = employers.(['firm_emp_' num2str(next_y)]);                       % Extract firm employment for next year

    % Map employment to unique establishments
    emp_y_mapped    = zeros(n_estabs, 1);                                       % Initialize zeros vector for current year employment mapping
    emp_next_mapped = zeros(n_estabs, 1);                                       % Initialize zeros vector for next year employment mapping

    [found_y, idx_y] = ismember(estab_y, unique_estabs);                        % Find which current year establishments exist in unique list and their indices
    emp_y_mapped(idx_y(found_y)) = emp_y(found_y);                              % Assign employment values to corresponding positions in mapped array

    [found_next, idx_next] = ismember(estab_next, unique_estabs);               % Find which next year establishments exist in unique list and their indices
    emp_next_mapped(idx_next(found_next)) = emp_next(found_next);               % Assign employment values to corresponding positions in mapped array

    % Compute average employment
    avg_emp = (emp_y_mapped + emp_next_mapped) / 2;                             % Calculate average employment across the two years
    avg_emp(avg_emp == 0) = NaN;                                                % Replace zero average employment with NaN to avoid division by zero

    % Construct adjacency matrix (zeros on main diagonal)
    M_estabs = sparse(estab_y_idx, estab_next_idx, 1, n_estabs, n_estabs);      % Create sparse matrix counting worker flows from establishment i to j
    M_estabs(1:n_estabs+1:end) = 0;                                             % Set diagonal to zero to remove self-loops (workers staying at same firm)

    % Extract non-zero entries as (i, j, flows_ij)
    [row_idx, col_idx, flows] = find(M_estabs);                                 % Extract row indices, column indices, and values of non-zero elements

    % For bilateral pairs, we want i < j (to avoid duplicates)
    % Compute symmetrized flows: flows_pair = M(i,j) + M(j,i)

    % Create a table for this year pair
    n_pairs = length(row_idx);                                                  % Count number of directed pairs with non-zero flows

    % Initialize storage for bilateral measures
    estab_i_list = cell(n_pairs, 1);                                            % Initialize cell array for origin establishment IDs
    estab_j_list = cell(n_pairs, 1);                                            % Initialize cell array for destination establishment IDs
    flows_ij_list = zeros(n_pairs, 1);                                          % Initialize array for flows from i to j
    flows_ji_list = zeros(n_pairs, 1);                                          % Initialize array for flows from j to i
    avg_emp_i_list = zeros(n_pairs, 1);                                         % Initialize array for average employment at establishment i
    avg_emp_j_list = zeros(n_pairs, 1);                                         % Initialize array for average employment at establishment j

    for k = 1:n_pairs                                                           % Loop through each directed pair
        i = row_idx(k);                                                         % Get row index (origin establishment)
        j = col_idx(k);                                                         % Get column index (destination establishment)

        estab_i_list{k} = unique_estabs(i);                                     % Store origin establishment ID
        estab_j_list{k} = unique_estabs(j);                                     % Store destination establishment ID
        flows_ij_list(k) = full(M_estabs(i, j));                                % Get flow count from i to j (convert from sparse to full)
        flows_ji_list(k) = full(M_estabs(j, i));                                % Get flow count from j to i (convert from sparse to full)
        avg_emp_i_list(k) = avg_emp(i);                                         % Get average employment at origin establishment
        avg_emp_j_list(k) = avg_emp(j);                                         % Get average employment at destination establishment
    end

    % Create table for this year pair
    T_bilateral = table(estab_i_list, estab_j_list, flows_ij_list, flows_ji_list, ...
        avg_emp_i_list, avg_emp_j_list, ...
        'VariableNames', {'estab_i', 'estab_j', 'flows_ij', 'flows_ji', 'avg_emp_i', 'avg_emp_j'}); % Create table with bilateral flow data and employment

    % Compute bilateral flow (symmetrized)
    T_bilateral.flows_bilateral = T_bilateral.flows_ij + T_bilateral.flows_ji;  % Sum flows in both directions to get total bilateral flow

    % Compute ratio normalized by avg_emp_i
    T_bilateral.ratio_t = T_bilateral.flows_bilateral ./ T_bilateral.avg_emp_i; % Calculate bilateral connectivity as flows divided by origin employment

    % Rename ratio column with year suffix
    ratioVarName = sprintf('ratio_%d_%d', y, next_y);                           % Create variable name with year pair suffix for ratio
    flowsVarName = sprintf('flows_bilateral_%d_%d', y, next_y);                 % Create variable name with year pair suffix for flows

    T_bilateral.Properties.VariableNames{'ratio_t'} = ratioVarName;             % Rename ratio variable with year-specific name
    T_bilateral.Properties.VariableNames{'flows_bilateral'} = flowsVarName;     % Rename bilateral flows variable with year-specific name

    % Keep only essential columns for merging
    T_bilateral_slim = T_bilateral(:, {'estab_i', 'estab_j', ratioVarName, flowsVarName}); % Subset table to keep only key variables

    bilateral_all{end+1} = T_bilateral_slim;                                    % Append this year pair's table to the cell array

    fprintf('Found %d directed pairs for year pair %d-%d.\n', n_pairs, y, next_y); % Print number of directed pairs found
end

%% Merge all year pairs
% Start with first year pair
final_bilateral = bilateral_all{1};                                             % Initialize final table with first year pair data

for k = 2:length(bilateral_all)                                                 % Loop through remaining year pairs
    % Outer join on (estab_i, estab_j)
    final_bilateral = outerjoin(final_bilateral, bilateral_all{k}, ...
        'Keys', {'estab_i', 'estab_j'}, ...
        'MergeKeys', true, ...
        'Type', 'full');                                                        % Full outer join to combine all year pairs, keeping all pairs from any year
end

%% Now we need to aggregate to unique pairs (i,j) where i < j
% This symmetrizes the data

fprintf('Aggregating to unique pairs...\n');                                    % Print progress message for aggregation step

% Convert cell arrays to string for comparison
estab_i_str = string(final_bilateral.estab_i);                                  % Convert establishment i IDs to string array for comparison
estab_j_str = string(final_bilateral.estab_j);                                  % Convert establishment j IDs to string array for comparison

% Create canonical ordering: always put smaller ID first
pair_first = cell(height(final_bilateral), 1);                                  % Initialize cell array for first (smaller) establishment in pair
pair_second = cell(height(final_bilateral), 1);                                 % Initialize cell array for second (larger) establishment in pair

for k = 1:height(final_bilateral)                                               % Loop through each row in final bilateral table
    if estab_i_str(k) < estab_j_str(k)                                          % If establishment i has smaller ID than j
        pair_first{k} = estab_i_str(k);                                         % Assign i as first in canonical pair
        pair_second{k} = estab_j_str(k);                                        % Assign j as second in canonical pair
    else                                                                        % If establishment j has smaller or equal ID
        pair_first{k} = estab_j_str(k);                                         % Assign j as first in canonical pair
        pair_second{k} = estab_i_str(k);                                        % Assign i as second in canonical pair
    end
end

final_bilateral.pair_first = pair_first;                                        % Add canonical first establishment to table
final_bilateral.pair_second = pair_second;                                      % Add canonical second establishment to table

% Group by (pair_first, pair_second) and sum flows, average ratios
% Using groupsummary or accumarray approach

% Create unique pair identifier
pair_key = strcat(string(pair_first), '_', string(pair_second));                % Create unique string key by concatenating pair IDs
[unique_pairs, ~, pair_idx] = unique(pair_key);                                 % Get unique pair keys and mapping indices
n_unique_pairs = length(unique_pairs);                                          % Count number of unique establishment pairs

fprintf('Number of unique pairs: %d\n', n_unique_pairs);                        % Print number of unique pairs found

% Initialize output arrays
out_first = cell(n_unique_pairs, 1);                                            % Initialize cell array for first establishment IDs in output
out_second = cell(n_unique_pairs, 1);                                           % Initialize cell array for second establishment IDs in output
out_flows_total = zeros(n_unique_pairs, 1);                                     % Initialize array for total flows across all year pairs
out_ratio_0708 = nan(n_unique_pairs, 1);                                        % Initialize array for 2007-2008 connectivity ratio (NaN default)
out_ratio_0809 = nan(n_unique_pairs, 1);                                        % Initialize array for 2008-2009 connectivity ratio (NaN default)
out_ratio_0910 = nan(n_unique_pairs, 1);                                        % Initialize array for 2009-2010 connectivity ratio (NaN default)
out_ratio_1011 = nan(n_unique_pairs, 1);                                        % Initialize array for 2010-2011 connectivity ratio (NaN default)
out_flows_0708 = zeros(n_unique_pairs, 1);                                      % Initialize array for 2007-2008 bilateral flows
out_flows_0809 = zeros(n_unique_pairs, 1);                                      % Initialize array for 2008-2009 bilateral flows
out_flows_0910 = zeros(n_unique_pairs, 1);                                      % Initialize array for 2009-2010 bilateral flows
out_flows_1011 = zeros(n_unique_pairs, 1);                                      % Initialize array for 2010-2011 bilateral flows

% Get column indices for year-specific variables
cols = final_bilateral.Properties.VariableNames;                                % Get list of all variable names in final table

for p = 1:n_unique_pairs                                                        % Loop through each unique pair
    mask = (pair_idx == p);                                                     % Create logical mask for rows belonging to current pair
    subset = final_bilateral(mask, :);                                          % Extract subset of rows for current pair

    % Extract pair identifiers
    out_first{p} = subset.pair_first{1};                                        % Store first establishment ID for this pair
    out_second{p} = subset.pair_second{1};                                      % Store second establishment ID for this pair

    % For flows, take the max (they should be the same for both directions since
    % flows_bilateral = M(i,j) + M(j,i) is computed for each directed pair)
    % If both (i,j) and (j,i) exist, they have the same bilateral flow count
    if ismember('flows_bilateral_2007_2008', cols)                              % Check if 2007-2008 flows variable exists
        vals = subset.flows_bilateral_2007_2008;                                % Extract 2007-2008 flow values
        vals = vals(~isnan(vals));                                              % Remove NaN values
        if ~isempty(vals)                                                       % If non-empty after removing NaNs
            out_flows_0708(p) = max(vals);                                      % Take maximum value (both directions should be equal)
        end
    end
    if ismember('flows_bilateral_2008_2009', cols)                              % Check if 2008-2009 flows variable exists
        vals = subset.flows_bilateral_2008_2009;                                % Extract 2008-2009 flow values
        vals = vals(~isnan(vals));                                              % Remove NaN values
        if ~isempty(vals)                                                       % If non-empty after removing NaNs
            out_flows_0809(p) = max(vals);                                      % Take maximum value
        end
    end
    if ismember('flows_bilateral_2009_2010', cols)                              % Check if 2009-2010 flows variable exists
        vals = subset.flows_bilateral_2009_2010;                                % Extract 2009-2010 flow values
        vals = vals(~isnan(vals));                                              % Remove NaN values
        if ~isempty(vals)                                                       % If non-empty after removing NaNs
            out_flows_0910(p) = max(vals);                                      % Take maximum value
        end
    end
    if ismember('flows_bilateral_2010_2011', cols)                              % Check if 2010-2011 flows variable exists
        vals = subset.flows_bilateral_2010_2011;                                % Extract 2010-2011 flow values
        vals = vals(~isnan(vals));                                              % Remove NaN values
        if ~isempty(vals)                                                       % If non-empty after removing NaNs
            out_flows_1011(p) = max(vals);                                      % Take maximum value
        end
    end

    % For ratios, take the one where the denominator is the "first" establishment
    % (i.e., keep ratio where estab_i == pair_first)
    % This ensures consistent normalization
    for row = 1:height(subset)                                                  % Loop through rows in subset for this pair
        orig_i = string(subset.estab_i{row});                                   % Get original establishment i from this row
        first_estab = string(subset.pair_first{row});                           % Get canonical first establishment

        if orig_i == first_estab                                                % If original i matches canonical first (correct denominator)
            % This row has the correct denominator (avg_emp of first estab)
            if ismember('ratio_2007_2008', cols) && ~isnan(subset.ratio_2007_2008(row)) % Check if 2007-2008 ratio exists and is not NaN
                out_ratio_0708(p) = subset.ratio_2007_2008(row);                % Store 2007-2008 ratio
            end
            if ismember('ratio_2008_2009', cols) && ~isnan(subset.ratio_2008_2009(row)) % Check if 2008-2009 ratio exists and is not NaN
                out_ratio_0809(p) = subset.ratio_2008_2009(row);                % Store 2008-2009 ratio
            end
            if ismember('ratio_2009_2010', cols) && ~isnan(subset.ratio_2009_2010(row)) % Check if 2009-2010 ratio exists and is not NaN
                out_ratio_0910(p) = subset.ratio_2009_2010(row);                % Store 2009-2010 ratio
            end
            if ismember('ratio_2010_2011', cols) && ~isnan(subset.ratio_2010_2011(row)) % Check if 2010-2011 ratio exists and is not NaN
                out_ratio_1011(p) = subset.ratio_2010_2011(row);                % Store 2010-2011 ratio
            end
            break;                                                              % Found the correct row, exit inner loop
        end
    end

    out_flows_total(p) = out_flows_0708(p) + out_flows_0809(p) + out_flows_0910(p) + out_flows_1011(p); % Sum flows across all year pairs for total
end

%% Compute average bilateral connectivity per worker across year pairs
% bilateral_conn_pw = average of (flows_ij + flows_ji) / avg_emp_i across t

% Count non-missing year pairs for each pair
n_years = ~isnan(out_ratio_0708) + ~isnan(out_ratio_0809) + ~isnan(out_ratio_0910) + ~isnan(out_ratio_1011); % Count number of year pairs with valid ratios

% Replace NaN with 0 for summation
r0708 = out_ratio_0708; r0708(isnan(r0708)) = 0;                                % Copy 2007-2008 ratios and replace NaN with 0
r0809 = out_ratio_0809; r0809(isnan(r0809)) = 0;                                % Copy 2008-2009 ratios and replace NaN with 0
r0910 = out_ratio_0910; r0910(isnan(r0910)) = 0;                                % Copy 2009-2010 ratios and replace NaN with 0
r1011 = out_ratio_1011; r1011(isnan(r1011)) = 0;                                % Copy 2010-2011 ratios and replace NaN with 0

bilateral_conn_pw = (r0708 + r0809 + r0910 + r1011) ./ max(n_years, 1);         % Compute average connectivity across valid year pairs (min divisor of 1)
bilateral_conn_pw(n_years == 0) = NaN;                                          % Set connectivity to NaN for pairs with no valid year pairs

%% Create output table
output_table = table(out_first, out_second, bilateral_conn_pw, out_flows_total, ...
    out_flows_0708, out_flows_0809, out_flows_0910, out_flows_1011, ...
    out_ratio_0708, out_ratio_0809, out_ratio_0910, out_ratio_1011, ...
    'VariableNames', {'identificad_i', 'identificad_j', 'bilateral_conn_pw', 'flows_total', ...
    'flows_0708', 'flows_0809', 'flows_0910', 'flows_1011', ...
    'ratio_0708', 'ratio_0809', 'ratio_0910', 'ratio_1011'});                   % Create output table with all bilateral connectivity measures

%% Save output
outputFile = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_connectivity_2007_2011.csv'; % Define output file path
writetable(output_table, outputFile);                                           % Write output table to CSV file

fprintf('Saved bilateral connectivity data to %s\n', outputFile);               % Print confirmation message with file path
fprintf('Total unique pairs: %d\n', height(output_table));                      % Print total number of unique pairs saved
fprintf('Done!\n');                                                             % Print completion message
