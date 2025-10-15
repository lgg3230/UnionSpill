
%% Clear Workspace
clear; clc; close all;

%% Define the year range for flow data
start_year = 2009;
end_year   = 2012;  
% This will process pairs: 2009-2010, 2010-2011, and 2011-2012

%% Load the treatment status dataset (for 2012)
% This file must have two columns:
%   - identificad: Unique employer ID (for 2012)
%   - treat_ultra: Dummy variable equal to 1 if the employer is treated, 0 otherwise
treatData = readtable("/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/treat_cnpj.csv");
% Convert the employer IDs to strings for consistent matching
treatData.identificad = string(treatData.identificad);

%% Initialize a cell array to store tables for each year pair
connTables = {};

%% Loop over consecutive year pairs
for y = start_year:(end_year - 1)
    nextYear = y + 1;
    
    % Construct the file path for the flow data for the current pair.
    % (Assumes file names like "employers_2009_2010.csv", etc.)
    flowFile = sprintf("/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv", y, nextYear);
    
    % Load the biannual flow data for the current pair
    flowData = readtable(flowFile);
    
    % Dynamically construct the column names for the two years.
    % (Assumes the columns are named 'identificad_<year>' for year t and for t+1.)
    col_t  = sprintf('identificad_%d', y);
    col_t1 = sprintf('identificad_%d', nextYear);
    
    % Extract employer IDs (convert to strings)
    emp_t  = string(flowData.(col_t));   % Employers in year t (source)
    emp_t1 = string(flowData.(col_t1));    % Employers in year t+1 (destination)
    
    %% Build Unique Employer Mapping from the Flow Data
    % Combine employer IDs from both years to obtain all unique employer IDs
    unique_emps = unique([emp_t; emp_t1]);
    nEmps = length(unique_emps);
    
    % Map each employer ID to its index in unique_emps
    [~, emp_t_idx]  = ismember(emp_t, unique_emps);
    [~, emp_t1_idx] = ismember(emp_t1, unique_emps);
    
    % Remove any rows with invalid indices (if any)
    valid_idx = (emp_t_idx > 0) & (emp_t1_idx > 0);
    emp_t_idx  = emp_t_idx(valid_idx);
    emp_t1_idx = emp_t1_idx(valid_idx);
    
    %% Construct the Adjacency Matrix (Connectivity Matrix)
    % M(i,j) counts the number of workers moving from employer i (year t) to employer j (year t+1)
    M = sparse(emp_t_idx, emp_t1_idx, 1, nEmps, nEmps);
    
    %% Assign Treatment Status to Unique Employers (from Flow Data)
    % For each employer in unique_emps, match it to the treatment dataset.
    [found, treat_idx] = ismember(unique_emps, treatData.identificad);
    % Initialize treatment status vector (default: untreated, 0)
    isTreated = zeros(nEmps, 1);
    % For those employers found in treatData, assign their treat_ultra value
    isTreated(found) = treatData.treat_ultra(treat_idx(found));
    
    %% Compute Raw Flow Measures (both Outflows and Inflows)
    % Outgoing flows (row sums): total workers leaving each employer (as source)
    totalOut = full(sum(M, 2));
    % Incoming flows (column sums): total workers arriving at each employer (as destination)
    totalIn = full(sum(M, 1))';
    % Total flows for each employer = outflow + inflow
    totalFlows = totalOut + totalIn;
    
    % Outflows to treated firms: For each row (source), sum flows to columns corresponding to treated employers
    outToTreated = full(sum(M(:, isTreated == 1), 2));
    % Inflows from treated firms: For each column (destination), sum flows from rows corresponding to treated employers
    inFromTreated = full(sum(M(isTreated == 1, :), 1))';
    
    % Total flows with treated firms = outflow to treated + inflow from treated
    treatedFlows = outToTreated + inFromTreated;
    
    %% Compute Connectivity Measure
    % Connectivity Percentage = 100 * (treatedFlows / totalFlows)
    connectivityPercentage = 100 * (treatedFlows ./ totalFlows);
    connectivityPercentage(totalFlows == 0) = NaN; % Avoid division by zero
    
    %% Prepare a Table for the Current Year Pair
    % Use the unique employer IDs as the identifier; here we name this variable "identificad"
    T_pair = table(unique_emps, connectivityPercentage, outToTreated, inFromTreated, ...
        'VariableNames', {'identificad', 'Connectivity_Percentage', 'OutflowTreated', 'InflowTreated'});
    
    % Rename the measure variables to include the year pair information
    connVarName = sprintf('Connectivity_%d_%d', y, nextYear);
    outVarName  = sprintf('OutflowTreated_%d_%d', y, nextYear);
    inVarName   = sprintf('InflowTreated_%d_%d', y, nextYear);
    
    T_pair.Properties.VariableNames{'Connectivity_Percentage'} = connVarName;
    T_pair.Properties.VariableNames{'OutflowTreated'} = outVarName;
    T_pair.Properties.VariableNames{'InflowTreated'} = inVarName;
    
    % Store this table in our cell array
    connTables{end+1} = T_pair;
    
    fprintf('Processed measures for year pair %d-%d.\n', y, nextYear);
end

%% Merge All Year-Pair Tables into One Final Table
% Perform an outer join on identificad (employer id) so that every employer is included.
finalTable = connTables{1};
for i = 2:length(connTables)
    finalTable = outerjoin(finalTable, connTables{i}, 'MergeKeys', true, 'Type', 'full');
end

% (Optional) Sort the final table by identificad
finalTable = sortrows(finalTable, 'identificad');

%% Save the Final Merged Table
outputFile = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/connectivity_measures_all_years.csv";
writetable(finalTable, outputFile);

disp('Final merged dataset with connectivity, raw outflow, and raw inflow measures has been saved.');