%% Full Connectivity - Post-Treatment Period (2011-2016)
% Computes total flows for each establishment for post-treatment year pairs
% Output: CSV with connectivity measures for each establishment

clear; clc; close all;

%% Define the post-treatment years
start_year = 2011;
end_year   = 2016;

%% Load Lagos Sample Dataset (for reference/filtering if needed)
lagossample = readtable("/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/lagos_sample.csv");
lagossample.identificad = string(lagossample.identificad);

%% Initialize cell to store connectivity measures
conntables = {};

%% Loop: compute connectivity matrix for every two consecutive years

for y = start_year:(end_year-1)
    next_y = (y + 1);

    % Read employers across two consecutive years
    filename = sprintf('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv', y, next_y);
    fprintf('Loading %s...\n', filename);
    employers = readtable(filename);

    % Extract establishment IDs from employers data
    estab_y = string(employers.(['identificad_' num2str(y)]));
    estab_next = string(employers.(['identificad_' num2str(next_y)]));

    % Build unique establishment mapping
    unique_estabs = unique([estab_y; estab_next]);
    n_estabs = length(unique_estabs);

    % Map each employer ID to its index in unique_estabs
    [~, estab_y_idx] = ismember(estab_y, unique_estabs);
    [~, estab_next_idx] = ismember(estab_next, unique_estabs);

    % Remove invalid rows
    valid_idx = (estab_y_idx > 0) & (estab_next_idx > 0);
    estab_y_idx = estab_y_idx(valid_idx);
    estab_next_idx = estab_next_idx(valid_idx);

    % Construct adjacency matrix for establishments, zeros on main diagonal
    M_estabs = sparse(estab_y_idx, estab_next_idx, 1, n_estabs, n_estabs);
    M_estabs(1:n_estabs+1:end) = 0;

    % Mark which establishments are part of Lagos sample
    [~, lagos_idx] = ismember(unique_estabs, lagossample.identificad);
    is_lagos = zeros(n_estabs, 1);
    is_lagos(lagos_idx > 0) = lagossample.lagos_sample(lagos_idx(lagos_idx > 0));

    % Compute flows between establishments
    totalOut = full(sum(M_estabs, 2));
    totalIn = full(sum(M_estabs, 1))';
    totalFlows = totalOut + totalIn;

    outToLagos = full(sum(M_estabs(:, is_lagos == 1), 2));
    inFromLagos = full(sum(M_estabs(is_lagos == 1, :), 1))';
    LagosFlows = outToLagos + inFromLagos;

    % Load employment data for both years
    emp_y    = employers.(['firm_emp_' num2str(y)]);
    emp_next = employers.(['firm_emp_' num2str(next_y)]);

    % Map employment to unique establishments
    emp_y_mapped    = zeros(n_estabs, 1);
    emp_next_mapped = zeros(n_estabs, 1);

    [found_y, idx_y] = ismember(estab_y, unique_estabs);
    emp_y_mapped(idx_y(found_y)) = emp_y(found_y);

    [found_next, idx_next] = ismember(estab_next, unique_estabs);
    emp_next_mapped(idx_next(found_next)) = emp_next(found_next);

    % Compute average employment and avoid division by zero
    avg_emp = (emp_y_mapped + emp_next_mapped) / 2;
    avg_emp(avg_emp == 0) = NaN;

    % Normalize flows (per worker)
    norm_totalOut   = totalOut ./ avg_emp;
    norm_totalIn    = totalIn  ./ avg_emp;
    norm_totalFlows = totalFlows ./ avg_emp;

    norm_outToLagos  = outToLagos ./ avg_emp;
    norm_inFromLagos = inFromLagos ./ avg_emp;
    norm_LagosFlows  = LagosFlows ./ avg_emp;

    % Create table for this year pair
    T_pair = table(unique_estabs, ...
                totalOut, totalIn, totalFlows, ...
                norm_totalOut, norm_totalIn, norm_totalFlows, ...
                outToLagos, inFromLagos, LagosFlows, ...
                norm_outToLagos, norm_inFromLagos, norm_LagosFlows, ...
                'VariableNames', { ...
                    'identificad1', ...
                    'total_out','total_in','total_flows', ...
                    'total_out_pw','total_in_pw','total_flows_pw', ...
                    'out_lagos','in_lagos','lagos_flows', ...
                    'out_lagos_pw','in_lagos_pw','lagos_flows_pw' ...
                });

    % Rename variables to include years
    T_pair.Properties.VariableNames{'total_out'}   = sprintf('totalout_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'total_in'}    = sprintf('totalin_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'total_flows'} = sprintf('totalflows_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'out_lagos'}   = sprintf('outlagos_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'in_lagos'}    = sprintf('inlagos_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'lagos_flows'} = sprintf('totallagos_%d_%d', y, next_y);

    T_pair.Properties.VariableNames{'total_out_pw'}   = sprintf('totalout_pw_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'total_in_pw'}    = sprintf('totalin_pw_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'total_flows_pw'} = sprintf('totalflows_pw_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'out_lagos_pw'}   = sprintf('outlagos_pw_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'in_lagos_pw'}    = sprintf('inlagos_pw_%d_%d', y, next_y);
    T_pair.Properties.VariableNames{'lagos_flows_pw'} = sprintf('totallagos_pw_%d_%d', y, next_y);

    % Store this table in our cell array
    conntables{end+1} = T_pair;

    fprintf('Processed connectivity measures for year pair %d-%d.\n', y, next_y);
end

%% Merge All Connectivity Tables into One Final Table
finaltable = conntables{1};
for k = 2:length(conntables)
    finaltable = outerjoin(finaltable, conntables{k}, 'MergeKeys', true, 'Type', 'full');
end

%% Sort the final table by identificad
finaltable = sortrows(finaltable, 'identificad1');

%% Save the Final Merged Connectivity Dataset
outputFile = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/connectivity_2011_2016.csv';
writetable(finaltable, outputFile);

fprintf('\nSaved full connectivity data (2011-2016) to %s\n', outputFile);
fprintf('Total establishments: %d\n', height(finaltable));
fprintf('Done!\n');
